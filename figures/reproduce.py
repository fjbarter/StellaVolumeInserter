#!/usr/bin/env python3
"""Reproduce numerical figures from the tracked reference CSVs."""
import subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for path in sorted((ROOT / "cases").glob("*/plot_*.py")):
    if path.parent.name == "03_dense_cube":
        continue  # Same plotter is provided with the full sweep.
    subprocess.run([sys.executable, str(path)], check=True, cwd=ROOT)
