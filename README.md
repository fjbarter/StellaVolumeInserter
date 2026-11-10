# StellaVolumeInserter

Reproducibility repository for **Fast, GPU-Accelerated Dense Sphere Packing in Complex
Geometries**.

The eleven cases cover classification, finite-sphere geometry, packing, size distribution,
segregation, mesh sensitivity, wall corrections and CPU/GPU performance. This repository
contains experiment code and independent checks, not the Stella framework or manuscript.

## Install and run the dense-cube example

Stella is an external dependency. The examples use a local Stella checkout at the tested
revision below; Packing3D is fetched from GitHub at a fixed commit. This repository does
not bundle either package.

```sh
# Stella/ is a temporary dependency checkout and is ignored by Git.
git clone --single-branch --branch anicusan/gpu-updates https://github.com/stellaorg/stella.jl Stella
# Check out the tested revision.
git -C Stella checkout --detach 6dbfdb956891e94fa491f2ae0a7d0af10ec7d86a
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
| 05_bidisperse | Archived exploratory case; excluded from the current manuscript |
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
its checksums and original-VTP associations are inventoried under `docs/`. The original
assemblies are not distributed; readers can regenerate assemblies using the case scripts.
Table analysis and plotting remain usable without them. The Dragon asset has download/checksum instructions.

Validation recomputes geometry independently of Stella; a returned block alone does not
establish convergence. Whole-domain and interior fractions are different measures. The
bidisperse interior result is finite-region-sensitive; wall corrections are mesh/order
dependent; historical Dragon timings compare CPU Float64 with Metal Float32. See
`docs/limitations.md`, `docs/timing.md` and `docs/verification.md`.

## Citation, licence and publication

The repository code is licensed under the GNU Affero General Public License, version 3;
see `LICENSE`. External packages and the separately downloaded Dragon mesh have their own
licences. Publication identifiers and an archive DOI are not assigned here. See
`docs/release_checklist.md`.
The reproducibility repository is publicly hosted at
https://github.com/fjbarter/StellaVolumeInserter. See the dependency and release notes
for the Stella revision and other materials used by the experiments.
