function particle_data(particles)
    positions = Float64.(Array(particles.istate.position.view))
    subtypes = Array(particles.subtype)
    radius_lookup = Float64.(Array(particles.properties.radius.property))
    return positions, radius_lookup[subtypes]
end


function write_snapshot(block, directory, name)
    mkpath(directory)
    hasproperty(block, :shape) && hasproperty(block.shape, :mesh) && export_mesh(directory, name, block.shape.mesh)
    vtk = VTK(directory; default_renderer=false)
    settings = (precision=(integration=TypeMap(:double),),)
    host_block = Stella.convert_object(TypeMap(:double), block)
    writer = Stella.vtk_construct_writer(host_block, nothing, settings)
    Stella.vtk_write_block(
        writer, vtk, host_block, (status=(time=0.0,),);
        prefix=joinpath(directory, name),
    )
end


function run_insertion(insert, directory; requested_count, volume, clearance,
                       relative_tolerance, seed, settings=Dict{String, Any}(),
                       expected_radii=nothing, expected_fractions=nothing,
                       reference_clearance=clearance, additional_diagnostics=nothing,
                       require_compile_free=false)
    mkpath(directory)
    summary = Dict{String, Any}(
        "requested_count" => requested_count, "seed" => seed,
        "relative_tolerance" => relative_tolerance, "julia_version" => string(VERSION),
        "cpu" => Sys.CPU_NAME, "julia_threads" => Threads.nthreads(),
        "blas_threads" => BLAS.get_num_threads(),
        "domain_volume" => volume, "success" => false, "status" => "error",
        "purging_enabled" => false,
    )
    summary["cpu_model"] = try
        strip(read(pipeline(`sysctl -n machdep.cpu.brand_string`; stderr=devnull), String))
    catch
        Sys.CPU_NAME
    end
    merge!(summary, settings)
    summary["stella_source"] = "https://github.com/stellaorg/stella.jl"
    summary["stella_revision"] = try
        readchomp(`git -C $(dirname(dirname(pathof(Stella)))) rev-parse HEAD`)
    catch
        "unavailable"
    end
    Random.seed!(seed)
    GC.gc()
    particles = nothing
    log_path = joinpath(directory, "insertion.log")
    precompile(insert, ())
    elapsed = NaN
    open(log_path, "w") do log
        redirect_stdout(log) do
            redirect_stderr(log) do
                started = time_ns()
                try
                    if require_compile_free
                        # Discard any invocation that compiles; rerun the identical seeded
                        # condition. Never subtract compilation from a contaminated timing.
                        for attempt in 1:5
                            Random.seed!(seed)
                            GC.gc()
                            measured = @timed insert()
                            summary["compile_check_attempts"] = attempt
                            summary["compile_seconds"] = measured.compile_time
                            summary["recompile_seconds"] = measured.recompile_time
                            if measured.compile_time == 0 && measured.recompile_time == 0
                                particles = measured.value
                                elapsed = measured.time
                                break
                            end
                        end
                        isnothing(particles) && error("Could not obtain a compilation-free insertion timing")
                    else
                        particles = insert()
                        elapsed = (time_ns() - started) / 1e9
                    end
                catch error
                    elapsed = (time_ns() - started) / 1e9
                    error isa InterruptException && rethrow()
                    summary["error"] = sprint(showerror, error)
                    showerror(log, error, catch_backtrace())
                end
            end
        end
    end
    summary["insertion_seconds"] = elapsed
    summary["seconds_per_requested_particle"] = elapsed / requested_count
    log_text = read(log_path, String)
    summary["reported_converged"] = occursin("Successfully inserted ", log_text)
    iterations = collect(eachmatch(r"iter=(\d+)", log_text))
    summary["iterations"] = isempty(iterations) ? -1 : parse(Int, last(iterations).captures[1])
    summary["iteration_count_source"] = summary["reported_converged"] ?
        "convergence_log" : "last_reported_log"
    summary["termination_reason"] = if occursin("Insertion stagnated", get(summary, "error", ""))
        "stagnation"
    elseif haskey(summary, "error")
        "exception"
    elseif summary["reported_converged"]
        "converged"
    else
        "iteration_limit_or_validation_failure"
    end

    if !isnothing(particles)
        positions, radii = particle_data(particles)
        export_particles(directory, positions, radii)
        export_validation_input(directory, summary, expected_radii, radii)
        pair_overlap = pair_penetrations(positions, radii)
        wall_clearance = [clearance(p) for p in eachcol(positions)]
        ideal_clearance = [reference_clearance(p) for p in eachcol(positions)]
        wall_overlap = max.(0, radii - wall_clearance)
        minimum_radius = isnothing(expected_radii) ? minimum(radii) : minimum(expected_radii)
        tolerance = relative_tolerance * minimum_radius
        valid = all(isfinite, positions) && all(isfinite, radii)
        success = valid && length(radii) == requested_count &&
            minimum(wall_clearance) >= 0 && maximum(pair_overlap) <= tolerance &&
            maximum(wall_overlap) <= tolerance
        merge!(summary, Dict(
            "status" => success ? "passed" : "validation_failed", "success" => success,
            "final_count" => length(radii), "packing_fraction" => sum(4pi/3 .* radii.^3) / volume,
            "seconds_per_particle" => elapsed / length(radii), "absolute_tolerance" => tolerance,
            "max_pair_penetration" => maximum(pair_overlap),
            "max_wall_penetration" => maximum(wall_overlap),
            "centres_outside" => count(<(0), wall_clearance),
            "max_reference_wall_penetration" => maximum(max.(0, radii - ideal_clearance)),
        ))
        if !isnothing(expected_radii)
            counts = [count(r -> isapprox(r, value; rtol=1e-6), radii) for value in expected_radii]
            summary["psd_radii"] = expected_radii
            summary["psd_counts"] = counts
            summary["psd_number_fractions"] = counts / length(radii)
            summary["psd_expected_fractions"] = expected_fractions
            summary["psd_volume_fractions"] = counts .* expected_radii.^3 /
                sum(counts .* expected_radii.^3)
            summary["psd_max_number_fraction_error"] = maximum(
                abs.(counts / length(radii) - expected_fractions)
            )
            summary["psd_unmatched_particles"] = length(radii) - sum(counts)
        end
        if !isnothing(additional_diagnostics)
            merge!(summary, additional_diagnostics(positions, radii))
        end
        write_snapshot(particles, directory, "particles")
        write_points(positions, directory, "validation";
            radius=radii, pair_penetration=pair_overlap, wall_penetration=wall_overlap,
            signed_wall_clearance=wall_clearance, reference_clearance=ideal_clearance,
        )
    end
    write_summary(directory, summary)
    println(basename(directory), ": ", summary["status"], " (", round(elapsed; digits=3), " s)")
    return summary
end


# Warm compilation at a separate, inexpensive condition; never include this in timed results.
function warm_up(material; parallel=ParallelSettings(num_threads=1))
    Random.seed!(0)
    create_spheres_in_volume(
        16, material; include=box_mesh(), properties=FractionalDistribution(radius=0.04),
        precision=(sampling=:double, relaxation=:double), parallel=parallel, verbose=0,
    )
end
