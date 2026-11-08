# Single-threaded problem-size scaling

## Purpose and configuration

13 counts from 1,000 to 1,000,000; five seeds 1–5 each. Radius 0.02; whole-domain fraction 0.40; grow cube by N^(1/3), preserving one 540-triangle mesh. CPU Float64; one Julia thread/task/BLAS thread; tolerance 1e-3; no purging. Reject any timing with nonzero compilation or recompilation counters.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/10_cpu_scaling -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/10_cpu_scaling --threads=1 cases/10_cpu_scaling/run.jl
```

Insertion writes `data/raw/generated/10_cpu_scaling/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/10_cpu_scaling/validate.jl
julia --project=common/analysis cases/10_cpu_scaling/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/10_cpu_scaling` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

All 65 runs validated. One-million mean±sample SD 152.87±2.50 s. Plots show mean±SD, without individual repeat points. This is problem-size scaling, not weak scaling.

## Provenance

Migrated from `prototyping/volume_inserter_tests/problem_size_scaling`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
