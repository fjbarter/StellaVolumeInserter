# Independent bidisperse cell lists avoid a large-particle cell width for every small pair.
# Only this case specialises the shared validator; no Stella collision code is reused.
function pair_penetrations(positions::Matrix{Float64}, radii::Vector{Float64})
    values = sort(unique(radii))
    length(values) == 2 || return invoke(pair_penetrations, Tuple{Any,Any}, positions, radii)
    small_radius, large_radius = values
    small = findall(==(small_radius), radii)
    large = findall(==(large_radius), radii)
    width = 2small_radius
    cell(p) = (floor(Int, p[1] / width), floor(Int, p[2] / width), floor(Int, p[3] / width))
    cells = Dict{NTuple{3,Int},Vector{Int}}()
    for i in small
        push!(get!(cells, cell(view(positions, :, i)), Int[]), i)
    end
    penetration = zeros(length(radii))
    function check_pair(i, j)
        dx = positions[1, i] - positions[1, j]
        dy = positions[2, i] - positions[2, j]
        dz = positions[3, i] - positions[3, j]
        distance2 = dx * dx + dy * dy + dz * dz
        reach = radii[i] + radii[j]
        if distance2 < reach * reach
            overlap = reach - sqrt(distance2)
            penetration[i] = max(penetration[i], overlap)
            penetration[j] = max(penetration[j], overlap)
        end
    end
    for i in small
        cx, cy, cz = cell(view(positions, :, i))
        for z in cz-1:cz+1, y in cy-1:cy+1, x in cx-1:cx+1
            bucket = get(cells, (x, y, z), nothing)
            isnothing(bucket) && continue
            for j in bucket
                j > i && check_pair(i, j)
            end
        end
    end
    reach = small_radius + large_radius
    for i in large
        lower = floor.(Int, (positions[:, i] .- reach) ./ width)
        upper = floor.(Int, (positions[:, i] .+ reach) ./ width)
        for z in lower[3]:upper[3], y in lower[2]:upper[2], x in lower[1]:upper[1]
            bucket = get(cells, (x, y, z), nothing)
            isnothing(bucket) && continue
            for j in bucket
                check_pair(i, j)
            end
        end
    end
    for a in eachindex(large), b in a+1:length(large)
        check_pair(large[a], large[b])
    end
    penetration
end
