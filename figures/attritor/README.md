# Attritor workflow illustration

Copied from the current prototyping attritor case, including its user-edited fine exclusion
mesh and ten-bin uniform 0.6–0.8 mm radius distribution. Count is round(0.6*118665)=71199.
Sampling and relaxation use Metal. This performs insertion and static export only; no time
integration, gravity, contacts or shaft rotation are configured.

Run `julia --project=figures/attritor -e 'using Pkg;Pkg.instantiate()'`, then
`julia --project=figures/attritor figures/attritor/run.jl` from the repository root.
Both inclusion/exclusion meshes are written before insertion; particles follow if returned.
Output is figures/generated/attritor/. Prepare the cutaway/camera in ParaView manually.
This is a workflow illustration, not a validated or timed benchmark; the volume factor is a
nominal inventory estimate, not an independently measured bulk fraction. No rerun was made
while migrating. Its local Stella source block follows the same temporary convention.
