# Run with --project=common/validation; this file never imports Stella.
include(joinpath(@__DIR__, "..", "..", "common", "validation", "saved_data.jl"))
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "assemblies", "reference", "04_density_sweep") :
    abspath(ARGS[1])
output = joinpath(root, "data", "processed", "generated", "04_density_sweep")
validate_saved_case(input, output)
