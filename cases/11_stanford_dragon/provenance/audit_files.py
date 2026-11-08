from pathlib import Path
import struct, hashlib, re, zlib, array, json, math

p = Path(__file__).resolve().parent.parent
b = (p / "dragon2.stl").read_bytes()
n = struct.unpack_from("<I", b, 80)[0]
assert len(b) == 84 + 50 * n
lo = [math.inf] * 3
hi = [-math.inf] * 3
v6 = 0
for i in range(n):
    t = struct.unpack_from("<12fH", b, 84 + 50 * i)
    a = t[3:6]
    c = t[6:9]
    d = t[9:12]
    for vertex in [a, c, d]:
        for k in range(3):
            lo[k] = min(lo[k], vertex[k])
            hi[k] = max(hi[k], vertex[k])
    v6 += (
        a[0] * (c[1] * d[2] - c[2] * d[1])
        + a[1] * (c[2] * d[0] - c[0] * d[2])
        + a[2] * (c[0] * d[1] - c[1] * d[0])
    )
mesh = {
    "file": "dragon2.stl",
    "sha256": hashlib.sha256(b).hexdigest(),
    "triangles": n,
    "bounds_min": lo,
    "bounds_max": hi,
    "signed_surface_volume": v6 / 6,
    "length_units": "STL header says MM; benchmark uses raw mesh-coordinate units",
}
f = p / "particles_vtk" / "particles_0.vtp"
data = f.read_bytes()
start = data.index(b"<AppendedData")
header = data[:start].decode()
offset = re.search(r'Name="radius"[^>]*offset="(\d+)"', header)[1]
base = data.index(b"_", start) + 1
pos = base + int(offset)
nb, bs, last = struct.unpack_from("<3Q", data, pos)
sizes = struct.unpack_from("<" + "Q" * nb, data, pos + 24)
pos += 24 + 8 * nb
raw = []
for size in sizes:
    raw.append(zlib.decompress(data[pos : pos + size]))
    pos += size
vals = array.array("f")
vals.frombytes(b"".join(raw))
from collections import Counter

counts = Counter(vals)
volume = sum(c * 4 * math.pi / 3 * r**3 for r, c in counts.items())
result = {
    "mesh": mesh,
    "saved_particle_file": {
        "file": str(f.relative_to(p)),
        "sha256": hashlib.sha256(data).hexdigest(),
        "count": len(vals),
        "radius_bins": [{"radius": r, "count": c} for r, c in sorted(counts.items())],
        "sphere_volume": volume,
        "fraction_using_signed_mesh_volume": volume / abs(v6 / 6),
        "timed_run_association": "not recorded; existing output predates reported 73-second comparison",
    },
}
(p / "metadata" / "file_audit.json").write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
