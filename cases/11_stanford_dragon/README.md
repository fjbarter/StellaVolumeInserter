# Stanford Dragon benchmark

## Configuration

The case inserts 1,705,517 spheres into the original 100,000-triangle Dragon STL. It uses
`Uniform(0.06,0.12)` discretised into ten radius classes, seed 1, relative tolerance
`1e-2`, and no purging. CPU mode uses Float64 for both stages; Metal mode uses Metal for
both stages and Float32.

## Requirements

Use Julia 1.13.3 with this case project and the authorised `Stella/` source checkout on
`anicusan/gpu-updates` at the tested revision recorded in `docs/dependencies.md`. The GPU
mode requires a compatible Apple Metal device. `meshes/dragon2.stl` is intentionally
ignored by Git; download the original file and verify it with
`python3 scripts/check_dragon_mesh.py`.

Instantiate once from the repository root:

```sh
julia --project=cases/11_stanford_dragon -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

## CPU and GPU runs

The shared runner defaults to CPU Float64. Set Julia's thread count for the CPU comparison:

```sh
julia --project=cases/11_stanford_dragon --threads=1 cases/11_stanford_dragon/run.jl cpu
julia --project=cases/11_stanford_dragon --threads=2 cases/11_stanford_dragon/run.jl cpu
julia --project=cases/11_stanford_dragon --threads=4 cases/11_stanford_dragon/run.jl cpu
julia --project=cases/11_stanford_dragon --threads=8 cases/11_stanford_dragon/run.jl cpu
```

For Metal Float32 on both sampling and relaxation, select `metal` with the shared runner:

```sh
julia --project=cases/11_stanford_dragon --threads=1 cases/11_stanford_dragon/run.jl metal
```

The runner checks for a Metal device when this backend is selected, warms the insertion
path, synchronises device work before timing, and saves the mesh, particles, numeric data,
logs and run metadata. Set `STELLA_OUTPUT` to choose an output directory; the default is
`data/raw/generated/11_stanford_dragon/{cpu_N,metal}`. Do not run timing cases concurrently.
CPU mode does not require an available Metal device.

## Results and scope

The paper retains the experimenter-reported historical times: 2,941/1,634/915/522 s on
1/2/4/8 CPU threads and 73 s on Metal. The historical packing fraction is 0.581. Those
values remain the manuscript benchmark.

A separate run of the original prototype under Julia 1.12.5 and Stella revision
`6dbfdb956891e94fa491f2ae0a7d0af10ec7d86a` completed in 83.889 s (986 iterations; maximum
overlap 0.0006252527). A second successful prototype run reported by the user took 85.453 s
(986 iterations; maximum overlap 0.00062669814). The user noted that the machine was in Low
Power Mode. These are supplemental reproduction observations and do not replace the
historical 73-second result. The run output and metadata for the 83.889-second observation
are in the ignored directory
`data/raw/generated/11_stanford_dragon/metal_gpu_updates_julia_1_12_5/`.

Earlier attempts using the older bundled revision `f170527` with the migration environment
stopped at the stagnation guard; their logs remain under the separate generated `metal/`
and `metal_retry1/` directories. They are not the result reported above. CPU benchmark
timings have not been rerun.

## Independent validation and analysis

`run.jl` also exports numeric files needed by the independent tools.
For a new run, pass its output directory explicitly:

```sh
julia --project=common/validation cases/11_stanford_dragon/validate.jl data/raw/generated/11_stanford_dragon/metal
julia --project=common/analysis cases/11_stanford_dragon/analyse.jl data/raw/generated/11_stanford_dragon/metal
```

Full triangle-based validation of a new Dragon assembly can be expensive; a solver return
message alone is not an independent geometric check. The separately preserved prototype
VTK output is for visual inspection and does not include the numeric export required by the
validators. The historical 73-second assembly is not associated with the older tracked VTP.
