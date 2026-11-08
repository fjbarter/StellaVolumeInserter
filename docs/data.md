# Data layout and numeric schema

- data/raw/reference/<case>: tracked original numerical tables and per-condition summaries.
- data/processed/reference/<case>: tracked original aggregated statistics.
- data/assemblies/reference/<case>: untracked local reference payload, losslessly extracted
  from existing VTPs, with independent boundary geometry and validation descriptors.
- data/raw/generated/<case>: new insertions, numeric particles, boundaries, logs and VTKs.
- data/processed/generated/<case>: independently regenerated validation/analysis products.
- figures/generated/<case>: regenerated numerical plots.

A particles.csv[.gz] has id,x,y,z,radius,size_class. Floating-point values are exported at
round-trip precision from the saved numeric representation. VTK export precision can differ
from historical solver precision; decoding it does not recover discarded solver digits.
A mesh has <name>.vertices.csv[.gz] with x,y,z and <name>.triangles.csv[.gz] with a,b,c
(one-based vertex indices). Separate meshes retain their inclusion/exclusion identities.
validation_input.toml records count, minimum prescribed radius, relative tolerance, reported
convergence and either analytic box size or inclusion/exclusion mesh stems.

summary.toml records geometry settings, count, PSD diagnostics, tolerances, timing,
convergence and independent checks when available. Scientific validation must distinguish
reported_converged from status=passed: historical status can describe geometry even when
relaxation did not report convergence. Only both together give a validated converged assembly.
Classification *.points.csv[.gz] additionally preserve acceptance flags, targeted/random
labels and the original numerical boundary-band classification.

The payload inventory is docs/assembly_inventory.csv.
It records repository-relative paths, byte counts and SHA-256. docs/assembly_provenance.csv
links each extracted particle payload to its original VTP checksum and particle count.
Workstation paths were removed from distributable metadata. Original files are untouched.
Use `python3 scripts/check_payload.py` to check a local payload or a later downloaded archive.
The payload is available in this local checkout but will not be present in a plain Git clone
until a release archive is published; add its permanent URL before advertising complete
saved-assembly reproduction. New runs need no reference payload.
