function validate_classification(input, output)
    rows = Dict{String,Any}[]
    for (directory, _, files) in walkdir(input), file in files
        occursin(r"classification_.*\.points\.csv", file) || continue
        positions_data, header = numeric_csv(joinpath(directory, file))
        column = Dict(k => i for (i, k) in enumerate(header))
        positions = permutedims(positions_data[:, [column["x"], column["y"], column["z"]]])
        accepted = positions_data[:, column["accepted"]] .!= 0
        geometry_directory = joinpath(directory, "insertion")
        descriptor = TOML.parsefile(joinpath(geometry_directory, "validation_input.toml"))
        reference = boundary_reference(geometry_directory, descriptor)
        name = basename(directory)
        margin = name == "annulus" ? 1e-4 : name == "intersecting_cubes" ? 0.004 : 0.035
        # The archived diagnostics identify the numerical boundary band used originally.
        # Do not assign an inside/outside label to those probes.
        boundary =
            haskey(column, "boundary") ? positions_data[:, column["boundary"]] .!= 0 :
            falses(length(accepted))
        clearance = [reference(p) for p in eachcol(positions)]
        false_positive = count(accepted .& .!boundary .& (clearance .< 0))
        clearance_violation = count(accepted .& .!boundary .& (clearance .< margin))
        false_negative = count(.!accepted .& .!boundary .& (clearance .>= margin))
        push!(
            rows,
            Dict(
                "domain" => name,
                "file" => file,
                "points" => length(accepted),
                "false_positives" => false_positive,
                "clearance_violations" => clearance_violation,
                "false_negatives" => false_negative,
                "sampling_clearance" => margin,
            ),
        )
        @assert false_positive == clearance_violation == false_negative == 0
    end
    isempty(rows) && error("No saved classifier point exports in $input")
    open(joinpath(output, "classification_validation.toml"), "w") do io
        TOML.print(io, Dict("classifications" => rows); sorted=true)
    end
    println("Independently reclassified ", length(rows), " point clouds")
end
