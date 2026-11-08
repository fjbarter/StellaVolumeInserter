using Stella
using Random

include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))

mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
parallel = ParallelSettings(num_threads=1)
seeds = 1:5
relative_tolerance = 1e-3
num_particles = 800
packing_fraction = 0.40
output = get(
    ENV,
    "STELLA_OUTPUT",
    joinpath(@__DIR__, "..", "..", "data", "raw", "generated", "08_mesh_refinement"),
)
mkpath(output)


# Replay exactly the same penetrating spheres at every resolution. This isolates the
# wall-correction field from stochastic sampling and from particle-particle relaxation.
function wall_probe(mesh, positions, directory, mesh_clearance, ideal_clearance; probe_radius=0.04)
    particles = create_spheres(
        mcc;
        positions=positions,
        properties=FractionalDistribution(radius=probe_radius),
    )
    wall = create_triangle_wall(mesh, steel)
    settings = Stella.materialize_insertion_settings(
        (sampling=:double, relaxation=:double),
        UnitMap(),
        MersenneTwister(0),
        1.0,
        0.5,
        relative_tolerance,
        2000,
        0.025,
        100,
        1e-3,
        1.0,
        DominanceHierarchy(),
        false,
        0;
        parallel=parallel,
    )
    particle_bvh = Stella.SkinBVH(particles, 0.0, settings)
    wall_bvh = Stella.SkinBVH(wall, 0.0, settings)
    traversal = Stella.build_wall_traversal(settings)
    write_snapshot(particles, directory, "probes_before")
    Stella.repel_from_walls!(
        particles,
        wall,
        particle_bvh,
        wall_bvh,
        traversal,
        probe_radius * 1e-3,
        settings,
        probe_radius * relative_tolerance,
    )
    corrected, radii = particle_data(particles)
    displacements = corrected - positions
    lengths = [norm(v) for v in eachcol(displacements)]
    mesh_overlap = [max(0, probe_radius - mesh_clearance(p)) for p in eachcol(corrected)]
    ideal_overlap = [max(0, probe_radius - ideal_clearance(p)) for p in eachcol(corrected)]
    write_snapshot(particles, directory, "probes_after")
    write_points(
        corrected,
        directory,
        "probe_diagnostics";
        displacement=displacements,
        displacement_length=lengths,
        mesh_penetration=mesh_overlap,
        ideal_penetration=ideal_overlap,
        radius=radii,
    )
    return displacements,
    Dict{String,Any}(
        "probe_mean_displacement" => sum(lengths) / length(lengths),
        "probe_max_displacement" => maximum(lengths),
        "probe_max_mesh_penetration" => maximum(mesh_overlap),
        "probe_max_ideal_penetration" => maximum(ideal_overlap),
    )
end


warm_up(mcc; parallel)
rows = Dict{String,Any}[]

# Exact-surface refinement: Gmsh changes triangulation, but not the six planar cube faces.
box_probe_positions = [
    0.02 0.02 0.02 0.5 0.5 0.98 0.98
    0.5 0.02 0.02 0.5 0.02 0.98 0.5
    0.5 0.5 0.02 0.02 0.02 0.98 0.5
]
reference_displacements = nothing

for level in 0:5
    mesh_size = 1.0 / 2^level
    box = G.with_gmsh(argv=["", "-v", "0"]) do
        G.Box((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
        G.mesh(size_min=mesh_size, size_max=mesh_size)
    end |> TriangleMesh
    directory = joinpath(output, "cube_level_$level")
    clearance = p -> box_clearance(p, (1.0, 1.0, 1.0))
    write_snapshot(create_triangle_wall(box, steel), directory, "inclusion")
    displacement, probe_stats =
        wall_probe(box, box_probe_positions, directory, clearance, clearance)
    if isnothing(reference_displacements)
        global reference_displacements = copy(displacement)
    end
    probe_stats["probe_max_change_from_coarse"] =
        maximum(norm(v) for v in eachcol(displacement - reference_displacements))
    radius = cbrt(packing_fraction / (num_particles * 4pi / 3))

    # Use the same five seeds at every mesh resolution; save every realisation.
    for seed in seeds
        run_directory = joinpath(directory, "seed_$seed")
        write_snapshot(create_triangle_wall(box, steel), run_directory, "inclusion")
        result = run_insertion(
            run_directory;
            requested_count=num_particles,
            volume=1.0,
            clearance=clearance,
            relative_tolerance=relative_tolerance,
            seed=seed,
            settings=Dict{String,Any}(
                "geometry" => "cube",
                "level" => level,
                "mesh_size_max" => mesh_size,
                "triangles" => size(box.connectivity, 2),
                "target_packing_fraction" => packing_fraction,
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
        merge!(result, probe_stats)
        write_summary(run_directory, result)
        push!(rows, result)
        write_table(joinpath(output, "mesh_refinement.csv"), rows)
    end

end

# Curved-surface convergence: Gmsh refines the same cylindrical CAD surface.
# Particle inventory stays fixed. Small mesh-volume changes are reported, not hidden.
angles = range(0, 2pi; length=17)[1:end-1]
cylinder_probe_positions =
    hcat([[0.85cos(angle), 0.85sin(angle), z] for z in (0.02, 0.5) for angle in angles]...)
reference_displacements = nothing

for mesh_size in [0.8, 0.4, 0.2, 0.1]
    cylinder = G.with_gmsh(argv=["", "-v", "0"]) do
        G.Cylinder((0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 1.0)
        G.mesh(size_min=mesh_size, size_max=mesh_size)
    end |> TriangleMesh
    volume = mesh_volume(cylinder)
    clearance = mesh_reference(cylinder)
    ideal_clearance = p -> cylinder_clearance(p)
    directory = joinpath(output, "cylinder_mesh_size_$mesh_size")
    write_snapshot(create_triangle_wall(cylinder, steel), directory, "inclusion")
    displacement, probe_stats = wall_probe(
        cylinder,
        cylinder_probe_positions,
        directory,
        clearance,
        ideal_clearance;
        probe_radius=0.2,
    )
    if isnothing(reference_displacements)
        global reference_displacements = copy(displacement)
    end
    probe_stats["probe_max_change_from_coarse"] =
        maximum(norm(v) for v in eachcol(displacement - reference_displacements))
    radius = cbrt(packing_fraction * pi / (num_particles * 4pi / 3))

    for seed in seeds
        run_directory = joinpath(directory, "seed_$seed")
        write_snapshot(create_triangle_wall(cylinder, steel), run_directory, "inclusion")
        result = run_insertion(
            run_directory;
            requested_count=num_particles,
            volume=volume,
            clearance=clearance,
            reference_clearance=ideal_clearance,
            relative_tolerance=relative_tolerance,
            seed=seed,
            settings=Dict{String,Any}(
                "geometry" => "cylinder",
                "mesh_size_max" => mesh_size,
                "triangles" => size(cylinder.connectivity, 2),
                "target_packing_fraction" => packing_fraction,
                "ideal_domain_volume" => Float64(pi),
                "relative_volume_error" => abs(volume - pi) / pi,
            ),
        ) do
            create_spheres_in_volume(
                num_particles,
                mcc;
                include=cylinder,
                properties=FractionalDistribution(radius=radius),
                precision=(sampling=:double, relaxation=:double),
                parallel=parallel,
                relative_tolerance=relative_tolerance,
                force_fill=false,
                verbose=2,
            )
        end
        merge!(result, probe_stats)
        write_summary(run_directory, result)
        push!(rows, result)
        write_table(joinpath(output, "mesh_refinement.csv"), rows)
    end

end
