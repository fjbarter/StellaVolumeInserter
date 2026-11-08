# Dense-cube reference conditions

## Purpose and configuration

Cube side 0.1; mesh size 0.01. Mono: N=1000, radius 0.005. Poly: N=2036, radii [0.003,0.004,0.005], number fractions [0.4,0.4,0.2]. Seed 1, CPU Float64, relative tolerance 1e-3, no purging. Interior region [0.01,0.09]^3 uses partial sphere volumes.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/03_dense_cube -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/03_dense_cube --threads=1 cases/03_dense_cube/run.jl
```

Insertion writes `data/raw/generated/03_dense_cube/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/03_dense_cube/validate.jl
julia --project=common/analysis cases/03_dense_cube/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/03_dense_cube` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

Mono interior fraction 0.59384, 690 iterations; poly interior fraction 0.59095, 528 iterations. These are the baseline references, not the separate 0.55-request cutaway.

## Provenance

Migrated from `prototyping/volume_inserter_tests/density_sweep`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
