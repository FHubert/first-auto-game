#!/usr/bin/env python3
"""Wrap raw screenshots in a simple phone frame (needs Pillow; copies unframed if missing).

Usage: python3 tools/frame_screenshots.py --in DIR --out DIR
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--bg", default="#14213D", help="canvas colour")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    files = sorted(args.src.glob("*.png"))
    if not files:
        print("no input images", file=sys.stderr)
        return 1
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("WARNING: Pillow not installed (pip install pillow); copying unframed", file=sys.stderr)
        for p in files:
            shutil.copy(p, args.out / p.name)
        return 0

    for p in files:
        shot = Image.open(p).convert("RGB")
        w, h = shot.size
        bezel, pad = max(12, w // 45), max(40, w // 12)
        radius = w // 10
        canvas = Image.new("RGB", (w + 2 * (bezel + pad), h + 2 * (bezel + pad)), args.bg)
        d = ImageDraw.Draw(canvas)
        d.rounded_rectangle(
            (pad, pad, pad + w + 2 * bezel, pad + h + 2 * bezel), radius=radius + bezel, fill="#05070D"
        )
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=radius, fill=255)
        canvas.paste(shot, (pad + bezel, pad + bezel), mask)
        canvas.save(args.out / p.name)
        print(f"framed {p.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
