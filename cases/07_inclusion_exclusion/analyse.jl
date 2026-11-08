# Numerical-table analysis needs Python's standard library only.
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "raw", "reference", "07_inclusion_exclusion") :
    abspath(ARGS[1])
run(`python3 $(joinpath(root,"scripts","analyse_case.py")) 07_inclusion_exclusion $input`)
