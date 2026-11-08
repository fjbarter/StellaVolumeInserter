# Spatial size segregation

## Purpose and configuration

20,000 spheres; 20 equally probable radii including endpoints 0.001–0.005; whole-domain request 0.50, seed 1, CPU Float64, tolerance 1e-3. Split at empirical median; ties enter larger class. Full-volume centre assignment on an enclosing Cartesian grid, no partial volumes. Nineteen random controls use seed 2026; grid divisions 1,2,4,6,8,12,16,24.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/06_spatial_segregation -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/06_spatial_segregation --threads=1 cases/06_spatial_segregation/run.jl
```

Insertion writes `data/raw/generated/06_spatial_segregation/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/06_spatial_segregation/validate.jl
julia --project=common/analysis cases/06_spatial_segregation/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/06_spatial_segregation` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

Selected grid 4^3; inserted intensity 0.0351; random mean±SD 0.0378±0.0041; perfect-segregation control 1.0. Controls calibrate the statistic, not physical packings.

## Provenance

Migrated from `prototyping/volume_inserter_tests/spatial_size_bias`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
