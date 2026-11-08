using WriteVTK

function write_points(positions, directory, name; fields...)
    mkpath(directory)
    scalar_fields = [
        (key, values) for (key, values) in fields if
        values isa AbstractVector && length(values) == size(positions, 2)
    ]
    open(joinpath(directory, name * ".points.csv"), "w") do io
        println(io, join(("x", "y", "z", string.(first.(scalar_fields))...), ','))
        for i in axes(positions, 2)
            println(
                io,
                join(
                    (
                        positions[1, i],
                        positions[2, i],
                        positions[3, i],
                        (v[i] for (_, v) in scalar_fields)...,
                    ),
                    ',',
                ),
            )
        end
    end
    cells = [MeshCell(VTKCellTypes.VTK_VERTEX, [i]) for i in axes(positions, 2)]
    vtk_grid(joinpath(directory, name), positions, cells) do vtk
        for (key, values) in fields
            vtk[string(key)] = values
        end
    end
end
