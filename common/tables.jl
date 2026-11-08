using TOML

function write_summary(directory, summary)
    open(joinpath(directory, "summary.toml"), "w") do io
        TOML.print(io, summary; sorted=true)
    end
end


function write_table(path, rows)
    isempty(rows) && return write(path, "")
    columns = sort!(unique(vcat([collect(keys(row)) for row in rows]...)))
    open(path, "w") do io
        println(io, join(columns, ','))
        for row in rows
            values = ["\"" * replace(string(get(row, key, "")), '"' => "\"\"") * "\""
                      for key in columns]
            println(io, join(values, ','))
        end
    end
end


