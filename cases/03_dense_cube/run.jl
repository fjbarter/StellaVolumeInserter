using Stella
using Random
using Packing3D

include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))

@assert Threads.nthreads() == 1 "Run this case with julia --threads=1"
BLAS.set_num_threads(1)

# One fixed seed per condition. Failed/stagnated conditions remain in the summary.
mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
seed = 1
parallel = ParallelSettings(num_threads=1)
relative_tolerance = 1e-3
# Include the existing dense-box test exactly: N=1000, r=0.005, side=0.1.
side = 0.1
baseline_fraction = 1000 * (4pi / 3 * 0.005^3) / side^3
packing_fractions = [baseline_fraction]
max_iterations = 2000
mesh_size = 0.01
bulk_bounds = [0.01, 0.09, 0.01, 0.09, 0.01, 0.09]
output = get(
    ENV,
    "STELLA_OUTPUT",
    joinpath(@__DIR__, "..", "..", "data", "raw", "generated", "03_dense_cube"),
)
mkpath(output)

box = G.with_gmsh(argv=["", "-v", "0"]) do
    G.Box((0.0, 0.0, 0.0), (side, side, side))
    G.mesh(size_max=mesh_size)
end |> TriangleMesh
write_snapshot(create_triangle_wall(box, steel), output, "inclusion")
bulk_region = box_mesh((0.08, 0.08, 0.08); origin=(0.01, 0.01, 0.01), size_max=mesh_size)
write_snapshot(create_triangle_wall(bulk_region, steel), output, "bulk_measurement_region")

# Number fractions are explicit, so requested and realised PSDs can be compared.
distributions = [
    (name="monodisperse", radii=[0.005], fractions=[1.0]),
    (name="polydisperse", radii=[0.003, 0.004, 0.005], fractions=[0.4, 0.4, 0.2]),
]

# Warm both subtype layouts before timing; one and three radius classes specialise differently.
for distribution in distributions
    Random.seed!(0)
    warm_radii = FractionalDistribution(distribution.fractions, distribution.radii)
    mean_volume = sum(distribution.fractions .* (4pi / 3 .* distribution.radii .^ 3))
    warm_count = round(Int, baseline_fraction * side^3 / mean_volume)
    create_spheres_in_volume(
        warm_count,
        mcc;
        include=box,
        properties=FractionalDistribution(radius=warm_radii),
        precision=(sampling=:double, relaxation=:double),
        parallel=parallel,
        relative_tolerance=relative_tolerance,
        force_fill=false,
        verbose=0,
    )
end
rows = Dict{String,Any}[]

for distribution in distributions, target_fraction in packing_fractions
    mean_particle_volume = sum(distribution.fractions .* (4pi / 3 .* distribution.radii .^ 3))
    num_particles = round(Int, target_fraction * side^3 / mean_particle_volume)
    radii = FractionalDistribution(distribution.fractions, distribution.radii)
    directory = joinpath(output, "$(distribution.name)_phi_$target_fraction")
    write_snapshot(create_triangle_wall(box, steel), directory, "inclusion")
    write_snapshot(create_triangle_wall(bulk_region, steel), directory, "bulk_measurement_region")

    # Target fraction sets particle count using the whole box. Bulk density is measured
    # independently in the interior, excluding wall effects and counting partial spheres.
    result = run_insertion(
        directory;
        requested_count=num_particles,
        volume=side^3,
        clearance=p -> box_clearance(p, (side, side, side)),
        relative_tolerance=relative_tolerance,
        seed=seed,
        expected_radii=distribution.radii,
        expected_fractions=distribution.fractions,
        settings=Dict{String,Any}(
            "target_packing_fraction" => target_fraction,
            "psd" => distribution.name,
            "max_iterations" => max_iterations,
            "backend" => "CPU Float64",
            "cpu_tasks" => 1,
            "bulk_bounds" => bulk_bounds,
            "side_length" => side,
            "dense_box_baseline" =>
                distribution.name == "monodisperse" && num_particles == 1000,
        ),
        additional_diagnostics=(positions, particle_radii) -> Dict{String,Any}(
            "bulk_packing_fraction" => Packing3D._compute_packing_cartesian(
                x_data=collect(positions[1, :]),
                y_data=collect(positions[2, :]),
                z_data=collect(positions[3, :]),
                radii=particle_radii,
                boundaries=bulk_bounds,
                calculate_partial_volumes=true,
            ),
        ),
    ) do
        create_spheres_in_volume(
            num_particles,
            mcc;
            include=box,
            properties=FractionalDistribution(radius=radii),
            precision=(sampling=:double, relaxation=:double),
            parallel=parallel,
            relative_tolerance=relative_tolerance,
            max_iterations=max_iterations,
            force_fill=false,
            verbose=2,
        )
    end
    push!(rows, result)
    write_table(joinpath(output, "density_sweep.csv"), rows)
end
