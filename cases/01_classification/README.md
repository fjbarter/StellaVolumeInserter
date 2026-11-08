# Point classification and supplementary finite-sphere checks

## Purpose and configuration

Five domains: box, cylinder, annulus, concave prism and intersecting cubes. Float32/Float64 point tests; 5,000 random points per domain plus targeted probes. Margins are 0.035, 0.035, 0.0001, 0.035 and 0.004 respectively. Random seed 1, except annular point sampling seed 42. The finite-sphere supplementary runs use seed 1 and CPU Float64.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/01_classification -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/01_classification --threads=1 cases/01_classification/run.jl
```

Insertion writes `data/raw/generated/01_classification/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/01_classification/validate.jl
julia --project=common/analysis cases/01_classification/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/01_classification` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

No false positives, clearance violations or false negatives among mesh-clearance-eligible points. Numerical boundary-band probes and intentional clearance rejections remain separate.

## Provenance

Migrated from `prototyping/volume_inserter_tests/geometric_correctness`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
