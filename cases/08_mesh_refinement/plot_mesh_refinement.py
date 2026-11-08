#!/usr/bin/env python3
"""Plot the completed mesh-refinement cases using Matplotlib.

Run from any directory:
    python3 plot_mesh_refinement.py

Defaults read results/mesh_refinement.csv beside this script and write figures to
results/plots/. PNGs are for preview; PDFs are vector artwork for the paper.
Requires matplotlib; all CSV handling uses the Python standard library.
"""

import argparse
import csv
import math
import statistics
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator


HERE = Path(__file__).resolve().parent
COLOURS = {"cube": "#287D8E", "cylinder": "#B85C65"}
MARKERS = {"cube": "o", "cylinder": "s"}


def read_results(path, expected_seeds):
    """Aggregate matched repeats; failures remain in the denominator and plot annotations."""
    with path.open(newline="") as source:
        reader = csv.DictReader(source)
        required = {"geometry", "triangles", "iterations", "status", "seed",
                    "reported_converged", "relative_volume_error"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError("CSV is missing columns: " + ", ".join(sorted(missing)))
        rows = list(reader)

    levels = {}
    for line, row in enumerate(rows, start=2):
        geometry = row["geometry"]
        triangles = int(row["triangles"])
        if geometry not in COLOURS or triangles <= 0:
            raise ValueError("Invalid geometry or triangle count on CSV line {}".format(line))
        levels.setdefault((geometry, triangles), []).append(row)

    groups = {"cube": [], "cylinder": []}
    for (geometry, triangles), repeats in sorted(levels.items()):
        seeds = [int(row["seed"]) for row in repeats]
        if len(seeds) != len(set(seeds)):
            raise ValueError("Duplicate seeds for {} / {} triangles".format(geometry, triangles))
        if set(seeds) != set(expected_seeds):
            raise ValueError(
                "{} / {} triangles has seeds {}; expected {}. Finish the study first.".format(
                    geometry, triangles, sorted(seeds), expected_seeds
                )
            )
        successful = [row for row in repeats if row["status"] == "passed"
                      and row["reported_converged"].lower() == "true"]
        values = [int(row["iterations"]) for row in successful]
        if any(value <= 0 for value in values):
            raise ValueError("Missing or invalid iteration count in a successful run")
        record = {
            "triangles": triangles,
            "iterations": values,
            "mean_iterations": statistics.mean(values) if values else math.nan,
            "sd_iterations": statistics.stdev(values) if len(values) > 1 else math.nan,
            "attempted": len(repeats),
            "successful": len(values),
            "failed": len(repeats) - len(values),
            "successful_seeds": [int(row["seed"]) for row in successful],
            "failed_seeds": [int(row["seed"]) for row in repeats if row not in successful],
        }
        if geometry == "cylinder":
            errors = [float(row["relative_volume_error"]) for row in repeats]
            if any(not math.isfinite(error) or error <= 0 for error in errors):
                raise ValueError("Cylinder volume error must be positive for the log plot")
            if not all(math.isclose(error, errors[0], rel_tol=1e-12) for error in errors):
                raise ValueError("Volume errors differ between seeds: check mesh reuse")
            # The same mesh is reused across seeds; this deterministic error is not averaged.
            record["volume_error_percent"] = 100 * errors[0]
        groups[geometry].append(record)

    for geometry, records in groups.items():
        if not records:
            raise ValueError("No {} results found".format(geometry))
        records.sort(key=lambda row: row["triangles"])
    return groups


def write_summary(path, groups):
    columns = ["geometry", "triangles", "attempted", "successful", "failed",
               "mean_iterations", "sd_iterations", "successful_seeds", "failed_seeds",
               "volume_error_percent"]
    with path.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=columns)
        writer.writeheader()
        for geometry, records in groups.items():
            for record in records:
                row = {key: record.get(key, "") for key in columns}
                row["geometry"] = geometry
                for key in ("successful_seeds", "failed_seeds"):
                    row[key] = ";".join(map(str, row[key]))
                writer.writerow(row)
    print(path)


def plot_iterations(ax, groups):
    failure_label_added = False
    all_values = []
    for geometry, records in groups.items():
        for record in records:
            values = record["iterations"]
            all_values.extend(values)
            if record["failed"]:
                label = "Failed runs (counts shown)" if not failure_label_added else None
                ax.scatter(record["triangles"], 0, marker="x", color="#B2182B",
                           label=label, clip_on=False, zorder=4)
                ax.annotate("{}/{} failed".format(record["failed"], record["attempted"]),
                            (record["triangles"], 0), xytext=(0, 8),
                            textcoords="offset points", ha="center", color="#B2182B", fontsize=8)
                failure_label_added = True
        ax.errorbar(
            [row["triangles"] for row in records],
            [row["mean_iterations"] for row in records],
            yerr=[row["sd_iterations"] for row in records],
            label=geometry.capitalize() + " (mean ± SD)",
            color=COLOURS[geometry], marker=MARKERS[geometry], capsize=3, zorder=3,
        )
        all_values.extend(row["mean_iterations"] + row["sd_iterations"]
                          for row in records if math.isfinite(row["sd_iterations"]))
    if not all_values:
        raise ValueError("No successful runs to plot; inspect the failure summary")
    ax.set_xscale("log")
    ax.set_xlabel("Number of surface triangles")
    ax.set_ylabel("Relaxation iterations")
    ax.set_ylim(0, math.ceil(max(all_values) * 1.12 / 10) * 10)
    ax.yaxis.set_major_locator(MaxNLocator(integer=True, nbins=5))
    ax.legend(
        frameon=True, fancybox=False, framealpha=1.0,
        facecolor="white", edgecolor="0.3", loc="lower left", fontsize=9,
    )
    style_axes(ax)


def plot_volume_error(ax, groups):
    records = groups["cylinder"]
    ax.plot(
        [row["triangles"] for row in records],
        [row["volume_error_percent"] for row in records],
        color=COLOURS["cylinder"],
        marker=MARKERS["cylinder"],
    )
    ax.set_xscale("log")
    ax.set_yscale("log")
    errors = [row["volume_error_percent"] for row in records]
    lower = 10 ** math.floor(math.log10(min(errors)))
    upper = 10 ** math.ceil(math.log10(max(errors)))
    ax.set_ylim(lower, upper if upper > lower else 10 * lower)
    ax.set_xlabel("Number of surface triangles")
    ax.set_ylabel("Relative cylinder-volume error (%)")
    style_axes(ax)


def style_axes(ax):
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(which="major", color="0.88", linewidth=0.6)
    ax.set_axisbelow(True)
    ax.tick_params(which="both", direction="out")


def save_figure(fig, output, name, formats):
    for extension in formats:
        path = output / (name + "." + extension)
        fig.savefig(path, dpi=300, bbox_inches="tight", facecolor="white")
        print(path)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=HERE.parent.parent / "data/raw/reference/08_mesh_refinement/mesh_refinement.csv")
    parser.add_argument("--output-dir", type=Path, default=HERE.parent.parent / "figures/generated/08_mesh_refinement")
    parser.add_argument("--formats", nargs="+", choices=("png", "pdf", "svg"), default=["png", "pdf"])
    parser.add_argument("--expected-seeds", nargs="+", type=int, default=[1, 2, 3, 4, 5])
    args = parser.parse_args()
    groups = read_results(args.csv, args.expected_seeds)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_summary(args.output_dir / "mesh_refinement_summary.csv", groups)

    plt.rcParams.update({
        "font.family": "sans-serif",
        "font.sans-serif": ["Arial"],
        "mathtext.fontset": "custom",
        "mathtext.rm": "Arial",
        "mathtext.it": "Arial:italic",
        "mathtext.bf": "Arial:bold",
        "font.size": 10,
        "axes.labelsize": 10,
        "legend.fontsize": 10,
        "lines.linewidth": 1.3,
        "lines.markersize": 4.5,
        "axes.linewidth": 0.7,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "svg.fonttype": "none",
    })

    # Combined lower row for the proposed four-panel figure, with mesh renders above.
    fig, axes = plt.subplots(1, 2, figsize=(7.0, 2.8), layout="constrained")
    plot_iterations(axes[0], groups)
    plot_volume_error(axes[1], groups)
    for label, ax in zip(("(c)", "(d)"), axes):
        ax.set_title(label, loc="left", fontweight="bold")
    save_figure(fig, args.output_dir, "mesh_refinement_plots", args.formats)

    # Individual vector panels are convenient when arranging the complete figure.
    for name, draw in (("refinement_iterations", plot_iterations),
                       ("refinement_volume_error", plot_volume_error)):
        fig, ax = plt.subplots(figsize=(3.4, 2.8), layout="constrained")
        draw(ax, groups)
        save_figure(fig, args.output_dir, name, args.formats)


if __name__ == "__main__":
    main()
