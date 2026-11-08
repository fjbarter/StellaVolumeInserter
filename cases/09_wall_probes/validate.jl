# Probe residual checks use the recorded CSV traces, without loading Stella.
root=normpath(joinpath(@__DIR__,"..",".."))
input=isempty(ARGS) ? joinpath(root,"data","raw","reference","09_wall_probes") : abspath(ARGS[1])
run(`python3 $(joinpath(root,"scripts","analyse_case.py")) 09_wall_probes $input --validate-probes`)
