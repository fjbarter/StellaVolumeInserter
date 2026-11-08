# Stanford Dragon benchmark

## Purpose and configuration

Original 100,000-triangle STL; 1,705,517 spheres; ten-bin approximation to Uniform(0.06,0.12); tolerance 1e-2, no purging. CPU Float64 at 1/2/4/8 threads; Metal Float32 for both stages. Seed 1 is the retained configuration.

## Requirements

See the root README for the temporary authorised `Stella/` checkout and pinned GitHub
Packing3D source. Julia 1.13.3 is the migration verification environment. GPU cases require
Metal.jl and compatible Apple hardware. The source environment manifests, where retained,
are recorded separately from the newly resolved reproducibility manifests.

## Reproduction

From the repository root:

```sh
julia --project=cases/11_stanford_dragon -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/11_stanford_dragon --threads=1 cases/11_stanford_dragon/run.jl
```

Insertion writes `data/raw/generated/11_stanford_dragon/`; set `STELLA_OUTPUT` to choose another
location. Meshes and particles are exported as VTK and portable numeric CSVs. Timing
excludes output, independent validation and analysis; see `docs/timing.md` for exceptions
and the historical protocol.

## Saved-data validation and analysis

```sh
julia --project=common/validation cases/11_stanford_dragon/validate.jl
julia --project=common/analysis cases/11_stanford_dragon/analyse.jl
```

Defaults use the local reference assembly payload or tracked reference tables, without
Stella. For new results, append `data/raw/generated/11_stanford_dragon` explicitly to each command.
Reference assembly data are inventoried but deliberately untracked; see `docs/data.md`.
The wall-probe validator instead checks the recorded analytic residual CSVs. Cases with
Packing3D analysis require its pinned GitHub dependency, independently of Stella.

## Recorded result and scope

Historical experimenter-reported times: 2941/1634/915/522 s on CPU, 73 s on Metal. These were not rerun during migration. Reported density 0.581 is the historical benchmark figure; the older saved VTP is not linked to the timed run.

Obtain/check the mesh using `meshes/README.md` and `python3 scripts/check_dragon_mesh.py`.
Run each configuration in a separate process with other workloads idle:

```sh
julia --project=cases/11_stanford_dragon --threads=1 cases/11_stanford_dragon/run.jl cpu
julia --project=cases/11_stanford_dragon --threads=2 cases/11_stanford_dragon/run.jl cpu
julia --project=cases/11_stanford_dragon --threads=4 cases/11_stanford_dragon/run.jl cpu
julia --project=cases/11_stanford_dragon --threads=8 cases/11_stanford_dragon/run.jl cpu
julia --project=cases/11_stanford_dragon --threads=1 cases/11_stanford_dragon/run.jl metal
```

New runs warm up and reject compilation-contaminated timings; synchronised external and
inserter-printed times are recorded separately. BLAS is fixed to one for new reproductions;
that setting was not recorded for the historical measurements. Run/analyse/validate never
replace historical CSVs. Full independent triangle-based Dragon validation is potentially
very expensive; it is not a quick benchmark check and requires a supplied new assembly.
The provenance script retains its historical mixed-backend settings deliberately, but is not
the runnable benchmark. No new Dragon run or validation of the 73-second assembly is claimed.

## Provenance

Migrated from `prototyping/volume_inserter_tests/stanford_dragon`. Original scripts are unchanged.
See `docs/migration.md`, `docs/assembly_provenance.csv`, the per-condition summaries and
`docs/verification.md` for the checks actually executed. Failed and unconverged conditions
remain distinguishable from successful assemblies. These are geometric initialisation tests,
not demonstrations of mechanical equilibrium.
