# Timing and hardware

Historical hardware audit: MacBook Pro, Apple M5 Pro, 18 CPU cores, integrated 20-core GPU,
48 GiB unified memory; macOS 26.6.2 (25G83), inspected 7 November 2026. These are audit facts,
not inferred historical affinity, power mode or thermal conditions. No serial/UUID is stored.

CPU scaling uses one Julia thread, one Stella task and one BLAS thread, CPU Float64 in both
stages, fixed radius 0.02 and requested whole-domain fraction 0.40. It has 13 sizes and five
seeds each. Warm-up, RNG reseeding, GC, meshing, independent validation, analysis and exports
are outside the timer. Timed calls include insertion and verbose diagnostic logging. Calls
with nonzero Julia compile/recompile counters are discarded, never corrected by subtraction.
All 65 accepted reference calls have zero counters. Means and sample SD use denominator n−1.

Density sweeps warm both subtype layouts before timing but do not have the scaling study's
explicit per-call zero-compilation acceptance test. Other validation timing is diagnostic;
do not relabel it as a rigorous performance benchmark.

Dragon timings are the experimenter-confirmed historical inserter-printed elapsed times,
after compilation warm-up and GPU synchronisation: CPU 1/2/4/8 threads = 2941/1634/915/522 s;
Metal = 73 s. CPU sampling/relaxation are Float64 and Metal sampling/relaxation Float32;
relative tolerance is 1e-2 and no purging is used. Exact historical source revision and CPU
core affinity were not recorded. The retained manifest is provenance, not proof of each
runtime version. The old particle export is not associated with the timed run. Historical
reported packing fraction 0.581 must not be assigned to newly generated assemblies without
measuring them. New Dragon commands explicitly select both backends and record compilation
counters; they are not reruns performed during this migration.

Li et al.'s approximately 16-hour runtime is cross-platform context, not an isolated
algorithmic speedup or equal-error comparison. Their stopping criterion differs. The CPU
particle-count sweep is problem-size scaling, not weak scaling or GPU scaling.
