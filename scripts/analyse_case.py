#!/usr/bin/env python3
"""Summarise archived experiment tables; no Stella or third-party Python modules required."""
import argparse, csv, json, statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("case")
parser.add_argument("input", type=Path)
parser.add_argument("--validate-probes", action="store_true")
args = parser.parse_args()

output = ROOT / "data/processed/generated" / args.case
output.mkdir(parents=True, exist_ok=True)
files = sorted(args.input.glob("*.csv"))
if not files:
    raise SystemExit(f"No CSV tables in {args.input}")
report = {}
for table_file in files:
    rows = list(csv.DictReader(table_file.open()))
    report[table_file.name] = {"rows": len(rows)}
    if rows and "status" in rows[0]:
        report[table_file.name]["statuses"] = {
            status: sum(row["status"] == status for row in rows)
            for status in sorted({row["status"] for row in rows})
        }
        # Inventory and convergence must both be checked, not just the independent status.
        report[table_file.name]["validated_converged"] = sum(
            row["status"] == "passed" and row.get("reported_converged", "").lower() == "true"
            for row in rows
        )
    if args.case == "11_stanford_dragon" and table_file.name == "historical_timings.csv":
        baseline = next(float(row["seconds"]) for row in rows if row["configuration"] == "cpu_1")
        comparisons = [
            dict(row, cpu_baseline_speedup=baseline / float(row["seconds"])) for row in rows
        ]
        with (output / "historical_speedups.csv").open("w", newline="") as io:
            writer = csv.DictWriter(io, fieldnames=comparisons[0])
            writer.writeheader()
            writer.writerows(comparisons)
    if args.case == "09_wall_probes" and table_file.name == "summary.csv":
        assert len(rows) == 360
        assert max(float(row["final_residual"]) for row in rows) <= 1e-12
        report[table_file.name]["max_final_residual"] = max(
            float(row["final_residual"]) for row in rows
        )
        report[table_file.name]["max_one_step_difference"] = max(
            float(row["change_from_coarse"]) for row in rows
        )
    if args.case == "10_cpu_scaling" and table_file.name == "problem_size_scaling.csv":
        counts = sorted({int(row["requested_count"]) for row in rows})
        assert len(counts) == 13
        summary = []
        for particle_count in counts:
            group = [row for row in rows if int(row["requested_count"]) == particle_count]
            assert sorted(int(row["seed"]) for row in group) == [1, 2, 3, 4, 5]
            assert all(
                row["status"] == "passed"
                and row["reported_converged"].lower() == "true"
                and int(row["final_count"]) == particle_count
                for row in group
            )
            assert all(
                float(row["compile_seconds"]) == float(row["recompile_seconds"]) == 0
                for row in group
            )
            record = {"requested_count": particle_count, "repeats": 5}
            for key in ["insertion_seconds", "iterations", "seconds_per_particle"]:
                values = [float(row[key]) for row in group]
                record[key] = statistics.mean(values)
                record[key + "_sd"] = statistics.stdev(values)
            summary.append(record)
        with (output / "problem_size_scaling_summary.csv").open("w", newline="") as io:
            writer = csv.DictWriter(io, fieldnames=summary[0])
            writer.writeheader()
            writer.writerows(summary)
(output / "table_audit.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
