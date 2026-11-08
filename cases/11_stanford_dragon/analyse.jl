# Numerical-table analysis needs Python's standard library only.
root = normpath(joinpath(@__DIR__, "..", ".."))
input =
    isempty(ARGS) ? joinpath(root, "data", "raw", "reference", "11_stanford_dragon") :
    abspath(ARGS[1])
run(`python3 $(joinpath(root,"scripts","analyse_case.py")) 11_stanford_dragon $input`)
