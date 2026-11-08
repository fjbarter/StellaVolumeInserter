function box_mesh(lengths=(1.0, 1.0, 1.0); origin=(0.0, 0.0, 0.0), size_max=0.25)
    G.with_gmsh(argv=["", "-v", "0"]) do
        G.Box(origin, lengths)
        G.mesh(size_max=size_max)
    end |> TriangleMesh
end


function cylinder_mesh(; radius=1.0, height=1.0, origin=(0.0, 0.0, 0.0), size_max=0.25)
    G.with_gmsh(argv=["", "-v", "0"]) do
        G.Cylinder(origin, (0.0, 0.0, height), radius)
        G.mesh(size_max=size_max)
    end |> TriangleMesh
end


