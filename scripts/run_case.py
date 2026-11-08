#!/usr/bin/env python3
"""Run one documented case; long benchmarks require an explicit opt-in."""
import argparse, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("case", help="Number 01–11 or full directory name")
parser.add_argument("action", choices=["run", "validate", "analyse"])
parser.add_argument("--input", type=Path)
parser.add_argument("--threads", type=int, default=1)
parser.add_argument("--backend", choices=["cpu", "metal"], default="cpu")
parser.add_argument("--allow-expensive", action="store_true")
args = parser.parse_args()

matches = [
    candidate
    for candidate in (ROOT / "cases").iterdir()
    if candidate.name == args.case or candidate.name.split("_")[0] == args.case.zfill(2)
]
if len(matches) != 1:
    parser.error("Choose a unique case 01–11")
case = matches[0]

if args.action == "run" and case.name[:2] in ("05", "10", "11") and not args.allow_expensive:
    parser.error("This is a potentially long CPU/GPU experiment; use --allow-expensive")
if args.action == "run":
    if not (ROOT / "Stella/Project.toml").exists():
        parser.error("Clone the authorised Stella repository into Stella/ first; see README.md")
    environment = case
else:
    environment = ROOT / "common" / ("validation" if args.action == "validate" else "analysis")

# Launch the selected case in its own Julia project.
command = [
    "julia",
    f"--project={environment}",
    f"--threads={args.threads}",
    str(case / (args.action + ".jl")),
]
if args.input:
    command.append(str(args.input.resolve()))
if args.action == "run" and case.name.startswith("11"):
    command.append(args.backend)
print(" ".join(command), flush=True)
subprocess.run(command, cwd=ROOT, check=True)
