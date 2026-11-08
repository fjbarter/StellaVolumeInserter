#!/usr/bin/env python3
"""Centre-assigned segregation intensity and its sampling-cell calibration."""
import argparse
from pathlib import Path
import csv
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "figures"))
from plotting import plt, TEAL, RED, apply_style, style_axes, boxed_legend, save_figure

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--csv",type=Path,default=HERE.parent.parent/"data/raw/reference/06_spatial_segregation/segregation_summary.csv")
parser.add_argument("--output-dir",type=Path,default=HERE.parent.parent/"figures/generated/06_spatial_segregation")
args=parser.parse_args()
rows = list(csv.DictReader(args.csv.open()))
selected = next(r for r in rows if r["selected"].lower() == "true")
apply_style()
fig, axes = plt.subplots(1, 2, figsize=(8.2, 3.5), layout="constrained")
for ax, subset, title in [(axes[0], rows, "(a) Cell-size calibration"),
                           (axes[1], [r for r in rows if 2 <= int(r["divisions"]) <= 8],
                            "(b) Coarser sampling grids")]:
    x = [int(r["divisions"]) for r in subset]
    ax.plot(x, [float(r["packing3d_intensity"]) for r in subset], "o-",
            color=TEAL, label="Inserted assembly")
    ax.errorbar(x, [float(r["reference_mean"]) for r in subset],
                yerr=[float(r["reference_sd"]) for r in subset], fmt="s--",
                capsize=3, color=RED, label="Random assignment: mean ± SD")
    if ax is axes[0]:
        ax.plot(x, [float(r["perfect_segregation_intensity"]) for r in subset], ":",
                color="0.4", label="Perfect segregation control")
        ax.set_ylim(0, 1.05)
    else:
        ax.set_ylim(0, 0.14)
    ax.axvline(int(selected["divisions"]), color="0.65", linewidth=0.9, linestyle="-.",
               label="Selected grid")
    ax.set_title(title, loc="left")
    ax.set_xlabel("Sampling cells per axis")
    ax.set_ylabel("Segregation intensity")
    ax.set_xticks(x)
    style_axes(ax)
    boxed_legend(ax, loc="upper left", fontsize=7.3)
save_figure(fig, args.output_dir, "spatial_size_bias", ["png", "pdf"])
