# Dependency sources and versions

All insertion cases use the deliberately temporary repository-root `Stella/` checkout.
Its path is `../../Stella` from a case or attritor project. `/Stella/` is ignored by Git.
Clone using authorised access; checkout `6dbfdb956891e94fa491f2ae0a7d0af10ec7d86a`
for the source baseline used here. Record a different revision explicitly for new studies.
Do not copy or commit the framework into this repository.

To switch to GitHub, replace only the marked temporary block in each insertion
Project.toml with its commented `Stella = {url = ..., rev = ...}` line. Then run
`julia --project=<case> -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'` and commit both
Project.toml and Manifest.toml. Editing Project.toml alone leaves the manifest's local path
active; both must be updated. Remove the obsolete markers when the switch is complete.

Packing3D is pinned to GitHub commit `d437dff33a3019bb28eda2796feae533a02123b7`, whose
Git tree `1bac8d5f34a70ea9af7792044a09410a45e619fa` matches the recorded packing analyses.
It is never taken from a local sibling checkout. StellaGmsh is registry-resolved, with the
exact package and Gmsh versions in each manifest. Geometry generators can produce different
triangulations under different versions, so use the saved environments and actual recorded
triangle counts rather than assuming mesh identity from element size alone.

common/validation and common/analysis have separate projects without Stella. The former
uses standard numeric I/O, CodecZlib and independent geometric routines; the latter also
uses Packing3D and WriteVTK. Every run/analyse/validate script documents its intended project.
The legacy source environments retained under docs/historical_environments are provenance,
not the active projects. Missing legacy manifests were not invented. Newly resolved projects
are reproducibility environments verified with Julia 1.13.3, not claims about every historical
runtime version. Never commit LocalPreferences.toml credentials or a local .env file.
