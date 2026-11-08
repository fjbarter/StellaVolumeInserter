using LinearAlgebra
using StaticArrays

# Independent reference: triangle distances and solid-angle winding in CPU Float64.
# No Stella contact, BVH or ray-intersection routines are reused here.
function mesh_reference(mesh)
    vertices = [SVector{3, Float64}(v) for v in eachcol(mesh.vertices)]
    triangles = [(vertices[a], vertices[b], vertices[c])
                 for (a, b, c) in eachcol(mesh.connectivity)]
    function clearance(point)
        p = SVector{3, Float64}(point)
        minimum_distance2 = Inf
        solid_angle = 0.0
        for (a, b, c) in triangles
            ab, ac, ap = b - a, c - a, p - a
            normal = cross(ab, ac)
            normal2 = dot(normal, normal)
            plane_numerator = dot(ap, normal)
            projected = ap - normal * (plane_numerator / normal2)
            aa, bb, cc = dot(ab, ab), dot(ab, ac), dot(ac, ac)
            u, v = dot(projected, ab), dot(projected, ac)
            determinant = aa * cc - bb^2
            beta = (cc * u - bb * v) / determinant
            gamma = (aa * v - bb * u) / determinant
            if beta >= 0 && gamma >= 0 && beta + gamma <= 1
                distance2 = plane_numerator^2 / normal2
            else
                distance2 = Inf
                for (start, stop) in ((a, b), (b, c), (c, a))
                    edge = stop - start
                    t = clamp(dot(p - start, edge) / dot(edge, edge), 0, 1)
                    delta = p - start - t * edge
                    distance2 = min(distance2, dot(delta, delta))
                end
            end
            minimum_distance2 = min(minimum_distance2, distance2)
            ra, rb, rc = a - p, b - p, c - p
            la, lb, lc = norm(ra), norm(rb), norm(rc)
            solid_angle += 2atan(dot(ra, cross(rb, rc)),
                la * lb * lc + dot(ra, rb) * lc + dot(rb, rc) * la + dot(rc, ra) * lb)
        end
        distance = sqrt(minimum_distance2)
        return (abs(solid_angle) > 2pi ? 1 : -1) * distance
    end
    return clearance
end


function mesh_volume(mesh)
    vertices = [SVector{3, Float64}(v) for v in eachcol(mesh.vertices)]
    return abs(sum(dot(vertices[a], cross(vertices[b], vertices[c]))
                   for (a, b, c) in eachcol(mesh.connectivity))) / 6
end


# Signed clearance: positive inside, negative outside. Independent of Stella's ray code.
function box_clearance(point, lengths; origin=(0.0, 0.0, 0.0))
    q = collect(point) - collect(origin)
    inside_distance = minimum(min(q[i], lengths[i] - q[i]) for i in 1:3)
    inside_distance >= 0 && return inside_distance
    return -sqrt(sum(max(-q[i], 0, q[i] - lengths[i])^2 for i in 1:3))
end


function polygon_clearance(point, polygon)
    x, y = point[1], point[2]
    inside = false
    distance2 = Inf
    for i in eachindex(polygon)
        ax, ay = polygon[i]
        bx, by = polygon[mod1(i + 1, length(polygon))]
        ex, ey = bx - ax, by - ay
        t = clamp(((x - ax) * ex + (y - ay) * ey) / (ex^2 + ey^2), 0, 1)
        distance2 = min(distance2, (x - ax - t * ex)^2 + (y - ay - t * ey)^2)
        if (ay > y) != (by > y) && x < ax + (y - ay) * ex / ey
            inside = !inside
        end
    end
    return (inside ? 1 : -1) * sqrt(distance2)
end


function prism_clearance(point, polygon; height=1.0)
    radial = polygon_clearance(point, polygon)
    axial = min(point[3], height - point[3])
    return min(radial, axial) >= 0 ? min(radial, axial) :
        -hypot(min(radial, 0), min(axial, 0))
end


cylinder_clearance(point; radius=1.0, height=1.0) =
    min(radius - hypot(point[1], point[2]), point[3], height - point[3])


# A separate CPU cell list checks every potentially overlapping pair, including coincidences.
# Cell width is the largest particle diameter, so only the 27 neighbouring cells are needed.
function pair_penetrations(positions, radii)
    cell_width = 2maximum(radii)
    cells = Dict{NTuple{3, Int}, Vector{Int}}()
    penetration = zeros(length(radii))
    for i in eachindex(radii)
        key = Tuple(floor.(Int, positions[:, i] / cell_width))
        for dx in -1:1, dy in -1:1, dz in -1:1
            neighbour = key .+ (dx, dy, dz)
            for j in get(cells, neighbour, Int[])
                overlap = max(0, radii[i] + radii[j] - norm(positions[:, i] - positions[:, j]))
                penetration[i] = max(penetration[i], overlap)
                penetration[j] = max(penetration[j], overlap)
            end
        end
        push!(get!(cells, key, Int[]), i)
    end
    return penetration
end


