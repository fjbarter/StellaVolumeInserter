using Stella
using Random
using Distributions: Uniform
import StellaGmsh as G
using Metal

Random.seed!(42)

# Materials and insertion geometry match examples/attritor_mill.
mcc = @material MCC ρ=1500.0 E=5e6 ν=0.4
steel = @material Steel ρ=7850.0 E=5e6 ν=0.4
output = joinpath(@__DIR__,"..","generated","attritor")

# The vessel is the inclusion; the shaft and fused arms form the exclusion.
cylinder_mesh = G.with_gmsh(argv=["", "-v", "0"]) do
    G.Cylinder((0.0, 0.0, 0.0), (0.0, 0.0, 80e-3), 30e-3)
    G.mesh(size_max=2e-3)
end
cylinder = create_triangle_wall(cylinder_mesh, steel)

attritor_mesh = G.with_gmsh(argv=["", "-v", "0"]) do
    G.gmsh.open(joinpath(@__DIR__, "attritor.geo"))
    G.mesh(size_max=1e-4)
end
attritor = create_triangle_wall(attritor_mesh, steel)

# Write static snapshots directly, without constructing or advancing a simulation.
vtk = VTK(output; default_renderer=false)
vtk_settings = (precision=(integration=Stella.TypeMap(:double),),)
function write_snapshot(block, name)
    block = Stella.convert_object(Stella.TypeMap(:double), block)
    writer = Stella.vtk_construct_writer(block, nothing, vtk_settings)
    Stella.vtk_write_block(
        writer, vtk, block, (status=(time=0.0,),);
        prefix=joinpath(output, name),
    )
end

# Save both boundary meshes before insertion, including if relaxation later fails.
write_snapshot(cylinder, "inclusion")
write_snapshot(attritor, "exclusion")

# Ten equal-probability bins across the original radius range.
psd = FractionalDistribution(Uniform(0.0006, 0.0008); nbins=10, tail_trim_fraction=0)

# Preserve the expected total sphere volume of the previous 40,000-particle PSD.
reference_mean_radius_cubed = 0.2 * 0.0006^3 + 0.5 * 0.0007^3 + 0.3 * 0.0008^3
mean_radius_cubed = sum(psd.distribution.p .* psd.support.^3)
# num_particles = round(Int, 40_000 * reference_mean_radius_cubed / mean_radius_cubed)
max_theoretical = 118665
desired_packing = 0.6
num_particles = round(Int, desired_packing * max_theoretical)
println("Uniform PSD: $num_particles particles in 10 radius bins")
particles = create_spheres_in_volume(
    num_particles,
    mcc;
    include=cylinder,
    exclude=attritor,
    properties=FractionalDistribution(radius=psd),
    verbose=2,
    precision=(
        sampling=Metal,
        relaxation=Metal
    )
)
write_snapshot(particles, "particles")
