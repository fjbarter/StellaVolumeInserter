using Stella
using Random
using Packing3D
using Metal

include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))
include(joinpath(@__DIR__, "pair_validation.jl"))

mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
seed = 1
num_particles = 100_000
r_small, r_large = 0.001, 0.020
radii = [r_small, r_large]
relative_tolerance = 1e-3
max_iterations = parse(Int, get(ENV, "MAXIMUM_ITERATIONS", "12000"))
output = get(
    ENV,
    "STELLA_OUTPUT",
    joinpath(@__DIR__, "..", "..", "data", "raw", "generated", "05_bidisperse"),
)
mkpath(output)

# Two-level void-filling design heuristic: if large spheres occupy phi_ref, small
# spheres occupy phi_ref of their remaining void. This is not a packing guarantee.
phi_ref = 0.64
small_to_large_volume = 1 - phi_ref
small_to_large_number = small_to_large_volume * (r_large / r_small)^3
p_large = 1 / (1 + small_to_large_number)
fractions = [1 - p_large, p_large]
psd = FractionalDistribution(fractions, radii)

# The effective radius is the cube root of the NUMBER-weighted mean r^3.
# An unweighted cbrt(r_small^3+r_large^3) would assume paired class counts and
# would provide far too little small-particle volume to fill large-particle voids.
r_effective = cbrt(sum(fractions .* radii .^ 3))
mean_volume = 4pi / 3 * r_effective^3
requested_fractions =
    parse.(Float64, split(get(ENV, "MAXIMUM_FRACTIONS", "0.60,0.65,0.70,0.75"), ','))
println("Radius ratio: $(r_large/r_small)")
println("Expected large count: $(num_particles*p_large); small count: $(num_particles*(1-p_large))")
println("Idealised two-level heuristic: $(phi_ref+(1-phi_ref)*phi_ref)")

# Preserve other attempted densities when rerunning a selected condition.
rows = Dict{String,Any}[]
for name in readdir(output)
    summary_file = joinpath(output, name, "summary.toml")
    isfile(summary_file) && push!(rows, TOML.parsefile(summary_file))
end
for target in requested_fractions
    side = cbrt(num_particles * mean_volume / target)
    directory = joinpath(output, "phi_$target")
    box = G.with_gmsh(argv=["", "-v", "0"]) do
        G.Box((0.0, 0.0, 0.0), (side, side, side))
        G.mesh(size_min=side / 4, size_max=side / 4)
    end |> TriangleMesh
    # Primary interior measure excludes a wall layer one large radius thick.
    # A thinner two-small-radius margin is also reported to expose boundary sensitivity.
    margin = r_large
    bounds = [margin, side - margin, margin, side - margin, margin, side - margin]
    thin_margin = 2r_small
    thin_bounds = [
        thin_margin,
        side - thin_margin,
        thin_margin,
        side - thin_margin,
        thin_margin,
        side - thin_margin,
    ]
    interior = box_mesh(
        (side - 2margin, side - 2margin, side - 2margin);
        origin=(margin, margin, margin),
        size_max=side / 4,
    )
    write_snapshot(create_triangle_wall(box, steel), directory, "inclusion")
    write_snapshot(create_triangle_wall(interior, steel), directory, "interior_measurement_region")
    println("Trying whole-domain fraction $target, cube side $side")
    flush(stdout)
    result = run_insertion(
        directory;
        requested_count=num_particles,
        volume=side^3,
        clearance=p -> box_clearance(p, (side, side, side)),
        relative_tolerance=relative_tolerance,
        seed=seed,
        expected_radii=radii,
        expected_fractions=fractions,
        settings=Dict{String,Any}(
            "target_packing_fraction" => target,
            "side_length" => side,
            "backend" => "Metal Float32 sampling and relaxation",
            "radius_ratio" => 20.0,
            "expected_large_count" => num_particles * p_large,
            "effective_radius" => r_effective,
            "max_iterations" => max_iterations,
            "interior_bounds" => bounds,
            "interior_margin" => margin,
            "phi_reference_heuristic" => phi_ref,
        ),
        additional_diagnostics=(positions, sampled_radii) -> Dict{String,Any}(
            "interior_packing_fraction" => Packing3D._compute_packing_cartesian(
                x_data=collect(positions[1, :]),
                y_data=collect(positions[2, :]),
                z_data=collect(positions[3, :]),
                radii=sampled_radii,
                boundaries=bounds,
                calculate_partial_volumes=true,
            ),
            "thin_margin_packing_fraction" => Packing3D._compute_packing_cartesian(
                x_data=collect(positions[1, :]),
                y_data=collect(positions[2, :]),
                z_data=collect(positions[3, :]),
                radii=sampled_radii,
                boundaries=thin_bounds,
                calculate_partial_volumes=true,
            ),
            "has_both_radius_classes" => length(unique(sampled_radii)) == 2,
        ),
    ) do
        block = create_spheres_in_volume(
            num_particles,
            mcc;
            include=box,
            properties=FractionalDistribution(radius=psd),
            precision=(sampling=Metal, relaxation=Metal),
            relative_tolerance=relative_tolerance,
            max_iterations=max_iterations,
            # Return the final block at the iteration limit so even unsuccessful attempts
            # can be independently checked and exported, without purging any particles.
            purge_stagnation=max_iterations + 1,
            force_fill=false,
            verbose=2,
        )
        Metal.synchronize()
        block
    end
    result["valid_bidisperse_assembly"] =
        result["status"] == "passed" &&
        result["reported_converged"] &&
        get(result, "has_both_radius_classes", false)
    write_summary(directory, result)
    filter!(row -> row["target_packing_fraction"] != target, rows)
    push!(rows, result)
    sort!(rows; by=row -> row["target_packing_fraction"])
    write_table(joinpath(output, "maximum_attempt.csv"), rows)
end
