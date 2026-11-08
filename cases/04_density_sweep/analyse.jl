# Run with --project=common/analysis; analysis does not load Stella.
include(joinpath(@__DIR__, "..", "..", "common", "analysis", "packing.jl"))
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "assemblies", "reference", "04_density_sweep") :
    abspath(ARGS[1])
output = joinpath(root, "data", "processed", "generated", "04_density_sweep")
analyse_packing(input, output)
