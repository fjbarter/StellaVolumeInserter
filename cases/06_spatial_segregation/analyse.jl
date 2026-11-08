using Packing3D, Statistics, Random, TOML

include(joinpath(@__DIR__, "..", "..", "common", "validation", "saved_data.jl"))
include(joinpath(@__DIR__, "..", "..", "common", "tables.jl"))
include(joinpath(@__DIR__, "..", "..", "common", "points.jl"))
include(joinpath(@__DIR__, "segregation_analysis.jl"))
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "assemblies", "reference", "06_spatial_segregation") :
    abspath(ARGS[1])
# Both the reference and run.jl save the primary assembly under insertion/.
directory = joinpath(input, "insertion")
positions, radii = read_particles(find_csv(directory, "particles"))
summary = TOML.parsefile(joinpath(directory, "summary.toml"))
output = joinpath(root, "data", "processed", "generated", "06_spatial_segregation")
mkpath(output)
result = analyse_segregation(positions, radii, summary["side_length"], output)
open(joinpath(output, "analysis.toml"), "w") do io
    TOML.print(io, result; sorted=true)
end
