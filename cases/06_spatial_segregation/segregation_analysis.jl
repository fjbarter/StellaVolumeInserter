# Packing3D dictionaries use N×3 coordinates and stable IDs.
function particle_dataset(points, radii)
    Dict{Symbol,Any}(
        :points => permutedims(points),
        :point_data => Dict{Symbol,Any}(:id => collect(eachindex(radii)), :radius => radii),
    )
end

function split_classes(data, threshold)
    small_ids, large_ids = Packing3D.split_data(data; split_by=:radius, threshold=threshold)
    Packing3D.match_split_data(data, small_ids, large_ids)
end

# Packing3D's normalised root variance, independently reconstructed for verification.
function intensity_from_volumes(vsmall, vlarge)
    total = vsmall + vlarge
    occupied = total .> 0
    mean_concentration = sum(vsmall) / sum(total)
    concentration = vsmall[occupied] ./ total[occupied]
    variance = sum(total[occupied] .* (concentration .- mean_concentration) .^ 2) / sum(total)
    sqrt(variance / (mean_concentration * (1 - mean_concentration)))
end

# Use the public statistic with centre assignment only: each sphere contributes its full
# solid volume to its centre's cell. No cell/sphere intersection calculations are performed.
function measure_intensity(data, threshold, mesh)
    small, large = split_classes(data, threshold)
    intensity = Packing3D.calculate_segregation_intensity(
        small,
        large;
        mesh=mesh,
        calculate_partial_volumes=false,
        clamp_0_to_1=false,
    )
    vsmall, vlarge =
        Packing3D.compute_volumes_per_cell(small, large; mesh=mesh, calculate_partial_volumes=false)
    @assert isapprox(intensity, intensity_from_volumes(vsmall, vlarge); atol=1e-12)
    return intensity, vsmall, vlarge
end

function analyse_segregation(points, radii, side, output)
    data = particle_dataset(points, radii)
    threshold = median(radii)
    small_mask = radii .< threshold
    @assert 0 < count(small_mask) < length(radii)
    sphere_volume = sum(4pi / 3 .* radii .^ 3)
    nreferences = 19
    rng = MersenneTwister(2026)
    permutations = [randperm(rng, length(radii)) for _ in 1:nreferences]

    # Statistical positive control: smaller centres occupy x<L/2, larger x>L/2.
    # Even grids align with that plane, so centre assignment gives exactly pure cells.
    # This control tests the statistic, not the feasibility of an inserted packing.
    segregated = copy(points)
    segregated[1, small_mask] .= points[1, small_mask] ./ 2
    segregated[1, .!small_mask] .= side / 2 .+ points[1, .!small_mask] ./ 2
    segregated_data = particle_dataset(segregated, radii)

    rows = Dict{String,Any}[]
    reference_rows = Dict{String,Any}[]
    padding = side * 1e-10
    lower, upper = -padding, side + padding
    params = Dict(
        :x_min => lower,
        :x_max => upper,
        :y_min => lower,
        :y_max => upper,
        :z_min => lower,
        :z_max => upper,
    )
    @assert minimum(points) >= lower && maximum(points) < upper

    # Include the deliberately uninformative one-cell grid and increasingly fine grids.
    for divisions in (1, 2, 4, 6, 8, 12, 16, 24)
        mesh = Packing3D.Mesh(
            :cartesian;
            params=copy(params),
            divisions=Dict(:x => divisions, :y => divisions, :z => divisions),
        )
        observed, vsmall, vlarge = measure_intensity(data, threshold, mesh)
        positive, _, _ = measure_intensity(segregated_data, threshold, mesh)
        @assert divisions == 1 ? abs(positive) < 1e-12 : isapprox(positive, 1; atol=1e-12)
        total = vsmall + vlarge
        @assert isapprox(sum(total), sphere_volume; rtol=1e-12)

        references = Float64[]
        for (rep, permutation) in enumerate(permutations)
            # Randomly assign the existing radius/class records to the fixed centre cloud.
            random_data = particle_dataset(points[:, permutation], radii)
            intensity, _, _ = measure_intensity(random_data, threshold, mesh)
            push!(references, intensity)
            push!(
                reference_rows,
                Dict("divisions" => divisions, "replicate" => rep, "intensity" => intensity),
            )
        end
        # Predeclared diagnostic criterion: resolve a separated control, keep the random
        # reference low, and retain at least 100 particles per cell on average.
        mean_count = length(radii) / mesh.total_cells
        suitable = positive > 0.99 && mean(references) < 0.10 && mean_count >= 100
        push!(
            rows,
            Dict{String,Any}(
                "divisions" => divisions,
                "cells" => mesh.total_cells,
                "cell_width" => (upper - lower) / divisions,
                "mean_particles_per_cell" => mean_count,
                "occupied_cells" => count(>(0), total),
                "median_radius" => threshold,
                "small_count" => count(small_mask),
                "large_count" => count(.!small_mask),
                "small_solid_fraction" => sum(vsmall) / sum(total),
                "packing3d_intensity" => observed,
                "reference_mean" => mean(references),
                "reference_sd" => std(references),
                "reference_min" => minimum(references),
                "reference_max" => maximum(references),
                "perfect_segregation_intensity" => positive,
                "suitable_cell_size" => suitable,
                "assigned_volume_relative_error" => (sum(total) - sphere_volume) / sphere_volume,
                "calculate_partial_volumes" => false,
            ),
        )

        # Align cell-centre coordinates with the volume routine's x-fastest addressing.
        # Mesh row ordering has no effect on intensity when partial volumes are disabled.
        width = (upper - lower) / divisions
        centres = hcat(
            [
                [lower + (x - 0.5) * width, lower + (y - 0.5) * width, lower + (z - 0.5) * width] for z in 1:divisions for y in 1:divisions for x in 1:divisions
            ]...,
        )
        concentration = [total[i] > 0 ? vsmall[i] / total[i] : NaN for i in eachindex(total)]
        write_points(
            centres,
            output,
            "cells_$(divisions)";
            small_solid_concentration=concentration,
            packing_fraction=total / mesh.cell_volume,
        )
        write_table(
            joinpath(output, "cells_$(divisions).csv"),
            [
                Dict(
                    "cell" => i,
                    "x" => centres[1, i],
                    "y" => centres[2, i],
                    "z" => centres[3, i],
                    "small_volume" => vsmall[i],
                    "large_volume" => vlarge[i],
                    "small_solid_concentration" => concentration[i],
                ) for i in eachindex(total)
            ],
        )
        println(
            "Grid $divisions^3: inserted=$observed, random=$(mean(references)), perfectly segregated=$positive",
        )
        flush(stdout)
    end
    candidates = filter(row -> row["suitable_cell_size"], rows)
    @assert !isempty(candidates) "No grid met the predeclared control and occupancy checks"
    selected = last(candidates) # finest resolution satisfying the stated checks
    for row in rows
        row["selected"] = row["divisions"] == selected["divisions"]
    end
    write_table(joinpath(output, "segregation_summary.csv"), rows)
    write_table(joinpath(output, "randomised_references.csv"), reference_rows)
    write_table(joinpath(output, "cell_size_check.csv"), rows)
    return Dict{String,Any}(
        "median_radius" => threshold,
        "small_count" => count(small_mask),
        "large_count" => count(.!small_mask),
        "segregation_analysis" => "segregation_summary.csv",
        "packing3d_source" => "https://github.com/fjbarter/Packing3D.jl",
        "randomised_references" => nreferences,
        "calculate_partial_volumes" => false,
        "grid_min" => lower,
        "grid_max" => upper,
        "selected_divisions" => selected["divisions"],
        "selected_intensity" => selected["packing3d_intensity"],
        "selected_reference_mean" => selected["reference_mean"],
        "selected_reference_sd" => selected["reference_sd"],
        "selected_perfect_segregation_intensity" => selected["perfect_segregation_intensity"],
    )
end
