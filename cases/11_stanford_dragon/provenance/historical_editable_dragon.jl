using Stella
using Distributions

using Random
Random.seed!(1)

using Metal

# Define materials used in the simulation
mcc = @material MCC E=5e6 ν=0.4 ρ=1580.0
steel = @material Steel E=5e6 ν=0.4 ρ=7850.0


dragon = create_triangle_wall("dragon2.stl", steel)

radii = FractionalDistribution(Uniform(0.06, 0.12))

# Estimate the dragon's enclosed volume using the volume inserter's Monte Carlo method.
mc_samples = 100_000
sampling_typemap = Stella.TypeMap(Metal)
parallel = ParallelSettings()
inclusion_bvhs = (
    Stella.build_triangle_query_bvh(
        dragon.shape.mesh, sampling_typemap; parallel=parallel,
    ),
)
mins, maxs = Stella.compute_bounds(inclusion_bvhs)
aabb_volume = Stella.compute_aabb_volume(mins, maxs)
ray_batch = Stella.RayBatchBuffer(
    sampling_typemap; num_points_in_batch=mc_samples, parallel=parallel,
)
valid_batch = similar(ray_batch.positions, Bool, mc_samples)
dragon_volume = Stella.estimate_internal_volume_mc(
    inclusion_bvhs, (),
    mins, maxs, aabb_volume, zero(sampling_typemap.reals),
    (rng=Random.MersenneTwister(1), parallel=parallel);
    ray_batch, valid_batch, mc_samples,
)
println("Dragon mesh volume: $dragon_volume (mesh units^3)")

# Make particles
particles = create_spheres_in_volume(
    1_705_517,
    mcc;
    include=dragon,
    properties=FractionalDistribution(
        radius=radii
    ),
    precision=(
        sampling=Metal,
        relaxation=:double,
    ),
    verbose=2,
    relative_tolerance=1e-2
)

# Write a single VTK snapshot of the inserted particles without running a simulation.
vtk = VTK(joinpath(@__DIR__, "results"); default_renderer=false)
vtk_settings = (precision=(integration=Stella.TypeMap(Metal),),)
vtk_writer = Stella.vtk_construct_writer(particles, nothing, vtk_settings)
Stella.vtk_write_block(
    vtk_writer, vtk, particles, (status=(time=0.0,),);
    prefix=joinpath(vtk.directory, "particles"),
)

# Save the Dragon boundary alongside the particles for inspection in ParaView.
wall_writer = Stella.vtk_construct_writer(dragon, nothing, vtk_settings)
Stella.vtk_write_block(
    wall_writer, vtk, dragon, (status=(time=0.0,),);
    prefix=joinpath(vtk.directory, "inclusion"),
)
