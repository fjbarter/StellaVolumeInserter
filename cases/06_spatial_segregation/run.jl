using Stella
using Random
using Statistics
using Packing3D
include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))

@assert Threads.nthreads() == 1 "Run with --threads=1"
BLAS.set_num_threads(1)
mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
seed = 1
num_particles = 20_000
packing_fraction = 0.50
relative_tolerance = 1e-3
parallel = ParallelSettings(num_threads=1)

# A discrete uniform radius distribution including both endpoints: exactly 1:5.
# Twenty equal-probability support values approximate a uniform distribution by number.
radii = collect(range(0.001, 0.005; length=20))
fractions = fill(1 / length(radii), length(radii))
psd = FractionalDistribution(fractions, radii)
mean_volume = sum(fractions .* (4pi/3 .* radii.^3))
side = cbrt(num_particles * mean_volume / packing_fraction)
output = get(ENV,"STELLA_OUTPUT",joinpath(@__DIR__,"..","..","data","raw","generated","06_spatial_segregation"))
mkpath(output)

box = G.with_gmsh(argv=["", "-v", "0"]) do
    G.Box((0.0, 0.0, 0.0), (side, side, side))
    G.mesh(size_max=side / 8)
end |> TriangleMesh
write_snapshot(create_triangle_wall(box, steel), output, "inclusion")

# Raw particle coordinates support repeat analysis without repeating insertion.
saved_particles = Ref{Any}(nothing)
result = run_insertion(
    joinpath(output, "insertion"); requested_count=num_particles, volume=side^3,
    clearance=p -> box_clearance(p, (side, side, side)),
    relative_tolerance=relative_tolerance, seed=seed,
    expected_radii=radii, expected_fractions=fractions,
    settings=Dict{String,Any}("side_length"=>side, "target_packing_fraction"=>packing_fraction,
        "backend"=>"CPU Float64", "cpu_tasks"=>1, "radius_ratio"=>5.0),
    additional_diagnostics=(positions, sampled_radii) -> begin
        open(joinpath(output, "particles.csv"), "w") do io
            println(io, "id,x,y,z,radius")
            for i in eachindex(sampled_radii)
                println(io, join((i, positions[1,i], positions[2,i], positions[3,i], sampled_radii[i]), ','))
            end
        end
        saved_particles[] = (copy(positions),copy(sampled_radii))
        Dict{String,Any}()
    end,
) do
    create_spheres_in_volume(
        num_particles, mcc; include=box,
        properties=FractionalDistribution(radius=psd),
        precision=(sampling=:double, relaxation=:double), parallel=parallel,
        relative_tolerance=relative_tolerance, max_iterations=4000,
        force_fill=false, verbose=2,
    )
end
@assert result["status"] == "passed" && result["reported_converged"] "Insertion did not validate"
write_table(joinpath(output,"insertion_summary.csv"),[result])
