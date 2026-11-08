# Whole-domain inventory sweep

## Purpose and configuration

Same cube and PSDs as 03; 17 requests per distribution from 0.30 to 0.68, including the reference inventory and 0.005 increments near 0.55–0.58. Seed 1, one CPU thread/task/BLAS thread, Float64, tolerance 1e-3, 2000 iterations, no purging.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/04_density_sweep -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/04_density_sweep --threads=1 cases/04_density_sweep/run.jl
```

Insertion writes `data/raw/generated/04_density_sweep/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/04_density_sweep/validate.jl
julia --project=common/analysis cases/04_density_sweep/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/04_density_sweep` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

Highest plotted validated interior fractions: mono 0.607 and poly 0.628. Failures remain in raw data but are excluded from the published curves. No universal packing limit is inferred.

## Provenance

Migrated from `prototyping/volume_inserter_tests/density_sweep`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
