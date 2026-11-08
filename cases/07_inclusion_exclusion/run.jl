using Stella, Random
include(joinpath(@__DIR__,"..","..","common","helpers.jl"))

mcc=@material MCC E=5e6 ν=0.4 ρ=1580.0
steel=@material Steel E=5e6 ν=0.4 ρ=7850.0
parallel=ParallelSettings(num_threads=1)
output=get(ENV,"STELLA_OUTPUT",joinpath(@__DIR__,"..","..","data","raw","generated","07_inclusion_exclusion"))
box1=box_mesh((0.1,0.1,0.1);size_max=0.01)
box2=box_mesh((0.1,0.1,0.1);origin=(0.07,0.07,0.07),size_max=0.01)
obstacle1=box_mesh((0.05,0.05,0.05);size_max=0.01)
obstacle2=box_mesh((0.05,0.05,0.05);origin=(0.14,0.14,0.14),size_max=0.01)
# Same analytical union/exclusion reference as the original regression case.
clearance=p->min(max(box_clearance(p,(0.1,0.1,0.1)),
                    box_clearance(p,(0.1,0.1,0.1);origin=(0.07,0.07,0.07))),
                -box_clearance(p,(0.05,0.05,0.05)),
                -box_clearance(p,(0.05,0.05,0.05);origin=(0.14,0.14,0.14)))
directory=joinpath(output,"intersecting_cubes","insertion")
for (i,mesh) in enumerate((box1,box2))
    write_snapshot(create_triangle_wall(mesh,steel),directory,"inclusion_$i")
end
for (i,mesh) in enumerate((obstacle1,obstacle2))
    write_snapshot(create_triangle_wall(mesh,steel),directory,"exclusion_$i")
end
warm_up(mcc;parallel)
result=run_insertion(directory;requested_count=2000,
    volume=2*0.1^3-0.03^3-0.05^3-0.03^3,clearance=clearance,
    relative_tolerance=1e-3,seed=1,
    settings=Dict{String,Any}("triangles"=>size(box1.connectivity,2)+size(box2.connectivity,2),
        "inclusion_count"=>2,"exclusion_count"=>2)) do
    create_spheres_in_volume(2000,mcc;include=(box1,box2),exclude=(obstacle2,obstacle1),
        properties=FractionalDistribution(radius=0.004),
        precision=(sampling=:double,relaxation=:double),parallel=parallel,
        relative_tolerance=1e-3,force_fill=false,verbose=2)
end
write_table(joinpath(output,"insertions.csv"),[result])
