#!/usr/bin/env python3
import os
import sys
import re
import numpy as np
from PIL import Image
import pandas as pd
import matplotlib.pyplot as plt

# ---------------- CONFIG ----------------
DEFAULT_DIR = "."
CSV_NAME = "cam_results.csv"
PLOT_NAME = "mae_vs_target.png"
# ----------------------------------------


def load_png_div128_cropped(path: str) -> np.ndarray:
    """
    Load 8-bit PNG → float32 by dividing by 2^7.
    Convert RGB → grayscale if needed.
    Crop arr[15:415, 5:485].
    Convert zeros to NaN.
    """
    with Image.open(path) as im:
        arr = np.asarray(im)

    # Convert RGB(A) → grayscale
    if arr.ndim == 3:
        arr = arr[..., :3]             # drop alpha
        arr = arr.mean(axis=2)         # grayscale average

    # Crop rows [15,415), cols [5,485)
    arr = arr[15:415, 5:485]

    # Divide by 2^7
    arr = arr.astype(np.float32) / (2**7)

    # Zero → NaN
    arr[arr == 0.0] = np.nan

    return arr


def main(directory: str):
    pattern = re.compile(r"cam_1_500_480_(\d+)\.png$")
    results = []

    files = sorted(fn for fn in os.listdir(directory) if pattern.match(fn))
    if not files:
        print("No matching files found (expected cam_1_500_480_<x>.png).")
        return

    for fname in files:
        x = int(pattern.match(fname).group(1))
        target = 0.24 + (0.02 * x)
        fpath = os.path.join(directory, fname)

        try:
            img = load_png_div128_cropped(fpath)

            mae = float(np.nanmean(np.abs(img - target)))

            print(f"x={x:02d}  target={target:.6f}  MAE={mae:.6f}  file={fname}")
            results.append((x, target, mae, fname))

        except Exception as e:
            print(f"ERROR processing {fname}: {e}")
            results.append((x, target, np.nan, fname))

    # Save results to CSV
    df = pd.DataFrame(results, columns=["x", "target", "MAE", "filename"])
    df = df.sort_values("x")
    df.to_csv(os.path.join(directory, CSV_NAME), index=False)
    print(f"\n✅ Results saved to: {os.path.join(directory, CSV_NAME)}")

    # ----------- PLOT MAE vs Target -----------
    plt.figure(figsize=(7, 4.2))
    plt.scatter(df["target"], df["MAE"], marker="o", label="MAE vs Target")

    plt.title("MAE vs Target (cropped, div128)")
    plt.xlabel("Target Value (0.24 + 0.02·x)")
    plt.ylabel("MAE")
    plt.grid(True, alpha=0.3)
    plt.legend()

    plt.tight_layout()
    plt.savefig(os.path.join(directory, PLOT_NAME), dpi=150)
    plt.close()

    print(f"📈 Plot saved to: {os.path.join(directory, PLOT_NAME)}")


if __name__ == "__main__":
    directory = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIR
    main(directory)
