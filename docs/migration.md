# Migration record — 8 November 2026

The original prototyping scripts and results were read/copied, not moved or edited.
The existing destination contained only .git at initial inspection. The eleven-case split
extracts classification/annulus/obstacle configurations from geometric_correctness and
extracts the two reference inventories from density_sweep. Shared validators were separated
from Stella-dependent generation. Saved-data analysis runs without Stella; the temporary
local Stella source was requested explicitly by the experimenter.

The cancelled stanford_dragon_repeat, unrelated rotating-drum/RAM/li_benchmark experiments,
framework source and manuscript are excluded. The attritor is an illustration, copied with
its current user-edited geometry/PSD/count settings; it is not treated as independently
validated performance evidence. Ten superseded one-seed refinement exports and the old
single-run scaling exports were excluded in favour of the paper's 50 and 65 repeated runs.
Failed density/bidisperse attempts remain recorded. Some failed insertions have no returned
assembly; a summary is retained rather than fabricating particle data.

The active manifests were resolved with Julia 1.13.3. Selected historical source
environments are retained separately for provenance; the active projects and manifests
should be used to run the cases. Stella's current
source baseline is commit 6dbfdb956891e94fa491f2ae0a7d0af10ec7d86a. The framework itself is
not copied. Packing3D's pinned GitHub commit/tree match the saved analysis environment.

No expensive scaling sweep, bidisperse insertion or Dragon benchmark was rerun for migration.
Original manuscript figures and text are unchanged. See verification.md for actual checks.
