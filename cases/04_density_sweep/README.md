# Whole-domain inventory sweep

The study uses the dense-cube geometry and PSDs described in case 03. It attempts five
independently seeded insertions at each of 17 monodisperse and 18 polydisperse whole-domain
requests. The additional polydisperse request is 0.525. Runs use one CPU thread/task/BLAS
thread, Float64, relative tolerance 1e-3, at most 2,000 iterations and no purging.

From the repository root, with the authorised Stella checkout described in the root README:

```sh
julia --project=cases/04_density_sweep -e 'using Pkg; Pkg.instantiate()'
julia --project=cases/04_density_sweep --threads=1 cases/04_density_sweep/run.jl
python3 cases/04_density_sweep/plot_density_sweep.py
```

New insertions write to `data/raw/generated/04_density_sweep/`; `STELLA_OUTPUT` selects a
different directory. Each condition has separate `seed_<n>` output. The figure reads the
tracked `data/raw/reference/04_density_sweep/density_sweep_repeats.csv` by default; pass
`--csv` to plot new output. The earlier single-seed table `density_sweep.csv` and its saved
assembly references are retained separately. To plot a completed new sweep using the
default output location, run:

```sh
python3 cases/04_density_sweep/plot_density_sweep.py \
    --csv data/raw/generated/04_density_sweep/density_sweep.csv \
    --output-dir figures/generated/04_density_sweep_new
```

The plotter requires all five seeds for every included condition. New timings and
seed-dependent results can differ from the recorded reference.

The repeated table records 175 attempts. The five polydisperse 0.525 runs were made in a
separate batch under the same settings; `run_batch` records which batch supplied each row.
The Stella source path was replaced with its repository URL in the tracked CSV to avoid a
workstation-specific path; the source revision is retained. The figure uses all eligible
monodisperse points and the polydisperse requests 0.30, 0.35, 0.40, 0.45, 0.50, 0.525,
0.55, 0.56, 0.57 and 0.58. It plots means and sample SDs for runs that both converged and
passed independent geometric checks; failed attempts remain in the CSV. Conditions with
fewer than two successful runs are omitted, and the figure lists sample counts below five.
The bulk fraction uses analytical partial sphere volumes inside the interior measurement
region, whereas the request sets inventory relative to the whole container.

The timer includes insertion and logging but excludes meshing, warm-up, final checks,
Packing3D analysis and VTK output. Per-call compilation counters were not used. The
original saved particle payload is deliberately untracked; the repeated-run VTK files and
logs are local to the original study, while the reference table records their summaries.
See `docs/data.md`, `docs/timing.md` and `docs/verification.md` for scope and provenance.
