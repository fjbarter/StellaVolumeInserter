"""Shared publication style and CSV helpers for the paper's performance plots."""
import csv
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

TEAL = "#287D8E"
RED = "#B85C65"


def apply_style():
    plt.rcParams.update({
        "font.family": "sans-serif", "font.sans-serif": ["Arial"],
        "mathtext.fontset": "custom", "mathtext.rm": "Arial",
        "mathtext.it": "Arial:italic", "mathtext.bf": "Arial:bold",
        "font.size": 10, "axes.labelsize": 10, "legend.fontsize": 9,
        "lines.linewidth": 1.3, "lines.markersize": 4.5, "axes.linewidth": 0.7,
        "pdf.fonttype": 42, "ps.fonttype": 42, "svg.fonttype": "none",
    })


def read_csv(path, required):
    with Path(path).open(newline="") as source:
        reader = csv.DictReader(source)
        missing = set(required).difference(reader.fieldnames or [])
        if missing:
            raise ValueError("CSV is missing columns: " + ", ".join(sorted(missing)))
        rows = list(reader)
    if not rows:
        raise ValueError("No experiment results found")
    for row in rows:
        if (int(row["julia_threads"]) != 1 or int(row["blas_threads"]) != 1
                or int(row.get("cpu_tasks", "1")) != 1):
            raise ValueError("These plots require single-threaded Julia and BLAS results")
    return rows


def number(row, key):
    value = float(row[key])
    if not math.isfinite(value):
        raise ValueError("Non-finite {} in results".format(key))
    return value


def validated(row):
    return row["status"] == "passed" and row["reported_converged"].lower() == "true"


def style_axes(ax):
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(which="major", color="0.88", linewidth=0.6)
    ax.set_axisbelow(True)
    ax.tick_params(which="both", direction="out")


def boxed_legend(ax, **kwargs):
    return ax.legend(frameon=True, fancybox=False, framealpha=1,
                     facecolor="white", edgecolor="0.3", **kwargs)


def save_figure(fig, directory, name, formats):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    for extension in formats:
        path = directory / (name + "." + extension)
        fig.savefig(path, dpi=300, bbox_inches="tight", facecolor="white")
        print(path)
    plt.close(fig)
