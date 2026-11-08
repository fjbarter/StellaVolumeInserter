using Stella
using Random

include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))

# Launch with julia --threads=1. Particle radii and target density stay fixed;
# enlarge one Gmsh-generated cubic mesh as N increases, preserving its connectivity.
@assert Threads.nthreads() == 1 "Run this case with julia --threads=1"
BLAS.set_num_threads(1)
mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
seeds = 1:5
parallel = ParallelSettings(num_threads=1)
particle_counts = [
    1000,
    2000,
    3000,
    5000,
    10_000,
    20_000,
    30_000,
    50_000,
    100_000,
    200_000,
    300_000,
    500_000,
    1_000_000,
]
radius = 0.02
packing_fraction = 0.40
relative_tolerance = 1e-3
mesh_size = 0.5
output = get(
    ENV,
    "STELLA_OUTPUT",
    joinpath(@__DIR__, "..", "..", "data", "raw", "generated", "10_cpu_scaling"),
)
mkpath(output)

unit_box = G.with_gmsh(argv=["", "-v", "0"]) do
    G.Box((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    G.mesh(size_max=mesh_size)
end |> TriangleMesh

# Warm the dense-relaxation path outside timing, using the same property types as the sweep.
Random.seed!(0)
warm_radius = cbrt(0.4 / (1000 * 4pi / 3))
create_spheres_in_volume(
    1000,
    mcc;
    include=unit_box,
    properties=FractionalDistribution(radius=warm_radius),
    precision=(sampling=:double, relaxation=:double),
    parallel=parallel,
    relative_tolerance=relative_tolerance,
    force_fill=false,
    verbose=0,
)
rows = Dict{String,Any}[]

# Independent seeds measure assembly-to-assembly variation as well as timing noise.
# Keep each repeat's mesh, particles and diagnostics for inspection.
for seed in seeds, num_particles in particle_counts
    println("Problem-size scaling: seed=$seed, N=$num_particles")
    flush(stdout)
    particle_volume = 4pi / 3 * radius^3
    side = cbrt(num_particles * particle_volume / packing_fraction)
    box = TriangleMesh(side .* unit_box.vertices, copy(unit_box.connectivity))
    directory = joinpath(output, "N_$num_particles", "seed_$seed")
    write_snapshot(create_triangle_wall(box, steel), directory, "inclusion")

    result = run_insertion(
        directory;
        requested_count=num_particles,
        volume=side^3,
        clearance=p -> box_clearance(p, (side, side, side)),
        relative_tolerance=relative_tolerance,
        seed=seed,
        require_compile_free=true,
        settings=Dict{String,Any}(
            "side_length" => side,
            "radius" => radius,
            "target_packing_fraction" => packing_fraction,
            "triangles" => size(box.connectivity, 2),
            "backend" => "CPU Float64",
            "cpu_tasks" => 1,
            "repeat" => seed,
        ),
    ) do
        create_spheres_in_volume(
            num_particles,
            mcc;
            include=box,
            properties=FractionalDistribution(radius=radius),
            precision=(sampling=:double, relaxation=:double),
            parallel=parallel,
            relative_tolerance=relative_tolerance,
            force_fill=false,
            verbose=2,
        )
    end
    push!(rows, result)
    write_table(joinpath(output, "problem_size_scaling.csv"), rows)
end
