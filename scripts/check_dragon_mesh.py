#!/usr/bin/env python3
from pathlib import Path
import hashlib,struct
p=Path(__file__).resolve().parents[1]/"meshes/dragon2.stl"
b=p.read_bytes()
assert hashlib.sha256(b).hexdigest()=="fa680acba2c958c917fa6b2fe561c0ef56c969b4c05ed19872b49b6c7ec4e118"
assert struct.unpack_from("<I",b,80)[0]==100000 and len(b)==84+50*100000
print("Original Dragon mesh checksum and triangle count verified")
