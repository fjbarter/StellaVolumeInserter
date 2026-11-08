# StellaVolumeInsertion

Reproducibility repository for **Conservative Mesh-Constrained Volume Insertion for Dense
Sphere Assemblies in Discrete Element Method Simulations**.

The eleven cases cover classification, finite-sphere geometry, packing, size distribution,
segregation, mesh sensitivity, wall corrections and CPU/GPU performance. This repository
contains experiment code and independent checks, not the Stella framework or manuscript.

## Install and run the dense-cube example

Stella is an external dependency. Until its public release, insertion requires authorised
GitHub access. Packing3D is also fetched from GitHub at a fixed commit. This repository does
not bypass access controls and does not bundle either package.

```sh
# Use your authorised GitHub access. Stella/ is temporary and ignored by Git.
git clone https://github.com/stellaorg/stella.jl Stella
git -C Stella checkout 6dbfdb956891e94fa491f2ae0a7d0af10ec7d86a
julia --project=cases/03_dense_cube -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/03_dense_cube --threads=1 cases/03_dense_cube/run.jl

# Validation and analysis are separate and do not import Stella.
julia --project=common/validation -e 'using Pkg; Pkg.instantiate()'
julia --project=common/analysis -e 'using Pkg; Pkg.instantiate()'
julia --project=common/validation cases/03_dense_cube/validate.jl data/raw/generated/03_dense_cube
julia --project=common/analysis cases/03_dense_cube/analyse.jl data/raw/generated/03_dense_cube
```

Each insertion Project.toml has a `BEGIN TEMPORARY STELLA SOURCE` block containing the
relative local path and a commented pinned GitHub alternative. See `docs/dependencies.md`
for switching sources. No absolute workstation path is needed. Julia 1.13.3 was used for
migration verification; manifests preserve the resolved dependency environments.

## Experiments

| Case | Study |
|---|---|
| 01_classification | Five domains, two point precisions, supplementary finite spheres |
| 02_annular_cylinder | Inclusion with an internal exclusion |
| 03_dense_cube | Monodisperse and polydisperse reference assemblies |
| 04_density_sweep | Whole-domain inventory and interior packing |
| 05_bidisperse | 100,000 spheres at 20:1 radius ratio; Metal |
| 06_spatial_segregation | 1:5 radius span, controls and cell-size calibration |
| 07_inclusion_exclusion | Overlapping inclusions and multiple exclusions |
| 08_mesh_refinement | Five seeds at each cube/cylinder resolution |
| 09_wall_probes | Contact hierarchy, ordering and repeated correction |
| 10_cpu_scaling | 13 sizes × five seeds, one CPU thread |
| 11_stanford_dragon | Historical CPU-thread and Metal comparison |

Cases run individually. `scripts/run_case.py` offers a common launcher and requires
`--allow-expensive` for the large insertion experiments. Do not run timing cases concurrently.
The attritor application is an illustration under `figures/attritor/`, not a validation case.

## Reproduce figures without Stella

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r figures/requirements.txt
.venv/bin/python figures/reproduce.py
```

Plots use tracked reference CSVs and write `figures/generated/`. They retain Arial (install
it locally, or Matplotlib will fall back), teal/muted red and boxed legends. The scaling
plot uses mean ± sample SD for five seeds, without individual repeat points. See
`docs/figures.md` for manual ParaView cutaways and the manuscript mapping.

## Data and scientific scope

Tracked reference tables live in `data/raw/reference/`, with processed statistics in
`data/processed/reference/`. New output is kept separately. The original local assemblies
were extracted losslessly to a compressed, untracked payload in `data/assemblies/reference/`;
its checksums and original-VTP associations are inventoried under `docs/`. That payload
needs deliberate archival and a download URL before a public release. Table analysis and
plotting remain usable without it. The Dragon asset has download/checksum instructions.

Validation recomputes geometry independently of Stella; a returned block alone does not
establish convergence. Whole-domain and interior fractions are different measures. The
bidisperse interior result is finite-region-sensitive; wall corrections are mesh/order
dependent; historical Dragon timings compare CPU Float64 with Metal Float32. See
`docs/limitations.md`, `docs/timing.md` and `docs/verification.md`.

## Citation, licence and publication

Publication identifiers and an archive DOI are not assigned here. No new licence has been
selected: framework, contributed scripts, geometries and data require their applicable
permissions to be confirmed before redistribution. See `docs/release_checklist.md`.
This local repository has not been published or pushed by the migration.
