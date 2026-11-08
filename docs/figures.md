# Manuscript figures and case mapping

| Figure/content | Reproduction source |
|---|---|
| Workflow / attritor | figures/attritor/run.jl; manual diagram and ParaView cutaway |
| Candidate checking | 01_classification labels; original attritor illustration requires its matching candidate dataset |
| Dominance schematic | Author-drawn conceptual figure; 09_wall_probes supplies quantitative evidence |
| Annulus cutaway | 02_annular_cylinder boundary + particle VTKs, manual ParaView |
| Dense-cube cutaway | 04_density_sweep, polydisperse whole-domain request 0.55; manual ParaView |
| Density curves | 04_density_sweep/plot_density_sweep.py |
| Cube/cylinder refinement | 08_mesh_refinement/plot_mesh_refinement.py; manual mesh/particle panels |
| Dragon surface/filling | 11_stanford_dragon mesh and assembly; provenance caveats apply |
| CPU scaling | 10_cpu_scaling/plot_problem_size_scaling.py |
| Segregation diagnostic | 06_spatial_segregation/plot_spatial_size_bias.py |

`python figures/reproduce.py` rebuilds all numerical plots from tracked reference tables.
It does not claim to reproduce hand-drawn workflow/schematic artwork or camera-specific
composites automatically. Numerical panel outputs are also exported separately. Plotters
accept explicit CSV/output paths (see --help). The dense-cube baseline is not the 0.55
cutaway; their counts and interior fractions differ. Do not substitute one for the other.
