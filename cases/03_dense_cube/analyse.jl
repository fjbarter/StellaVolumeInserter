# Run with --project=common/analysis; analysis does not load Stella.
include(joinpath(@__DIR__, "..", "..", "common", "analysis", "packing.jl"))
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "assemblies", "reference", "03_dense_cube") :
    abspath(ARGS[1])
output = joinpath(root, "data", "processed", "generated", "03_dense_cube")
analyse_packing(input, output)
