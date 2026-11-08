# Scientific and implementation scope

Independent checks include coincident particle centres, outside centres and overlaps.
The pinned Stella pair-correction code currently skips d²<=0 and records zero overlap;
this can miss exact coincident-centre pairs internally. The repository's external validator
rejects them. Migration does not fix or modify Stella. No claim is made that random sampling
eliminates this degeneracy. Use a newer source only with its revision recorded and rerun
appropriate checks; historical evidence remains tied to its recorded source/configuration.

Wall hierarchy corrections can depend on triangulation and order. Shared-feature suppression
is not coplanar-plane merging or a minimum-translation projection. Probe feasibility after
repeated sweeps does not imply identical final contact networks or packing statistics.

Whole-domain requests set inventory; interior packing uses a separately defined region and
partial volumes. The bidisperse one-large-radius margin and its small inventory of large
spheres produce strong finite-region sensitivity. No theoretical or algorithmic packing
maximum was determined. Density curves omit unsuccessful points but raw data retain them.

Segregation controls calibrate one statistic/scale. Partial volumes are disabled for that
study. No global proof of spatial unbiasedness or direct competing-method comparison follows.
Geometric admissibility is distinct from mechanical equilibrium. Portable backend interfaces
do not establish measured performance on untested CUDA, AMDGPU or oneAPI devices.
