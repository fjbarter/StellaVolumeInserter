# Instrument the checked-out production implementation in memory. Do not maintain a second
# implementation of its rules, or change any Stella source files. CPU, one task only.
function install_wall_trace()
    path =
        joinpath(dirname(pathof(Stella)), "inserters", "volume_inserter", "dominance_hierarchy.jl")
    source = read(path, String)
    start = findfirst("function _wallrep_algorithm_step!(", source)
    source = source[first(start):end]
    source = replace(
        source,
        "function _wallrep_algorithm_step!(" => "function diagnostic_wall_step!(events, ",
    )
    update = "dz += remaining_required_displacement * nz[current_contact_idx]"
    source = replace(
        source,
        update =>
            update *
            "\n" *
            "push!(events, (particle=Int(p), contact=Int(current_contact_idx), " *
            "kind=Int(kind[current_contact_idx]), amount=remaining_required_displacement, " *
            "dx=-dx, dy=-dy, dz=-dz))",
    )
    source = replace(
        source,
        "max_overlap=max_raw_wall_overlap," =>
            "kind=kind, overlap=overlap_eff, nx=nx, ny=ny, nz=nz, " *
            "edge_v1=edge_v1, edge_v2=edge_v2, vertex_ids=vertex_ids, " *
            "max_overlap=max_raw_wall_overlap,",
    )
    Base.include_string(Stella, source, path * " (diagnostic instrumentation)")
end
