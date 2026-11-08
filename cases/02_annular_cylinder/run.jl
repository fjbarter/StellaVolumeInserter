using Stella, Random
include(joinpath(@__DIR__,"..","..","common","helpers.jl"))

mcc=@material MCC E=5e6 ν=0.4 ρ=1580.0
steel=@material Steel E=5e6 ν=0.4 ρ=7850.0
parallel=ParallelSettings(num_threads=1)
output=get(ENV,"STELLA_OUTPUT",joinpath(@__DIR__,"..","..","data","raw","generated","02_annular_cylinder"))
outer=cylinder_mesh(;radius=0.03,height=0.1,size_max=0.003)
shaft=cylinder_mesh(;radius=0.01,height=0.1,size_max=0.003)
outer_reference=mesh_reference(outer)
shaft_reference=mesh_reference(shaft)
clearance=p->min(outer_reference(p),-shaft_reference(p))
ideal=p->min(cylinder_clearance(p;radius=0.03,height=0.1),hypot(p[1],p[2])-0.01)
directory=joinpath(output,"annulus","insertion")
write_snapshot(create_triangle_wall(outer,steel),directory,"inclusion_1")
write_snapshot(create_triangle_wall(shaft,steel),directory,"exclusion_1")
warm_up(mcc;parallel)
result=run_insertion(directory;requested_count=500,
    volume=mesh_volume(outer)-mesh_volume(shaft),clearance=clearance,reference_clearance=ideal,
    relative_tolerance=1e-3,seed=1,
    settings=Dict{String,Any}("triangles"=>size(outer.connectivity,2),
        "inclusion_count"=>1,"exclusion_count"=>1)) do
    create_spheres_in_volume(500,mcc;include=(outer,),exclude=(shaft,),
        properties=FractionalDistribution(radius=0.0015),
        precision=(sampling=:double,relaxation=:double),parallel=parallel,
        relative_tolerance=1e-3,force_fill=false,verbose=2)
end
write_table(joinpath(output,"insertions.csv"),[result])
