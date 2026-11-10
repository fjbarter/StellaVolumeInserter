# Verification — 8 November 2026

Checks were performed on the prepared migration using Julia 1.13.3 and the unchanged local
Stella baseline. The temporary verification checkout is not part of the deliverable.

## Executed

- Resolved/instantiated all eleven case environments, shared validation/analysis and attritor.
  Sources were restored to the explicit repository-relative Stella/ block after Pkg followed
  the temporary verification symlink. Manifests contain no absolute workstation source paths.
- Parsed all 49 migrated Julia scripts without executing their experiments; compiled Python
  entry points. A harmless legacy regex warning remains in the historical Dragon audit copy.
- Ran both dense-cube references from the migrated script, including numeric/mesh/VTK export;
  both converged and passed independent saved-data checks. Reanalysis reproduced both recorded
  interior fractions to the asserted tolerance.
- Ran the standalone annular-cylinder insertion and independently checked its saved mesh and
  particles; it converged in 11 iterations with all 500 spheres retained.
- Ran six focused independent-validator tests: valid assembly, coincident overlap magnitude,
  coincident-pair rejection, outside-centre rejection, inventory mismatch and nonfinite data.
- Revalidated the saved five-domain finite-sphere checks and all ten Float32/Float64 classifier
  clouds; found no false positives, clearance violations or eligible-point false negatives.
- Revalidated the archived annulus, intersecting-cubes, bidisperse, fifty refinement and
  sixty-five scaling assemblies. Bidisperse 0.60/0.65 validate and converge; 0.70/0.75 remain
  geometric failures with no reported convergence, as originally recorded.
- Recomputed all available density-sweep packing fractions (23 returned assemblies) and all
  four bidisperse measurements using independent saved-data analysis.
- Recomputed the segregation grid controls and selected-grid statistic: I=0.03511127586304663,
  random mean=0.037768735333956645, sample SD=0.004080775919211337.
- Reaggregated all 65 scaling records and checked zero compilation/recompilation counters;
  one-million mean/sample SD are 152.8715302002/2.496774203922477 seconds.
- Checked the 360 recorded wall-probe combinations against analytical residual criteria.
  Also reran the small wall-probe diagnostic and its validator; the independently checked
  maximum final residual was 1.457167719820518e-16.
- Regenerated density, segregation, refinement and scaling numerical plots from tracked CSVs
  with Matplotlib 3.9.4. No manual image composites were regenerated.
- Verified the local compressed assembly inventory by size and SHA-256.

## Not executed or established

No new Dragon, full density sweep, bidisperse GPU insertion, full refinement insertion sweep,
or five-repeat scaling insertion sweep was launched. The attritor illustration was not rerun.
Historical Dragon convergence and timings retain experimenter provenance, not newly produced
logs. CUDA, AMDGPU, oneAPI, other OSes and an unauthenticated public clone were not tested.
No public repository or dataset archive was created. Data/geometry licensing and publication
metadata remain release tasks, not claims of readiness for unrestricted redistribution.

## Density sweep update — 9 November 2026

The prototype density sweep was rerun for five seeds per condition. The 170 original
attempts and five additional polydisperse 0.525 attempts are recorded in the repeated
reference table; 98 both reported convergence and passed the independent geometric
checks performed during those runs. The 0.525 condition was measured separately.
Repeated-run particle assemblies were not separately revalidated from an archived
numeric payload. The original single-seed verification above remains a dated audit.

## Repository density sweep verification — 9 November 2026

The repository case was run with Julia 1.13.3, one CPU thread and Stella revision
`6dbfdb956891e94fa491f2ae0a7d0af10ec7d86a`. All 175 attempts completed. Their
statuses, convergence reports, particle counts, iteration counts and packing fractions
matched the recorded repeated-sweep table for each PSD, target and seed. Timings are
independent measurements and are not expected to match exactly.

The independent saved-data validator checked all 125 returned assemblies: 98 passed
both geometry and the reported convergence criterion; seven passed geometry without
reported convergence; and 20 failed geometry. The other 50 attempts returned no
assembly. Packing3D reanalysis of all 125 returned assemblies reproduced the recorded
interior fractions within the analysis tolerance. The plot regenerated from the
reference CSV matched the manuscript density-sweep image exactly, and the fresh run
produced identical successful-repeat counts, packing statistics and iteration statistics.
The fresh outputs and check reports are in the ignored local directory
`data/raw/generated/04_density_sweep/verification_20261109/`.
