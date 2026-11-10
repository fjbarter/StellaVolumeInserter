#!/usr/bin/env python3
"""Check repository layout, source conventions and reference-data integrity without Stella."""
import csv, re, sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    raise SystemExit("This layout check requires Python 3.11+ (plotters need only Matplotlib).")
ROOT = Path(__file__).resolve().parents[1]
cases = sorted((ROOT / "cases").iterdir())
assert len(cases) == 11
for case in cases:
    for name in [
        "Project.toml",
        "Manifest.toml",
        "run.jl",
        "validate.jl",
        "analyse.jl",
        "README.md",
    ]:
        assert (case / name).is_file(), f"{case.name}/{name}"
    text = (case / "Project.toml").read_text()
    project = tomllib.loads(text)
    assert project["sources"]["Stella"]["path"] == "../../Stella", case.name
    assert (
        text.count("BEGIN TEMPORARY STELLA SOURCE")
        == text.count("END TEMPORARY STELLA SOURCE")
        == 1
    ), case.name
    assert '# Stella = {url = "https://github.com/stellaorg/stella.jl"' in text
    if "Packing3D" in project.get("deps", {}):
        assert project["sources"]["Packing3D"] == {
            "url": "https://github.com/fjbarter/Packing3D.jl",
            "rev": "d437dff33a3019bb28eda2796feae533a02123b7",
        }
    manifest = tomllib.loads((case / "Manifest.toml").read_text())
    assert manifest["deps"]["Stella"][0]["path"] == "../../Stella"
for env in ["validation", "analysis"]:
    p = tomllib.loads((ROOT / f"common/{env}/Project.toml").read_text())
    assert "Stella" not in p["deps"]
assert "/Stella/" in (ROOT / ".gitignore").read_text()
for folder in [
    "cases",
    "common",
    "docs",
    "scripts",
    "figures",
    "data/raw/reference",
    "data/processed/reference",
]:
    for p in (ROOT / folder).rglob("*"):
        if p.suffix not in (".jl", ".py", ".toml", ".md", ".csv", ".json", ".txt"):
            continue
        assert (
            "/" + "Users" + "/"
        ) not in p.read_text(), f"Workstation path in {p.relative_to(ROOT)}"
rows = list(
    csv.DictReader((ROOT / "data/raw/reference/10_cpu_scaling/problem_size_scaling.csv").open())
)
assert len(rows) == 65
for n in {int(r["requested_count"]) for r in rows}:
    group = [r for r in rows if int(r["requested_count"]) == n]
    assert sorted(int(r["seed"]) for r in group) == [1, 2, 3, 4, 5]
    assert all(
        r["status"] == "passed"
        and r["reported_converged"].lower() == "true"
        and int(r["final_count"]) == n
        and float(r["compile_seconds"]) == float(r["recompile_seconds"]) == 0
        for r in group
    )
assert (
    len(
        list(
            csv.DictReader(
                (ROOT / "data/raw/reference/08_mesh_refinement/mesh_refinement.csv").open()
            )
        )
    )
    == 50
)
assert (
    len(
        list(
            csv.DictReader((ROOT / "data/raw/reference/04_density_sweep/density_sweep.csv").open())
        )
    )
    == 34
)
# The five-repeat sweep is preserved separately from the original single-seed table.
repeats = list(csv.DictReader(
    (ROOT / "data/raw/reference/04_density_sweep/density_sweep_repeats.csv").open()
))
assert len(repeats) == 175
conditions = {(r["psd"], float(r["target_packing_fraction"])) for r in repeats}
assert sum(name == "monodisperse" for name, _ in conditions) == 17
assert sum(name == "polydisperse" for name, _ in conditions) == 18
for name, target in conditions:
    group = [r for r in repeats if r["psd"] == name and float(r["target_packing_fraction"]) == target]
    assert sorted(int(r["seed"]) for r in group) == [1, 2, 3, 4, 5]

print(
    "Verified 11 complete cases, isolated validation/analysis projects, portable source blocks and reference table counts"
)
