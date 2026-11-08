# Surface triangulation sensitivity

## Purpose and configuration

800 monodisperse spheres at ideal-domain fraction 0.40. Cube mesh sizes 1,1/2,1/4,1/8,1/16,1/32; cylinder sizes 0.8,0.4,0.2,0.1. Five seeds at each mesh; CPU Float64, tolerance 1e-3, no purging. Includes the original single-step probes; detailed tracing is in 09.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/08_mesh_refinement -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/08_mesh_refinement --threads=1 cases/08_mesh_refinement/run.jl
```

Insertion writes `data/raw/generated/08_mesh_refinement/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/08_mesh_refinement/validate.jl
julia --project=common/analysis cases/08_mesh_refinement/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/08_mesh_refinement` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

30 cube + 20 cylinder insertions validated. Cube means 129.8–135.2 iterations; cylinder volume error 7.06% to 0.124%. Local correction invariance is not established.

## Provenance

Migrated from `prototyping/volume_inserter_tests/mesh_refinement`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
