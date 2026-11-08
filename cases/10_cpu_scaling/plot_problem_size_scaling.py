#!/usr/bin/env python3
"""Plot single-threaded problem-size scaling; read results relative to this script."""
import argparse
import csv
import statistics
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "figures"))
from plotting import (
    plt,
    TEAL,
    RED,
    apply_style,
    read_csv,
    number,
    validated,
    style_axes,
    boxed_legend,
    save_figure,
)
from matplotlib.ticker import MaxNLocator


def read_results(path):
    rows = read_csv(
        path,
        [
            "requested_count",
            "final_count",
            "insertion_seconds",
            "iterations",
            "status",
            "reported_converged",
            "julia_threads",
            "blas_threads",
            "compile_seconds",
            "recompile_seconds",
            "seconds_per_particle",
            "seed",
        ],
    )
    rows.sort(key=lambda row: int(row["requested_count"]))
    for row in rows:
        if number(row, "compile_seconds") != 0 or number(row, "recompile_seconds") != 0:
            raise ValueError("Size-scaling timing includes compilation")
        if not validated(row) or int(row["final_count"]) != int(row["requested_count"]):
            raise ValueError("Size-scaling condition did not converge and retain its inventory")
        if number(row, "insertion_seconds") <= 0 or int(row["iterations"]) <= 0:
            raise ValueError("Invalid time or iteration count")
    groups = {}
    for row in rows:
        groups.setdefault(int(row["requested_count"]), []).append(row)
    summary = []
    for count, repeats in sorted(groups.items()):
        seeds = [int(row["seed"]) for row in repeats]
        if sorted(seeds) != [1, 2, 3, 4, 5]:
            raise ValueError(f"N={count}: expected exactly five repeats with seeds 1–5")
        record = {"requested_count": count, "repeats": len(repeats)}
        for key in ("insertion_seconds", "iterations", "seconds_per_particle"):
            values = [number(row, key) for row in repeats]
            record[key] = statistics.mean(values)
            record[key + "_sd"] = statistics.stdev(values)
        summary.append(record)
    if len(summary) != 13:
        raise ValueError("Expected all 13 particle counts; finish the sweep first")
    return summary


def plot_runtime(ax, rows):
    counts = [int(row["requested_count"]) for row in rows]
    times = [number(row, "insertion_seconds") for row in rows]
    ax.errorbar(
        counts,
        times,
        yerr=[row["insertion_seconds_sd"] for row in rows],
        fmt="o-",
        capsize=3,
        color=TEAL,
        label="Mean ± SD (n=5)",
    )
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.loglog(
        counts,
        [times[0] * n / counts[0] for n in counts],
        "--",
        color="0.45",
        linewidth=1,
        label="Linear reference",
    )
    ax.set_ylabel("Insertion time (s)")
    boxed_legend(ax, loc="upper left", fontsize=8)
    finish(ax)


def plot_time_per_particle(ax, rows):
    counts = [int(row["requested_count"]) for row in rows]
    costs = [1e6 * number(row, "insertion_seconds") / n for row, n in zip(rows, counts)]
    ax.errorbar(
        counts,
        costs,
        yerr=[1e6 * row["seconds_per_particle_sd"] for row in rows],
        fmt="o-",
        capsize=3,
        color=TEAL,
        label="Mean ± SD (n=5)",
    )
    ax.set_xscale("log")
    boxed_legend(ax, fontsize=8)
    ax.set_ylabel("Insertion time per particle (µs)")
    ax.set_ylim(0, max(c + 1e6 * r["seconds_per_particle_sd"] for c, r in zip(costs, rows)) * 1.15)
    finish(ax)


def plot_iterations(ax, rows):
    ax.errorbar(
        [int(row["requested_count"]) for row in rows],
        [row["iterations"] for row in rows],
        yerr=[row["iterations_sd"] for row in rows],
        fmt="s-",
        capsize=3,
        color=RED,
        label="Mean ± SD (n=5)",
    )
    ax.set_xscale("log")
    boxed_legend(ax, fontsize=8)
    ax.set_ylabel("Relaxation iterations")
    ax.set_ylim(0, max(row["iterations"] + row["iterations_sd"] for row in rows) * 1.15)
    ax.yaxis.set_major_locator(MaxNLocator(integer=True, nbins=5))
    finish(ax)


def finish(ax):
    ax.set_xlabel("Number of particles")
    style_axes(ax)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--csv",
        type=Path,
        default=HERE.parent.parent / "data/raw/reference/10_cpu_scaling/problem_size_scaling.csv",
    )
    parser.add_argument(
        "--output-dir", type=Path, default=HERE.parent.parent / "figures/generated/10_cpu_scaling"
    )
    parser.add_argument(
        "--formats", nargs="+", choices=("png", "pdf", "svg"), default=["png", "pdf"]
    )
    args = parser.parse_args()
    rows = read_results(args.csv)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    with (args.output_dir / "problem_size_scaling_summary.csv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    apply_style()
    panels = [
        ("runtime", plot_runtime),
        ("time_per_particle", plot_time_per_particle),
        ("iterations", plot_iterations),
    ]
    fig, axes = plt.subplots(1, 3, figsize=(10.5, 2.9), layout="constrained")
    for label, ax, (_, draw) in zip(("(a)", "(b)", "(c)"), axes, panels):
        draw(ax, rows)
        ax.set_title(label, loc="left", fontweight="bold")
    save_figure(fig, args.output_dir, "problem_size_scaling", args.formats)
    for name, draw in panels:
        fig, ax = plt.subplots(figsize=(3.5, 2.9), layout="constrained")
        draw(ax, rows)
        save_figure(fig, args.output_dir, "size_scaling_" + name, args.formats)


if __name__ == "__main__":
    main()
