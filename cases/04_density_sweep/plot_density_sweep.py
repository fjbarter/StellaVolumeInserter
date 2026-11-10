#!/usr/bin/env python3
"""Plot mean and sample SD for converged, validated density-sweep repeats."""

import argparse
import csv
import math
from pathlib import Path
import statistics
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "figures"))
from plotting import (plt, TEAL, RED, apply_style, read_csv, number, validated,
                      style_axes, boxed_legend, save_figure)
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator

COLOURS = {"monodisperse": TEAL, "polydisperse": RED}
LABELS = {"monodisperse": "Monodisperse", "polydisperse": "Polydisperse"}
METRICS = ("bulk_packing_fraction", "insertion_seconds", "iterations")
SEEDS = [1, 2, 3, 4, 5]
POLYDISPERSE_TARGETS = {0.30, 0.35, 0.40, 0.45, 0.50, 0.525,
                       0.55, 0.56, 0.57, 0.58}


def read_results(path):
    rows = read_csv(path, ["psd", "target_packing_fraction", "seed", "insertion_seconds",
                           "iterations", "status", "reported_converged", "termination_reason",
                           "bulk_packing_fraction", "julia_threads", "blas_threads"])
    groups = {name: {} for name in COLOURS}
    for row in rows:
        name = row["psd"]
        if name not in groups:
            raise ValueError("Unknown particle-size distribution: " + name)
        if number(row, "insertion_seconds") <= 0:
            raise ValueError("Invalid attempt time")
        target = number(row, "target_packing_fraction")
        groups[name].setdefault(target, []).append(row)

    if not groups["monodisperse"]:
        raise ValueError("No monodisperse results found")
    missing = POLYDISPERSE_TARGETS.difference(groups["polydisperse"])
    if missing:
        raise ValueError(f"Missing polydisperse target fractions: {sorted(missing)}")
    # Keep all monodisperse points; thin only the polydisperse curve.
    groups["polydisperse"] = {
        target: repeats for target, repeats in groups["polydisperse"].items()
        if target in POLYDISPERSE_TARGETS
    }

    summary = {name: [] for name in COLOURS}
    for name, targets in groups.items():
        for target, repeats in sorted(targets.items()):
            if sorted(int(row["seed"]) for row in repeats) != SEEDS:
                raise ValueError(f"{name}, target {target}: expected exactly seeds 1–5")
            successful = [row for row in repeats if validated(row)]
            record = {"psd": name, "target_packing_fraction": target,
                      "attempts": len(repeats), "validated_converged": len(successful)}
            for metric in METRICS:
                values = [number(row, metric) for row in successful]
                if metric in ("insertion_seconds", "iterations") and any(v <= 0 for v in values):
                    raise ValueError(f"Invalid {metric} for a validated run")
                record[metric + "_mean"] = statistics.mean(values) if values else None
                record[metric + "_sd"] = statistics.stdev(values) if len(values) >= 2 else None
            summary[name].append(record)
    return summary


def plotted_rows(records):
    # An SD is undefined for fewer than two successful repeats.
    return [row for row in records if row["validated_converged"] >= 2]


def plot_mean_and_sd(ax, records, metric, *, colour, fmt, label=None):
    # Leave gaps where fewer than two runs succeeded, rather than joining across them.
    x = [row["target_packing_fraction"] for row in records]
    mean = [row[metric + "_mean"] if row["validated_converged"] >= 2 else math.nan
            for row in records]
    sd = [row[metric + "_sd"] if row["validated_converged"] >= 2 else math.nan
          for row in records]
    ax.errorbar(x, mean, yerr=sd, fmt=fmt, capsize=3, color=colour,
                linewidth=1.3, label=label)


def sample_count_note(groups):
    lines = ["Mean ± SD (n = 5 except):"]
    for name, records in groups.items():
        partial = [row for row in plotted_rows(records)
                   if row["validated_converged"] < len(SEEDS)]
        values = [f'{row["target_packing_fraction"]:.3f} ({row["validated_converged"]})'
                  for row in partial]
        for index in range(0, len(values), 2):
            prefix = LABELS[name] + ": " if index == 0 else "    "
            lines.append(prefix + ", ".join(values[index:index + 2]))
    return "\n".join(lines)


def plot_bulk_density(ax, groups):
    for name, records in groups.items():
        plot_mean_and_sd(ax, records, "bulk_packing_fraction", colour=COLOURS[name],
                         fmt="o-", label=LABELS[name])
    ax.plot([0, 0.75], [0, 0.75], "--", color="0.45", linewidth=1,
            label=r"$\phi_{\mathrm{bulk}}=\phi_{\mathrm{req}}$", zorder=1)
    ax.set_ylabel("Measured bulk packing fraction\n(interior region; wall layer excluded)")
    ax.text(0.04, 0.96, sample_count_note(groups), transform=ax.transAxes,
            va="top", fontsize=7.5)
    finish(ax, groups)
    ax.set_xlim(0, 0.75)
    ax.set_ylim(0, 0.75)
    ax.set_aspect("equal", adjustable="box")
    boxed_legend(ax, loc="lower right", fontsize=8)


def plot_performance(ax, groups):
    iteration_axis = ax.twinx()
    for name, records in groups.items():
        plot_mean_and_sd(ax, records, "insertion_seconds", colour=COLOURS[name], fmt="o-")
        plot_mean_and_sd(iteration_axis, records, "iterations", colour=COLOURS[name], fmt="o--")
    ax.set_ylabel("Insertion time (s)")
    iteration_axis.set_ylabel("Relaxation iterations")
    ax.set_ylim(bottom=0)
    iteration_axis.set_ylim(bottom=0)
    iteration_axis.yaxis.set_major_locator(MaxNLocator(integer=True, nbins=5))
    finish(ax, groups)
    iteration_axis.spines["top"].set_visible(False)
    iteration_axis.tick_params(direction="out")
    iteration_axis.grid(False)
    handles = [Line2D([], [], color=COLOURS[name], marker="o", label=LABELS[name])
               for name in COLOURS] + [
        Line2D([], [], color="0.25", label="Time (left axis)"),
        Line2D([], [], color="0.25", linestyle="--", label="Iterations (right axis)"),
    ]
    boxed_legend(ax, handles=handles, loc="upper left", fontsize=8.5)


def finish(ax, groups):
    fractions = [row["target_packing_fraction"] for rows in groups.values()
                 for row in plotted_rows(rows)]
    ax.set_xlim(min(fractions) - 0.015, math.ceil(max(fractions) * 20) / 20 + 0.005)
    ax.set_xlabel("Requested whole-domain packing fraction\n(full container volume)")
    style_axes(ax)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=HERE.parent.parent / "data/raw/reference/04_density_sweep/density_sweep_repeats.csv")
    parser.add_argument("--output-dir", type=Path, default=HERE.parent.parent / "figures/generated/04_density_sweep")
    parser.add_argument("--formats", nargs="+", choices=("png", "pdf", "svg"), default=["png", "pdf"])
    args = parser.parse_args()
    groups = read_results(args.csv)
    rows = [row for records in groups.values() for row in records]
    if not any(plotted_rows(records) for records in groups.values()):
        raise ValueError("No conditions have at least two converged, validated repeats")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    with (args.output_dir / "density_sweep_summary.csv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    apply_style()
    panels = [("bulk_density", plot_bulk_density), ("performance", plot_performance)]
    fig, axes = plt.subplots(1, 2, figsize=(8.2, 3.6), layout="constrained")
    for label, ax, (_, draw) in zip(("(a)", "(b)"), axes, panels):
        draw(ax, groups)
        ax.set_title(label, loc="left", fontweight="bold")
    save_figure(fig, args.output_dir, "density_sweep", args.formats)
    for name, draw in panels:
        fig, ax = plt.subplots(figsize=(4.2, 3.6), layout="constrained")
        draw(ax, groups)
        save_figure(fig, args.output_dir, "density_sweep_" + name, args.formats)


if __name__ == "__main__":
    main()
