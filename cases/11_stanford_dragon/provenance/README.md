# Dragon benchmark metadata audit (7 November 2026)

`benchmark_audit.json` separates user-confirmed benchmark settings, direct file measurements,
the environment saved with the case, and the current machine/checkout. Current facts are not
silently attributed to historical timings. No Dragon insertion was rerun for this audit.
No serial numbers, hardware UUIDs or user identifiers are included.

Verified files: binary STL has 100,000 triangles and signed enclosed volume 9967.791784635354
in raw mesh-coordinate units cubed. SHA-256 identifies the exact mesh. Its Netfabb/MM header
is a file annotation, not evidence that the DEM coordinate convention is millimetres.
The original download location and any repairs/rescaling are not established by that header.

The existing VTP has 1,705,517 particles and ten radius classes, but its sphere-volume sum
divided by the signed mesh volume is 0.5793269695441083. It is not linked to the reported
73-second run; do not present it as independent verification of that run or its 0.581 target.
The stored Float32 coordinates/radii describe export precision, not proven solver precision.

The user confirmed that the 73-second run used Metal for both sampling and relaxation.
The current editable dragon.jl uses Metal sampling and CPU Float64 relaxation, so it is not
an exact reproduction of that configuration. Preserve user edits; choose both stage backends
explicitly when making a future benchmark runner. The saved manifest records Julia 1.12.5,
Stella 0.1.0, Metal 1.11.1, AcceleratedKernels 0.4.4, ImplicitBVH 0.7.1 and
KernelAbstractions 0.9.45. This does not prove the runtime/version used for each timed run.

The machine inspected for this audit has 18 CPU cores, 20 GPU cores and 48 GiB unified
memory, with macOS 26.6.2 (25G83). The raw System Profiler core descriptor is retained in the JSON; CPU affinity was not
recorded, so thread counts do not identify which physical core classes executed a run.

## Experimenter-confirmed run protocol

The experimenter confirms compilation warm-up, use of the inserter's printed elapsed times,
and GPU synchronisation for accurate measurement. CPU sampling and relaxation use Float64;
Metal sampling and relaxation use Float32. The original Thingiverse mesh was not altered.
The manuscript reports packing fraction 0.581 as supplied for the benchmark; the separate
file-level audit of the older, unlinked VTP is retained without relabelling that export.
All reported runs converged under the stated settings. Exact iteration counts, runtime
Julia version and source revision were not supplied and are not invented. No rerun is needed
or requested for this update. The previously recorded uncertainties about timing, warm-up,
precision and mesh alteration are superseded by this confirmation.

`audit_files.py` can be run from any working directory with Python 3; it regenerates
`file_audit.json` from the STL and existing raw-appended, zlib-compressed VTP. It checks
file structure and extracts volume/bin counts without loading Stella or advancing dynamics.
