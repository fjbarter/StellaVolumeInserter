#!/usr/bin/env python3
"""Verify the intentionally separate reference assembly archive against its tracked inventory."""
from pathlib import Path
import csv, hashlib

ROOT = Path(__file__).resolve().parents[1]
rows = list(csv.DictReader((ROOT / "docs/assembly_inventory.csv").open()))
for row in rows:
    path = ROOT / row["path"]
    assert path.is_file(), f"Missing payload file {path.relative_to(ROOT)}; see docs/data.md"
    assert (
        path.stat().st_size == int(row["bytes"])
        and hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"]
    ), row["path"]
print(f"Verified {len(rows)} payload files")
