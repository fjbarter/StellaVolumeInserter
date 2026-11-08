using DelimitedFiles, TOML, CodecZlib
include("geometry.jl")

function numeric_csv(path)
    stream = endswith(path,".gz") ? GzipDecompressorStream(open(path)) : open(path)
    try
        values,header = readdlm(stream,',';header=true)
        return Float64.(values),String.(vec(header))
    finally
        close(stream)
    end
end
function read_particles(path)
    values,header=numeric_csv(path)
    columns=Dict(name=>i for (i,name) in enumerate(header))
    positions=permutedims(values[:,[columns["x"],columns["y"],columns["z"]]])
    positions,values[:,columns["radius"]]
end
function find_csv(directory,stem)
    for suffix in (".csv",".csv.gz")
        path=joinpath(directory,stem*suffix)
        isfile(path) && return path
    end
    error("Missing numeric export: $directory/$stem.csv[.gz]")
end
function read_mesh(directory,stem)
    vertices,_=numeric_csv(find_csv(directory,stem*".vertices"))
    triangles,_=numeric_csv(find_csv(directory,stem*".triangles"))
    (vertices=permutedims(vertices),connectivity=Int.(permutedims(triangles)))
end
function boundary_reference(directory,descriptor)
    if descriptor["boundary_kind"]=="box"
        side=descriptor["side_length"]
        return p->box_clearance(p,(side,side,side))
    end
    inclusions=[mesh_reference(read_mesh(directory,s)) for s in descriptor["inclusions"]]
    exclusions=[mesh_reference(read_mesh(directory,s)) for s in descriptor["exclusions"]]
    isempty(inclusions) && error("No inclusion meshes in $directory")
    p->min(maximum(f(p) for f in inclusions),
           isempty(exclusions) ? Inf : minimum(-f(p) for f in exclusions))
end
function check_assembly(positions,radii,clearance;requested_count,tolerance)
    @assert size(positions)==(3,length(radii)) "Position/radius shape mismatch"
    @assert all(isfinite,positions) && all(isfinite,radii) && all(>(0),radii) "Nonfinite or invalid particle data"
    pair=pair_penetrations(positions,radii)
    wall=[clearance(p) for p in eachcol(positions)]
    max_pair=maximum(pair)
    max_wall=maximum(max.(0,radii-wall))
    passed=length(radii)==requested_count && minimum(wall)>=0 && max_pair<=tolerance && max_wall<=tolerance
    Dict{String,Any}("geometric_validation_passed"=>passed,"final_count"=>length(radii),
         "max_pair_penetration"=>max_pair,"max_wall_penetration"=>max_wall,
         "centres_outside"=>count(<(0),wall),"absolute_tolerance"=>tolerance)
end
function validate_saved_case(input,output)
    files=sort([joinpath(root,f) for (root,_,names) in walkdir(input)
                for f in names if f=="validation_input.toml"])
    isempty(files) && error("No saved assembly descriptors in $input. Supply generated output or download the reference assembly archive.")
    mkpath(output)
    reports=Dict{String,Any}[]
    for file in files
        descriptor=TOML.parsefile(file);directory=dirname(file)
        positions,radii=read_particles(find_csv(directory,"particles"))
        clearance=boundary_reference(directory,descriptor)
        report=check_assembly(positions,radii,clearance;
            requested_count=descriptor["requested_count"],
            tolerance=descriptor["relative_tolerance"]*descriptor["minimum_radius"])
        report["condition"]=relpath(directory,input)
        report["reported_converged"]=get(descriptor,"reported_converged",false)
        report["validated_converged_assembly"]=report["geometric_validation_passed"] && report["reported_converged"]
        push!(reports,report)
        println(report["condition"],": geometric=",report["geometric_validation_passed"],
                ", reported convergence=",report["reported_converged"])
    end
    open(joinpath(output,"validation.toml"),"w") do io
        TOML.print(io,Dict("assemblies"=>reports);sorted=true)
    end
    # Failed reference attempts are retained as evidence, not promoted to valid assemblies.
    for r in reports
        r["reported_converged"] && @assert r["geometric_validation_passed"] "A reportedly converged assembly failed independent validation"
    end
    reports
end
