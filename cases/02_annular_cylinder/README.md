# Annular-cylinder verification

## Purpose and configuration

Outer/inner cylinder radii 0.03/0.01; height 0.1; mesh limit 0.003. Insert 500 spheres of radius 0.0015, seed 1, CPU Float64, relative tolerance 1e-3, no purging.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/02_annular_cylinder -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/02_annular_cylinder --threads=1 cases/02_annular_cylinder/run.jl
```

Insertion writes `data/raw/generated/02_annular_cylinder/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/02_annular_cylinder/validate.jl
julia --project=common/analysis cases/02_annular_cylinder/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/02_annular_cylinder` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

500 retained; 11 iterations; no positive mesh-based pair or wall penetration. Analytical-cylinder error is a separate geometry approximation diagnostic.

## Provenance

Migrated from `prototyping/volume_inserter_tests/geometric_correctness`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
