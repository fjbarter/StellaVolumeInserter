using Packing3D, TOML

include("../validation/saved_data.jl")
include("../tables.jl")
function analyse_packing(input, output)
    mkpath(output)
    rows = Dict{String,Any}[]
    for (directory, _, files) in walkdir(input)
        "summary.toml" in files || continue
        any(f -> f in files, ("particles.csv", "particles.csv.gz")) || continue
        s = TOML.parsefile(joinpath(directory, "summary.toml"))
        positions, radii = read_particles(find_csv(directory, "particles"))
        bounds =
            get(s, "bulk_bounds", get(s, "interior_bounds", [0.01, 0.09, 0.01, 0.09, 0.01, 0.09]))
        fraction = Packing3D._compute_packing_cartesian(
            x_data=collect(positions[1, :]),
            y_data=collect(positions[2, :]),
            z_data=collect(positions[3, :]),
            radii=radii,
            boundaries=bounds,
            calculate_partial_volumes=true,
        )
        row = Dict{String,Any}(
            "condition" => relpath(directory, input),
            "count" => length(radii),
            "whole_domain_fraction" => sum(4pi / 3 .* radii .^ 3) / s["domain_volume"],
            "interior_fraction" => fraction,
            "measurement_bounds" => bounds,
            "reported_converged" => get(s, "reported_converged", false),
            "reference_status" => get(s, "status", "unknown"),
        )
        for key in ("bulk_packing_fraction", "interior_packing_fraction")
            if haskey(s, key)
                row["difference_from_recorded_interior"] = fraction - s[key]
                @assert isapprox(fraction, s[key]; atol=1e-10, rtol=1e-9)
            end
        end
        push!(rows, row)
    end
    isempty(rows) && error("No saved assemblies with summaries in $input")
    write_table(joinpath(output, "packing_reanalysis.csv"), rows)
    println("Reanalysed ", length(rows), " packing conditions")
end
