#!/usr/bin/env python3
from pathlib import Path
import hashlib, struct

mesh_path = Path(__file__).resolve().parents[1] / "meshes/dragon2.stl"
mesh_bytes = mesh_path.read_bytes()
assert (
    hashlib.sha256(mesh_bytes).hexdigest()
    == "fa680acba2c958c917fa6b2fe561c0ef56c969b4c05ed19872b49b6c7ec4e118"
)
assert struct.unpack_from("<I", mesh_bytes, 80)[0] == 100000 and len(mesh_bytes) == 84 + 50 * 100000
print("Original Dragon mesh checksum and triangle count verified")
