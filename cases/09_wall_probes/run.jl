using Stella
using Random

include(joinpath(@__DIR__, "..", "..", "common", "helpers.jl"))
include(joinpath(@__DIR__, "trace_wall.jl"))

# Identical spheres, with no pair corrections: each column is an independent wall probe.
@assert Threads.nthreads() == 1 "Run with --threads=1"
BLAS.set_num_threads(1)
mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0
radius = 0.04
positions = [
    0.02 0.02 0.02 0.5 0.5 0.98 0.98 0.02 0.015 0.012
    0.5 0.02 0.02 0.5 0.02 0.98 0.5 0.371 0.025 0.021
    0.5 0.5 0.02 0.02 0.02 0.98 0.5 0.613 0.437 0.029
]
probe_names = [
    "face_x",
    "edge_xy",
    "corner_low",
    "face_z",
    "edge_yz",
    "corner_high",
    "face_high_x",
    "face_generic",
    "edge_asymmetric",
    "corner_asymmetric",
]
output = get(
    ENV,
    "STELLA_OUTPUT",
    joinpath(@__DIR__, "..", "..", "data", "raw", "generated", "09_wall_probes"),
)
mkpath(output)
install_wall_trace()

function make_particles(points)
    create_spheres(mcc; positions=copy(points), properties=FractionalDistribution(radius=radius))
end

function settings()
    Stella.materialize_insertion_settings(
        (sampling=:double, relaxation=:double),
        UnitMap(),
        MersenneTwister(0),
        1.0,
        0.5,
        1e-3,
        2000,
        0.025,
        100,
        1e-3,
        1.0,
        DominanceHierarchy(),
        false,
        0;
        parallel=ParallelSettings(num_threads=1),
    )
end

# Analytic minimum translation into the eroded cube: independent of triangle queries.
exact_position(p, clearance) = clamp.(p, radius + clearance, 1 - radius - clearance)
penetration(p, clearance=0.0) = max(0.0, radius + clearance - minimum(vcat(p, 1 .- p)))

function candidate_pairs(particles, wall, cfg)
    particle_bvh = Stella.SkinBVH(particles, 0.0, cfg)
    wall_bvh = Stella.SkinBVH(wall, 0.0, cfg)
    traversal = Stella.build_wall_traversal(cfg)
    Stella.repel_from_walls!(particles, wall, particle_bvh, wall_bvh, traversal, 0.0, cfg, 0.0)
    state = traversal[]
    return copy(state.cache1[1:state.num_contacts])
end

function run_diagnostic()
    rows = Dict{String,Any}[]
    reference = Dict()
    for level in 0:5
        mesh_size = 1.0 / 2^level
        mesh = G.with_gmsh(argv=["", "-v", "0"]) do
            G.Box((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
            G.mesh(size_min=mesh_size, size_max=mesh_size)
        end |> TriangleMesh
        wall = create_triangle_wall(mesh, steel)
        directory = joinpath(output, "level_$level")
        write_snapshot(wall, directory, "inclusion")
        write_snapshot(make_particles(positions), directory, "probes_before")
        cfg = settings()
        pairs = candidate_pairs(make_particles(positions), wall, cfg)

        for clearance in (0.0, radius * 1e-3), order in ("bvh", "reverse", "shuffle")
            ordered_pairs =
                order == "reverse" ? reverse(pairs) :
                order == "shuffle" ? shuffle(MersenneTwister(42), pairs) : pairs
            particles = make_particles(positions)
            displacement = zeros(3, size(positions, 2))
            events = NamedTuple[]
            info = Stella.diagnostic_wall_step!(
                events,
                DominanceHierarchy(),
                displacement,
                ordered_pairs,
                particles,
                wall,
                clearance,
                cfg,
            )
            corrected = positions + displacement
            @assert all(isfinite, corrected)
            if order == "bvh"
                # Check instrumentation against the untouched production entry point.
                actual = make_particles(positions)
                pbvh = Stella.SkinBVH(actual, 0.0, cfg)
                wbvh = Stella.SkinBVH(wall, 0.0, cfg)
                Stella.repel_from_walls!(
                    actual,
                    wall,
                    pbvh,
                    wbvh,
                    Stella.build_wall_traversal(cfg),
                    clearance,
                    cfg,
                    0.0,
                )
                actual_positions, _ = particle_data(actual)
                @assert maximum(abs.(actual_positions - corrected)) < 1e-12
            end
            @assert length(events) > 0
            mode = "$(order)_clearance_$(clearance)"
            case_dir = joinpath(directory, mode)
            write_snapshot(make_particles(corrected), case_dir, "probes_after_one_step")
            write_points(
                corrected,
                case_dir,
                "diagnostics";
                displacement=displacement,
                radius=fill(radius, size(positions, 2)),
                residual_penetration=[penetration(p) for p in eachcol(corrected)],
            )

            # Every candidate's classification plus every correction actually accumulated.
            contacts = Dict{String,Any}[]
            for k in eachindex(ordered_pairs)
                info.kind[k] == 0 && continue
                triangle = Int(ordered_pairs[k][2])
                vertices = mesh.vertices[:, mesh.connectivity[:, triangle]]
                plane_axis =
                    findfirst(a -> maximum(vertices[a, :]) - minimum(vertices[a, :]) < 1e-12, 1:3)
                push!(
                    contacts,
                    Dict(
                        "plane_axis" => plane_axis,
                        "plane_coordinate" => vertices[plane_axis, 1],
                        "particle" => Int(ordered_pairs[k][1]),
                        "triangle" => Int(ordered_pairs[k][2]),
                        "contact" => k,
                        "kind" => Int(info.kind[k]),
                        "effective_overlap" => info.overlap[k],
                        "nx" => info.nx[k],
                        "ny" => info.ny[k],
                        "nz" => info.nz[k],
                        "edge_v1" => info.edge_v1[k],
                        "edge_v2" => info.edge_v2[k],
                        "vertex" => info.vertex_ids[k],
                    ),
                )
            end
            write_table(joinpath(case_dir, "contacts.csv"), contacts)
            write_table(
                joinpath(case_dir, "applied_corrections.csv"),
                [Dict{String,Any}(string(k) => v for (k, v) in Base.pairs(e)) for e in events],
            )

            # Repeat the real BVH wall path, rebuilding candidate contacts every step.
            repeated = make_particles(corrected)
            particle_bvh = Stella.SkinBVH(repeated, 0.0, cfg)
            wall_bvh = Stella.SkinBVH(wall, 0.0, cfg)
            traversal = Stella.build_wall_traversal(cfg)
            history = Dict{String,Any}[]
            steps = 1
            for step in 1:20
                points, _ = particle_data(repeated)
                for i in eachindex(probe_names)
                    push!(
                        history,
                        Dict(
                            "step" => step,
                            "particle" => i,
                            "x" => points[1, i],
                            "y" => points[2, i],
                            "z" => points[3, i],
                            "raw_penetration" => penetration(points[:, i]),
                            "effective_penetration" => penetration(points[:, i], clearance),
                        ),
                    )
                end
                steps = step
                maximum(penetration(p, clearance) for p in eachcol(points)) <= 1e-12 && break
                result = Stella.repel_from_walls!(
                    repeated,
                    wall,
                    particle_bvh,
                    wall_bvh,
                    traversal,
                    clearance,
                    cfg,
                    0.0,
                )
                particle_bvh = result.particle_sbvh
            end
            final, _ = particle_data(repeated)
            write_table(joinpath(case_dir, "wall_iterations.csv"), history)
            write_snapshot(repeated, case_dir, "probes_after_repeated_steps")
            for i in eachindex(probe_names)
                key = (clearance, order, i)
                level == 0 && (reference[key] = copy(displacement[:, i]))
                exact = exact_position(positions[:, i], clearance)
                row = Dict{String,Any}(
                    "level" => level,
                    "triangles" => size(mesh.connectivity, 2),
                    "probe" => probe_names[i],
                    "particle" => i,
                    "radius" => radius,
                    "clearance" => clearance,
                    "order" => order,
                    "dx" => displacement[1, i],
                    "dy" => displacement[2, i],
                    "dz" => displacement[3, i],
                    "change_from_coarse" => norm(displacement[:, i] - reference[key]),
                    "error_from_exact" => norm(corrected[:, i] - exact),
                    "residual_after_one" => penetration(corrected[:, i]),
                    "effective_residual_after_one" => penetration(corrected[:, i], clearance),
                    "repeated_steps" => steps,
                    "final_residual" => penetration(final[:, i]),
                    "final_error_from_exact" => norm(final[:, i] - exact),
                )
                push!(rows, row)
            end
        end
        write_table(joinpath(output, "summary.csv"), rows)
        println("Completed level $level: $(size(mesh.connectivity,2)) triangles")
        flush(stdout)
    end
    println("Results: $output")
end

run_diagnostic()
