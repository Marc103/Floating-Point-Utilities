#!/usr/bin/env python3
"""
png_to_bw_ppm_p3.py
Convert a PNG (8-bit or 16-bit per channel) to a black & white PPM **P3 (ASCII)**
using only the green channel (R=G=B=G).

Usage:
    python png_to_bw_ppm_p3.py input.png [output.ppm]

Requires:
    pip install pillow
"""
import sys
import argparse
from pathlib import Path
from PIL import Image

def get_green_channel(img: Image.Image) -> Image.Image:
    """
    Return the image's green channel as a single-band Pillow Image.
    - If the image has a G channel, returns that band.
    - If grayscale, returns the single band as the 'green' equivalent.
    Prefers preserving bit depth (e.g., 'I;16*') when Pillow provides it.
    """
    # If there's a green channel, try to extract it directly
    try:
        g = img.getchannel('G')  # For RGB/RGBA, possibly 8-bit; in some cases 16-bit per band
        return g
    except Exception:
        pass

    # If the image is grayscale (8 or 16-bit), just return it
    if img.mode in ("L", "I;16", "I;16B", "I;16L", "I"):
        return img

    # Fall back: convert to 8-bit RGB and take green (this will downscale to 8-bit)
    img8 = img.convert("RGB")
    _, g8, _ = img8.split()
    return g8  # 'L' mode (8-bit)

def write_ppm_p3(output_path: Path, width: int, height: int, maxval: int, gray_values):
    """
    Write a PPM P3 file where each pixel is gray: 'v v v'.
    gray_values: iterable of ints in [0, maxval], length = width*height
    """
    with open(output_path, "w", encoding="ascii") as f:
        # Header
        f.write("P3\n")
        f.write(f"{width} {height}\n")
        f.write(f"{maxval}\n")

        # Body: write a few pixels per line for readability
        per_line = 1  # number of pixels per line (each pixel contributes 3 numbers)
        triplets_on_line = 0
        count_in_line = 0

        for v in gray_values:
            # Clamp just in case
            if v < 0: v = 0
            if v > maxval: v = maxval
            # Write "v v v"
            f.write(f"{v} {v} {v} ")
            count_in_line += 3
            triplets_on_line += 1
            if triplets_on_line >= per_line:
                f.write("\n")
                triplets_on_line = 0
                count_in_line = 0

        if triplets_on_line != 0:
            f.write("\n")

def png_to_bw_ppm_p3(input_path: Path, output_path: Path):
    img = Image.open(input_path)

    # Extract green (or equivalent gray) band while preserving depth if possible
    g = get_green_channel(img)

    # Determine bit depth from band mode
    if g.mode in ("I;16", "I;16B", "I;16L", "I"):
        # 16-bit grayscale data
        maxval = 65535
        # Ensure we iterate ints, not bytes
        data = g.getdata()  # sequence of Python ints
    else:
        # 8-bit grayscale ('L') or anything else converted to 8-bit
        if g.mode != "L":
            g = g.convert("L")
        maxval = 255
        data = g.getdata()

    width, height = g.size
    write_ppm_p3(output_path, width, height, maxval, data)

def main():
    ap = argparse.ArgumentParser(description="Convert PNG to black & white PPM P3 using the green channel.")
    ap.add_argument("input", help="Input PNG file (8-bit or 16-bit per channel)")
    ap.add_argument("output", nargs="?", help="Output PPM (P3/ASCII). Defaults to input name with .ppm")
    args = ap.parse_args()

    in_path = Path(args.input)
    if not in_path.exists():
        print(f"Error: {in_path} does not exist.", file=sys.stderr)
        sys.exit(1)

    out_path = Path(args.output) if args.output else in_path.with_suffix(".ppm")

    try:
        png_to_bw_ppm_p3(in_path, out_path)
    except Exception as e:
        print(f"Conversion failed: {e}", file=sys.stderr)
        sys.exit(2)

    print(f"Wrote {out_path}")

if __name__ == "__main__":
    main()
