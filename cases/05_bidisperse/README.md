# High size-ratio bidisperse attempt

## Purpose and configuration

100,000 spheres; radii 0.001/0.020; small:large number ratio 2880:1. Seed 1, both stages Metal Float32, tolerance 1e-3, no purging. Requests 0.60/0.65/0.70/0.75. Default new-run allowance is 12,000; the archived lower requests were extended to that allowance, while 0.70/0.75 retained 4,000.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/05_bidisperse -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/05_bidisperse --threads=1 cases/05_bidisperse/run.jl
```

Insertion writes `data/raw/generated/05_bidisperse/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/05_bidisperse/validate.jl
julia --project=common/analysis cases/05_bidisperse/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/05_bidisperse` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

At request 0.65: 99,966 small + 34 large spheres, 4,719 iterations; whole-domain 0.6402, interior 0.7725 with one-large-radius wall margin, 0.6696 with two-small-radius margin. Higher requests are unvalidated. The finite interior measure is not a packing limit.

`MAXIMUM_FRACTIONS=0.60,0.65` selects requests; `MAXIMUM_ITERATIONS=12000` sets the budget. To reproduce the archived higher-request budget, run `MAXIMUM_FRACTIONS=0.70,0.75 MAXIMUM_ITERATIONS=4000`.

## Provenance

Migrated from `prototyping/volume_inserter_tests/maximum_attempt`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
