# Run with --project=common/analysis; analysis does not load Stella.
include(joinpath(@__DIR__, "..", "..", "common", "analysis", "packing.jl"))
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "assemblies", "reference", "05_bidisperse") :
    abspath(ARGS[1])
output = joinpath(root, "data", "processed", "generated", "05_bidisperse")
analyse_packing(input, output)
