# Local wall-contact diagnostic

## Purpose and configuration

Ten independent probes, radius 0.04; six cube triangulations; original/reversed/shuffled contact order; clearance 0 or 4e-5. No pair relaxation. CPU Float64. Instrumentation is installed in memory and does not edit Stella source.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/09_wall_probes -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/09_wall_probes --threads=1 cases/09_wall_probes/run.jl
```

Insertion writes `data/raw/generated/09_wall_probes/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/09_wall_probes/validate.jl
julia --project=common/analysis cases/09_wall_probes/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/09_wall_probes` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

360 combinations; raw final residual at most 1.5e-16 after repeated wall sweeps. One-step corrections can differ substantially and depend on ordering. The original-order instrumentation is checked against the production entry point.

## Provenance

Migrated from `prototyping/volume_inserter_tests/cube_wall_diagnostic`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
