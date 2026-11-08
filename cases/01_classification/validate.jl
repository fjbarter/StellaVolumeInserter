# Run with --project=common/validation; this file never imports Stella.
include(joinpath(@__DIR__, "..", "..", "common", "validation", "saved_data.jl"))
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "assemblies", "reference", "01_classification") :
    abspath(ARGS[1])
output = joinpath(root, "data", "processed", "generated", "01_classification")
validate_saved_case(input, output)
include(joinpath(root, "common", "validation", "classification.jl"))
validate_classification(input, output)
