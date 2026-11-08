# Portable numeric exports supplement, rather than replace, ParaView files.
function export_particles(directory, positions, radii)
    classes = sort(unique(radii))
    open(joinpath(directory,"particles.csv"),"w") do io
        println(io,"id,x,y,z,radius,size_class")
        for i in eachindex(radii)
            println(io,join((i,positions[1,i],positions[2,i],positions[3,i],radii[i],
                            searchsortedfirst(classes,radii[i])),','))
        end
    end
end
function export_mesh(directory,name,mesh)
    open(joinpath(directory,name*".vertices.csv"),"w") do io
        println(io,"x,y,z")
        for p in eachcol(mesh.vertices); println(io,join(p,',')); end
    end
    open(joinpath(directory,name*".triangles.csv"),"w") do io
        println(io,"a,b,c")
        for t in eachcol(mesh.connectivity); println(io,join(t,',')); end
    end
end
function export_validation_input(directory,summary,expected_radii,radii)
    descriptor=Dict{String,Any}("requested_count"=>summary["requested_count"],
        "relative_tolerance"=>summary["relative_tolerance"],
        "minimum_radius"=>isnothing(expected_radii) ? minimum(radii) : minimum(expected_radii),
        "reported_converged"=>summary["reported_converged"])
    if haskey(summary,"side_length")
        descriptor["boundary_kind"]="box"
        descriptor["side_length"]=summary["side_length"]
    else
        descriptor["boundary_kind"]="meshes"
        descriptor["inclusions"]=[replace(f,".vertices.csv"=>"") for f in readdir(directory)
            if startswith(f,"inclusion") && endswith(f,".vertices.csv")]
        descriptor["exclusions"]=[replace(f,".vertices.csv"=>"") for f in readdir(directory)
            if startswith(f,"exclusion") && endswith(f,".vertices.csv")]
    end
    open(joinpath(directory,"validation_input.toml"),"w") do io
        TOML.print(io,descriptor;sorted=true)
    end
end
