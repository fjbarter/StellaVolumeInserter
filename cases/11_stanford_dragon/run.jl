using Stella, Distributions, Random, LinearAlgebra, TOML, SHA

include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))

# Select one historical configuration per process. Launch CPU cases with --threads=N.
backend = isempty(ARGS) ? "cpu" : ARGS[1]
@assert backend in ("cpu", "metal") "Choose cpu or metal"
if backend == "metal"
    Sys.isapple() || error("Metal backend requires macOS")
    @eval using Metal
    isempty(Metal.devices()) && error("Metal backend selected, but no Metal device is available")
end
BLAS.set_num_threads(1)
parallel = ParallelSettings(num_threads=Threads.nthreads())
precision =
    backend == "metal" ? (sampling=Metal, relaxation=Metal) : (sampling=:double, relaxation=:double)

# Check that the original benchmark mesh is available.
root = normpath(joinpath(@__DIR__, "..", ".."))
mesh_path = joinpath(root, "meshes", "dragon2.stl")
@assert isfile(mesh_path) "Download the original mesh as documented in meshes/README.md"
@assert bytes2hex(sha256(read(mesh_path))) ==
        "fa680acba2c958c917fa6b2fe561c0ef56c969b4c05ed19872b49b6c7ec4e118" "Dragon mesh checksum mismatch"
label = backend == "metal" ? "metal" : "cpu_$(Threads.nthreads())"
output = get(
    ENV,
    "STELLA_OUTPUT",
    joinpath(root, "data", "raw", "generated", "11_stanford_dragon", label),
)
mkpath(output)

# Define the materials and save the mesh for visual inspection.
mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
dragon = create_triangle_wall(mesh_path, steel)
write_snapshot(dragon, output, "inclusion")

# Use the same insertion settings for warm-up and the benchmark.
function insert_geometry(n, wall, mcc, precision, parallel, backend)
    block = create_spheres_in_volume(
        n,
        mcc;
        include=wall,
        properties=FractionalDistribution(radius=FractionalDistribution(Uniform(0.06, 0.12))),
        precision=precision,
        parallel=parallel,
        relative_tolerance=1e-2,
        force_fill=false,
        verbose=2,
    )
    backend == "metal" && Metal.synchronize()
    block
end

# Warm the same subtype layout and dense pair path, outside the measurement.
side = cbrt(1000 * (4pi / 3) * 0.09^3 / 0.40)
warm_wall = create_triangle_wall(box_mesh((side, side, side); size_max=side / 4), steel)
Random.seed!(0)
open(joinpath(output, "warmup.log"), "w") do io
    redirect_stdout(io) do
        redirect_stderr(io) do
            insert_geometry(1000, warm_wall, mcc, precision, parallel, backend)
        end
    end
end

# Record the execution environment and the benchmark settings.
gpu_name = backend == "metal" ? String(first(Metal.devices()).name) : "not used"
os_version = Sys.isapple() ? strip(read(`sw_vers -productVersion`, String)) : "not recorded"
summary = Dict{String,Any}(
    "configuration" => label,
    "requested_count" => 1_705_517,
    "seed" => 1,
    "relative_tolerance" => 1e-2,
    "backend" => backend,
    "gpu_device" => gpu_name,
    "os_version" => os_version,
    "cpu_tasks" => parallel.num_threads,
    "julia_threads" => Threads.nthreads(),
    "blas_threads" => BLAS.get_num_threads(),
    "arithmetic" => backend == "metal" ? "Float32 both stages" : "Float64 both stages",
    "julia_version" => string(VERSION),
    "purging_enabled" => false,
    "measurement_kind" => "new reproduction, not a replacement for historical timings",
    "domain_volume" => mesh_volume(dragon.shape.mesh),
    "cpu_model" => Sys.CPU_NAME,
    "stella_version" => string(Base.pkgversion(Stella)),
    "mesh_sha256" => bytes2hex(sha256(read(mesh_path))),
    "stella_revision" => readchomp(`git -C $(dirname(dirname(pathof(Stella)))) rev-parse HEAD`),
)

# Retry if compilation exceeds one microsecond in either reported counter.
# Retain the measured counters and elapsed time; do not subtract compilation.
compilation_allowance = 1e-6
summary["compilation_allowance_seconds"] = compilation_allowance
block = Ref{Any}(nothing)
for attempt in 1:3
    Random.seed!(1)
    GC.gc()
    log_path = joinpath(output, "insertion_attempt_$attempt.log")
    measured = try
        open(log_path, "w") do io
            redirect_stdout(io) do
                redirect_stderr(io) do
                    @timed insert_geometry(1_705_517, dragon, mcc, precision, parallel, backend)
                end
            end
        end
    catch error
        error isa InterruptException && rethrow()
        trace = catch_backtrace()
        log_text = isfile(log_path) ? read(log_path, String) : ""
        iterations = collect(eachmatch(r"iter=(\d+)", log_text))
        summary["attempt"] = attempt
        summary["reported_converged"] = false
        summary["termination_reason"] = occursin("stagnated", sprint(showerror, error)) ?
            "stagnation" : "exception"
        summary["error"] = sprint(showerror, error)
        summary["iterations"] = isempty(iterations) ? -1 : parse(Int, last(iterations).captures[1])
        write_summary(output, summary)
        open(log_path, "a") do io
            println(io, "\nInsertion failed:")
            showerror(io, error, trace)
            println(io)
        end
        rethrow()
    end
    summary["compile_seconds"] = measured.compile_time
    summary["recompile_seconds"] = measured.recompile_time
    summary["synchronised_wall_seconds"] = measured.time
    summary["attempt"] = attempt
    text = read(log_path, String)
    stop = match(
        r"Successfully inserted (\d+) particles \(([\d.eE+-]+) seconds, (\d+) iterations, max overlap: ([\d.eE+-]+)\)",
        text,
    )
    summary["reported_converged"] = !isnothing(stop)
    if !isnothing(stop)
        summary["final_count"] = parse(Int, stop.captures[1])
        summary["printed_insertion_seconds"] = parse(Float64, stop.captures[2])
        summary["iterations"] = parse(Int, stop.captures[3])
        summary["reported_max_overlap"] = parse(Float64, stop.captures[4])
    end
    write_summary(output, summary)
    if measured.compile_time <= compilation_allowance &&
       measured.recompile_time <= compilation_allowance
        block[] = measured.value
        break
    end
    println("Discarding attempt with compilation above one microsecond: ", attempt)
end
isnothing(block[]) && error("No timing obtained within the compilation allowance")

# Save the converged assembly and its metadata for validation and inspection.
positions, radii = particle_data(block[])
summary["final_count"] = length(radii)
summary["realised_whole_domain_fraction"] = sum(4pi / 3 .* radii .^ 3) / summary["domain_volume"]
write_snapshot(block[], output, "particles")
export_particles(output, positions, radii)
export_validation_input(output, summary, nothing, radii)
write_summary(output, summary)
@assert summary["reported_converged"] && length(radii) == 1_705_517
println("Recorded ", summary["printed_insertion_seconds"], " seconds in ", output)
