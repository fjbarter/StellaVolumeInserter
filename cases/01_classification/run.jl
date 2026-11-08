using Stella
using Random

include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))

# StellaGmsh generates all meshes; no external geometry files are needed.
mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
parallel = ParallelSettings(num_threads=1)
relative_tolerance = 1e-3
seed = 1
output = get(ENV,"STELLA_OUTPUT",joinpath(@__DIR__,"..","..","data","raw","generated","01_classification"))
mkpath(output)

mesh_size = 0.2
box = box_mesh(; size_max=mesh_size)
cylinder = cylinder_mesh(; size_max=mesh_size)
# Match the analytical annulus regression test in Stella's test suite.
annulus_outer = cylinder_mesh(; radius=0.03, height=0.1, size_max=0.003)
shaft = cylinder_mesh(; radius=0.01, height=0.1, size_max=0.003)
# Keep inclusions separate: this exercises their union semantics, not only a fused mesh.
box1 = box_mesh((0.1, 0.1, 0.1); size_max=0.01)
box2 = box_mesh((0.1, 0.1, 0.1); origin=(0.07, 0.07, 0.07), size_max=0.01)
box3 = box_mesh((0.05, 0.05, 0.05); origin=(0.14, 0.14, 0.14), size_max=0.01)
box4 = box_mesh((0.05, 0.05, 0.05); size_max=0.01)

# A sphere must fit in at least one inclusion and stay clear of both exclusions.
intersecting_clearance = p -> min(
    max(box_clearance(p, (0.1, 0.1, 0.1)),
        box_clearance(p, (0.1, 0.1, 0.1); origin=(0.07, 0.07, 0.07))),
    -box_clearance(p, (0.05, 0.05, 0.05); origin=(0.14, 0.14, 0.14)),
    -box_clearance(p, (0.05, 0.05, 0.05)),
)

# Fuse two overlapping boxes to obtain a closed concave L-shaped inclusion.
concave = G.with_gmsh(argv=["", "-v", "0"]) do
    G.Box((0.0, 0.0, 0.0), (2.0, 1.0, 1.0)) +
        G.Box((0.0, 0.0, 0.0), (1.0, 2.0, 1.0))
    G.mesh(size_max=mesh_size)
end |> TriangleMesh
l_polygon = [(0.0, 0.0), (2.0, 0.0), (2.0, 1.0),
             (1.0, 1.0), (1.0, 2.0), (0.0, 2.0)]

# Mesh references use independent solid-angle winding and triangle distances.
# Analytical references additionally expose curved-surface discretisation error.
box_reference = mesh_reference(box)
cylinder_reference = mesh_reference(cylinder)
shaft_reference = mesh_reference(shaft)
annulus_reference = mesh_reference(annulus_outer)

scenarios = [
    (
        name="box", inclusions=(box,), excludes=(), volume=mesh_volume(box),
        clearance=box_reference,
        ideal=p -> box_clearance(p, (1.0, 1.0, 1.0)),
        lower=(-0.1, -0.1, -0.1), upper=(1.1, 1.1, 1.1),
    ),
    (
        name="cylinder", inclusions=(cylinder,), excludes=(), volume=mesh_volume(cylinder),
        clearance=cylinder_reference, ideal=p -> cylinder_clearance(p),
        lower=(-1.1, -1.1, -0.1), upper=(1.1, 1.1, 1.1),
    ),
    (
        name="annulus", inclusions=(annulus_outer,), excludes=(shaft,),
        volume=mesh_volume(annulus_outer) - mesh_volume(shaft),
        clearance=p -> min(annulus_reference(p), -shaft_reference(p)),
        ideal=p -> min(cylinder_clearance(p; radius=0.03, height=0.1),
                       hypot(p[1], p[2]) - 0.01),
        lower=(-0.03, -0.03, 0.0), upper=(0.03, 0.03, 0.1),
    ),
    (
        name="concave_prism", inclusions=(concave,), excludes=(), volume=mesh_volume(concave),
        clearance=mesh_reference(concave), ideal=p -> prism_clearance(p, l_polygon),
        lower=(-0.1, -0.1, -0.1), upper=(2.1, 2.1, 1.1),
    ),
    (
        name="intersecting_cubes", inclusions=(box1, box2), excludes=(box3, box4),
        volume=2 * 0.1^3 - 0.03^3 - 0.05^3 - 0.03^3,
        clearance=intersecting_clearance, ideal=intersecting_clearance,
        lower=(-0.01, -0.01, -0.01), upper=(0.2, 0.2, 0.2),
    ),
]

scenarios = filter(c -> c.name in ("box","cylinder","annulus","concave_prism","intersecting_cubes"), scenarios)

warm_up(mcc; parallel)
classification_rows = Dict{String, Any}[]
insertion_rows = Dict{String, Any}[]

for case in scenarios
    directory = joinpath(output, case.name)
    for (i, mesh) in enumerate(case.inclusions)
        write_snapshot(create_triangle_wall(mesh, steel), directory, "inclusion_$i")
    end
    for (i, mesh) in enumerate(case.excludes)
        write_snapshot(create_triangle_wall(mesh, steel), directory, "exclusion_$i")
    end

    # Random points plus exact vertices, edge midpoints and face centroids, perturbed on
    # either side of each coordinate direction to exercise ray/triangle degeneracies.
    rng = MersenneTwister(case.name == "annulus" ? 42 : seed)
    num_random = 5000
    positions = permutedims(rand(rng, num_random, 3))
    positions .= collect(case.lower) .+ positions .* collect(case.upper .- case.lower)
    probes = Vector{Float64}[]
    for mesh in (case.inclusions..., case.excludes...)
        num_triangles = size(mesh.connectivity, 2)
        selected = unique(round.(Int, range(1, num_triangles; length=min(num_triangles, 24))))
        for (a, b, c) in eachcol(mesh.connectivity[:, selected])
            v1, v2, v3 = mesh.vertices[:, a], mesh.vertices[:, b], mesh.vertices[:, c]
            for point in (v1, (v1 + v2) / 2, (v1 + v2 + v3) / 3)
                push!(probes, point)
                for axis in 1:3, offset in (-1e-5, 1e-5)
                    shifted = copy(point)
                    shifted[axis] += offset
                    push!(probes, shifted)
                end
            end
        end
    end
    positions = hcat(positions, probes...)

    sampling_clearance = case.name == "annulus" ? 1e-4 :
        (case.name == "intersecting_cubes" ? 0.004 : 0.035)

    for precision in (:single, :double)
        typemap = TypeMap(precision)
        T = typeof(typemap.reals)
        inclusion_bvhs = Tuple(
            Stella.build_triangle_query_bvh(mesh, typemap; parallel) for mesh in case.inclusions
        )
        exclusion_bvhs = Tuple(
            Stella.build_triangle_query_bvh(mesh, typemap; parallel) for mesh in case.excludes
        )
        batch = Stella.RayBatchBuffer(typemap; num_points_in_batch=1024, parallel)
        accepted = Bool[]
        checked_positions = Float64.(T.(positions))
        for first_point in 1:1024:size(positions, 2)
            last_point = min(first_point + 1023, size(positions, 2))
            points = T.(positions[:, first_point:last_point])
            n = size(points, 2)
            for i in 1:n, ray in 1:6
                batch.positions[:, 6(i - 1) + ray] .= points[:, i]
            end
            flags = fill(false, n)
            Stella.check_valid_insertion_points_in_batch(
                batch, n, inclusion_bvhs, exclusion_bvhs, T(sampling_clearance^2), flags; parallel,
            )
            append!(accepted, flags)
        end

        # Boundary points have no unique inside/outside label; report them separately.
        clearance = [case.clearance(p) for p in eachcol(checked_positions)]
        ideal_clearance = [case.ideal(p) for p in eachcol(checked_positions)]
        boundary_band = 32eps(T) * maximum(case.upper .- case.lower)
        inside = clearance .> sampling_clearance + boundary_band
        intentional_rejection = .!accepted .& (clearance .> boundary_band) .&
            (clearance .< sampling_clearance - boundary_band)
        clearance_violation = accepted .& (clearance .< sampling_clearance - boundary_band)
        outside = clearance .< -boundary_band
        boundary = (abs.(clearance) .<= boundary_band) .|
            (abs.(clearance .- sampling_clearance) .<= boundary_band)
        false_positive = accepted .& outside
        false_negative = .!accepted .& inside
        # Keep ordinary random sampling separate from deliberately adversarial probes.
        for (category, indices) in (("random", 1:num_random),
                                    ("targeted", num_random+1:length(accepted)))
            row = Dict{String, Any}(
                "case" => case.name, "precision" => string(precision), "category" => category,
                "points" => length(indices), "boundary_band" => boundary_band,
                "sampling_clearance" => sampling_clearance,
                "intentional_clearance_rejections" => count(intentional_rejection[indices]),
                "clearance_violations" => count(clearance_violation[indices]),
                "inside_points" => count(inside[indices]),
                "outside_points" => count(outside[indices]),
                "boundary_points" => count(boundary[indices]),
                "false_positives" => count(false_positive[indices]),
                "false_negatives" => count(false_negative[indices]),
                "ideal_false_positives" => count(
                    (accepted .& (ideal_clearance .< -boundary_band))[indices]
                ),
                "ideal_false_negatives" => count(
                    (.!accepted .& (ideal_clearance .> sampling_clearance + boundary_band))[indices]
                ),
                "false_positive_rate" => count(false_positive[indices]) /
                    max(1, count(outside[indices])),
                "false_negative_rate" => count(false_negative[indices]) /
                    max(1, count(inside[indices])),
            )
            push!(classification_rows, row)
            write_summary(mkpath(joinpath(directory, "$(precision)_$category")), row)
        end
        mismatches = Dict{String, Any}[]
        for i in findall(false_positive .| false_negative)
            push!(mismatches, Dict{String, Any}(
                "x" => checked_positions[1, i], "y" => checked_positions[2, i],
                "z" => checked_positions[3, i], "accepted" => accepted[i],
                "clearance" => clearance[i], "targeted" => i > num_random,
            ))
        end
        write_table(joinpath(directory, "mismatches_$precision.csv"), mismatches)
        write_points(checked_positions, directory, "classification_$precision";
            accepted=Int.(accepted), targeted=Int.((1:length(accepted)) .> num_random),
            false_positive=Int.(false_positive),
            false_negative=Int.(false_negative), signed_clearance=clearance,
            intentional_clearance_rejection=Int.(intentional_rejection),
            clearance_violation=Int.(clearance_violation),
            ideal_clearance=ideal_clearance, boundary=Int.(boundary),
        )
    end

    # Save the same boundaries beside the final particles for convenient ParaView loading.
    insertion_directory = joinpath(directory, "insertion")
    for (i, mesh) in enumerate(case.inclusions)
        write_snapshot(create_triangle_wall(mesh, steel), insertion_directory, "inclusion_$i")
    end
    for (i, mesh) in enumerate(case.excludes)
        write_snapshot(create_triangle_wall(mesh, steel), insertion_directory, "exclusion_$i")
    end

    # Also validate finite spheres in each domain, beyond testing centre classification.
    num_particles = case.name == "intersecting_cubes" ? 2000 : 500
    particle_radius = case.name == "annulus" ? 0.0015 :
        (case.name == "intersecting_cubes" ? 0.004 : 0.035)
    result = run_insertion(
        insertion_directory; requested_count=num_particles,
        volume=case.volume, clearance=case.clearance, reference_clearance=case.ideal,
        relative_tolerance=relative_tolerance, seed=seed,
        settings=Dict{String, Any}(
            "triangles" => sum(size(mesh.connectivity, 2) for mesh in case.inclusions),
            "inclusion_count" => length(case.inclusions),
            "exclusion_count" => length(case.excludes),
        ),
    ) do
        create_spheres_in_volume(
            num_particles, mcc; include=case.inclusions, exclude=case.excludes,
            properties=FractionalDistribution(radius=particle_radius),
            precision=(sampling=:double, relaxation=:double), parallel=parallel,
            relative_tolerance=relative_tolerance, force_fill=false, verbose=2,
        )
    end
    push!(insertion_rows, result)
end

write_table(joinpath(output, "classification.csv"), classification_rows)
write_table(joinpath(output, "insertions.csv"), insertion_rows)
