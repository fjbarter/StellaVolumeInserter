#!/usr/bin/env python3
"""Plot whole-domain requests against bulk density and cost for validated converged runs."""
import argparse
import math
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
from matplotlib.lines import Line2D
from matplotlib.ticker import MaxNLocator

COLOURS = {"monodisperse": TEAL, "polydisperse": RED}
LABELS = {"monodisperse": "Monodisperse", "polydisperse": "Polydisperse"}


def read_results(path):
    rows = read_csv(
        path,
        [
            "psd",
            "target_packing_fraction",
            "insertion_seconds",
            "iterations",
            "status",
            "reported_converged",
            "termination_reason",
            "bulk_packing_fraction",
            "julia_threads",
            "blas_threads",
        ],
    )
    groups = {name: [] for name in COLOURS}
    for row in rows:
        if row["psd"] not in groups:
            raise ValueError("Unknown particle-size distribution: " + row["psd"])
        if number(row, "insertion_seconds") <= 0:
            raise ValueError("Invalid attempt time")
        groups[row["psd"]].append(row)
    for name, records in groups.items():
        records.sort(key=lambda row: number(row, "target_packing_fraction"))
        targets = [number(row, "target_packing_fraction") for row in records]
        if not records or len(set(targets)) != len(targets):
            raise ValueError("Missing distribution or duplicate target fractions: " + name)
    if [r["target_packing_fraction"] for r in groups["monodisperse"]] != [
        r["target_packing_fraction"] for r in groups["polydisperse"]
    ]:
        raise ValueError("The two distributions must use the same target fractions")
    return groups


def plot_bulk_density(ax, groups):
    for name, records in groups.items():
        # Report bulk density only when both stopping and independent validation criteria pass.
        successful = [row for row in records if validated(row)]
        values = [number(row, "bulk_packing_fraction") for row in successful]
        ax.plot(
            [number(row, "target_packing_fraction") for row in successful],
            values,
            "o-",
            color=COLOURS[name],
            label=LABELS[name],
        )
    ax.plot(
        [0, 0.75],
        [0, 0.75],
        "--",
        color="0.45",
        linewidth=1,
        label=r"$\phi_{\mathrm{bulk}}=\phi_{\mathrm{req}}$",
        zorder=1,
    )
    ax.set_ylabel("Measured bulk packing fraction\n(interior region; wall layer excluded)")
    maxima = {
        name: max(number(row, "bulk_packing_fraction") for row in records if validated(row))
        for name, records in groups.items()
    }
    ax.text(
        0.04,
        0.96,
        "Highest validated bulk fractions\nMono: {:.3f}; Poly: {:.3f}".format(
            maxima["monodisperse"], maxima["polydisperse"]
        ),
        transform=ax.transAxes,
        va="top",
        fontsize=8.5,
    )
    finish(ax, groups)
    ax.set_xlim(0, 0.75)
    ax.set_ylim(0, 0.75)
    ax.set_aspect("equal", adjustable="box")
    boxed_legend(ax, loc="lower right", fontsize=8)


def plot_performance(ax, groups):
    # Plot only runs satisfying both convergence and independent geometric checks.
    # All unsuccessful attempts remain available in the raw CSV and logs.
    returned = {
        name: [row for row in records if validated(row)] for name, records in groups.items()
    }
    if not any(returned.values()):
        raise ValueError("No converged, independently validated assemblies to plot")
    iteration_axis = ax.twinx()
    for name, records in returned.items():
        x = [number(row, "target_packing_fraction") for row in records]
        times = [number(row, "insertion_seconds") for row in records]
        iterations = [int(row["iterations"]) for row in records]
        if any(value <= 0 for value in iterations):
            raise ValueError("Returned assembly lacks a valid iteration count")
        ax.plot(x, times, color=COLOURS[name], linewidth=1.3)
        iteration_axis.plot(x, iterations, "--", color=COLOURS[name], linewidth=1.3)
        for row, px, time, count in zip(records, x, times, iterations):
            for target_axis, value in ((ax, time), (iteration_axis, count)):
                target_axis.plot(
                    px,
                    value,
                    marker="o",
                    color=COLOURS[name],
                    linestyle="none",
                    markerfacecolor=COLOURS[name],
                )
    ax.set_ylabel("Insertion time (s)")
    iteration_axis.set_ylabel("Relaxation iterations")
    ax.set_ylim(bottom=0)
    iteration_axis.set_ylim(bottom=0)
    iteration_axis.yaxis.set_major_locator(MaxNLocator(integer=True, nbins=5))
    finish(ax, returned)
    iteration_axis.spines["top"].set_visible(False)
    iteration_axis.tick_params(direction="out")
    iteration_axis.grid(False)
    handles = [
        Line2D([], [], color=COLOURS[name], marker="o", label=LABELS[name]) for name in COLOURS
    ] + [
        Line2D([], [], color="0.25", label="Time (left axis)"),
        Line2D([], [], color="0.25", linestyle="--", label="Iterations (right axis)"),
    ]
    boxed_legend(ax, handles=handles, loc="upper left", fontsize=8.5)


def finish(ax, groups):
    fractions = [number(row, "target_packing_fraction") for rows in groups.values() for row in rows]
    ax.set_xlim(min(fractions) - 0.015, math.ceil(max(fractions) * 20) / 20 + 0.005)
    ax.set_xlabel("Requested whole-domain packing fraction\n(full container volume)")
    style_axes(ax)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--csv",
        type=Path,
        default=HERE.parent.parent / "data/raw/reference/04_density_sweep/density_sweep.csv",
    )
    parser.add_argument(
        "--output-dir", type=Path, default=HERE.parent.parent / "figures/generated/04_density_sweep"
    )
    parser.add_argument(
        "--formats", nargs="+", choices=("png", "pdf", "svg"), default=["png", "pdf"]
    )
    args = parser.parse_args()
    groups = read_results(args.csv)
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
