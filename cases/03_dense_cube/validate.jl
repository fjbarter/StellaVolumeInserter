# Run with --project=common/validation; this file never imports Stella.
include(joinpath(@__DIR__, "..", "..", "common", "validation", "saved_data.jl"))
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "assemblies", "reference", "03_dense_cube") :
    abspath(ARGS[1])
output = joinpath(root, "data", "processed", "generated", "03_dense_cube")
validate_saved_case(input, output)
