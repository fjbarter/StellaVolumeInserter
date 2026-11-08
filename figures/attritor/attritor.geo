NewModel;
SetFactory("OpenCASCADE");

mesh_size = 0.0005;

Mesh.MeshSizeMin = mesh_size;
Mesh.MeshSizeMax = mesh_size;
Mesh.MeshSizeFromPoints = 0;
Mesh.MeshSizeFromCurvature = 0;
Mesh.MeshSizeExtendFromBoundary = 0;

barrel_length = 0.08;
barrel_radius = 0.003;
origin_x = 0.0;
origin_y = 0.0;
origin_z = 0.0;

spokes_per_layer = 5;
number_of_layers = 8;
z_min = 0.005;
z_max = 0.05;
thickness = 0.0015;
angular_offset = Pi / 10.0;

// Barrel
barrel = 1;
Cylinder(barrel) = {origin_x, origin_y, origin_z, 0.0, 0.0, barrel_length, barrel_radius};

// Flush overlap offset
t = thickness;
r0 = Sqrt(barrel_radius * barrel_radius - t * t);

// Spokes
spokes[] = {};

For i In {0:number_of_layers-1}
  If (number_of_layers == 1)
    z_pos = 0.5 * (z_min + z_max);
  Else
    z_pos = z_min + i * (z_max - z_min) / (number_of_layers - 1);
  EndIf

  radial_length = -0.2 * z_pos + 0.028;

  For j In {0:spokes_per_layer-1}
    theta = 2.0 * Pi * j / spokes_per_layer + i * angular_offset;

    x0 = origin_x + r0 * Cos(theta);
    y0 = origin_y + r0 * Sin(theta);
    z0 = origin_z + z_pos;

    extension = radial_length - r0;
    dx = extension * Cos(theta);
    dy = extension * Sin(theta);

    s = newv;
    Cylinder(s) = {x0, y0, z0, dx, dy, 0.0, t};
    spokes[] += {s};
  EndFor
EndFor

// Fuse into one watertight volume
If (#spokes[] > 0)
  BooleanUnion(1000) = { Volume{barrel}; Delete; }{ Volume{spokes[]}; Delete; };
EndIf
