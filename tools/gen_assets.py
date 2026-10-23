#!/usr/bin/env python3
"""Deterministic placeholder art generator (SVG, plus PNG when cairosvg is installed).

Reads tools/palette.json and writes to game/assets/sprites/ (or --out):
  icon_1024.*              app icon 1024x1024 (geometric shape + initial)
  feature_graphic_1024x500.*  Play Store feature graphic
  shape_circle|square|triangle|star.*  256x256 sprites
  background_720x1280.*    vertical gradient background
Same input -> byte-identical SVG output (no randomness, no timestamps).
PNG output depends on the installed cairo/fonts; install with `pip install cairosvg`.

Usage: python3 tools/gen_assets.py [--out DIR] [--initial F] [--palette PATH]
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HERE = Path(__file__).resolve().parent


def svg(w: int, h: int, body: str, defs: str = "") -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
        f"{('<defs>' + defs + '</defs>') if defs else ''}{body}</svg>\n"
    )


def f(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


def star_points(cx: float, cy: float, r_out: float, r_in: float, n: int = 5) -> str:
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = -math.pi / 2 + i * math.pi / n
        pts.append(f"{f(cx + r * math.cos(a))},{f(cy + r * math.sin(a))}")
    return " ".join(pts)


def triangle_points(cx: float, cy: float, r: float) -> str:
    pts = []
    for i in range(3):
        a = -math.pi / 2 + i * 2 * math.pi / 3
        pts.append(f"{f(cx + r * math.cos(a))},{f(cy + r * math.sin(a))}")
    return " ".join(pts)


def gradient(gid: str, c1: str, c2: str) -> str:
    return (
        f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>'
    )


def build(pal: dict, initial: str) -> dict[str, str]:
    c = pal["colors"]
    bg, bg2, acc = pal["background"], pal["background_alt"], pal["accent"]
    out: dict[str, str] = {}

    # App icon: full-bleed square (stores round the corners themselves).
    out["icon_1024"] = svg(
        1024,
        1024,
        '<rect width="1024" height="1024" fill="url(#g)"/>'
        f'<circle cx="512" cy="512" r="340" fill="{c[0]}"/>'
        f'<polygon points="{star_points(512, 512, 250, 110)}" fill="{acc}" opacity="0.35"/>'
        f'<text x="512" y="512" font-family="Helvetica, Arial, sans-serif" font-weight="700" font-size="400" '
        f'text-anchor="middle" dominant-baseline="central" fill="{bg}">{initial}</text>',
        gradient("g", bg2, bg),
    )

    # Feature graphic: the four shapes on a gradient, left aligned title block as plain bars.
    shapes = (
        f'<circle cx="560" cy="250" r="110" fill="{c[0]}"/>'
        f'<rect x="690" y="140" width="220" height="220" rx="24" fill="{c[1]}"/>'
        f'<polygon points="{triangle_points(250, 250, 140)}" fill="{c[2]}"/>'
        f'<polygon points="{star_points(830, 250, 120, 52)}" fill="{acc}"/>'
    )
    out["feature_graphic_1024x500"] = svg(
        1024, 500, '<rect width="1024" height="500" fill="url(#g)"/>' + shapes, gradient("g", bg2, bg)
    )

    # Sprites 256x256.
    out["shape_circle"] = svg(256, 256, f'<circle cx="128" cy="128" r="112" fill="{c[0]}"/>')
    out["shape_square"] = svg(256, 256, f'<rect x="20" y="20" width="216" height="216" rx="20" fill="{c[1]}"/>')
    out["shape_triangle"] = svg(256, 256, f'<polygon points="{triangle_points(128, 140, 118)}" fill="{c[2]}"/>')
    out["shape_star"] = svg(256, 256, f'<polygon points="{star_points(128, 132, 118, 50)}" fill="{acc}"/>')

    # Background 720x1280: gradient plus faint accent circles.
    dots = "".join(
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c[i % len(c)]}" opacity="0.08"/>'
        for i, (x, y, r) in enumerate([(120, 200, 160), (600, 480, 120), (200, 900, 200), (560, 1150, 140)])
    )
    out["background_720x1280"] = svg(
        720, 1280, '<rect width="720" height="1280" fill="url(#g)"/>' + dots, gradient("g", bg2, bg)
    )
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "game" / "assets" / "sprites")
    ap.add_argument("--palette", type=Path, default=HERE / "palette.json")
    ap.add_argument("--initial", default="F", help="letter on the app icon")
    args = ap.parse_args()

    pal = json.loads(args.palette.read_text(encoding="utf-8"))
    if len(pal.get("colors", [])) < 6:
        print("palette.json needs 6 colors", file=sys.stderr)
        return 1
    args.out.mkdir(parents=True, exist_ok=True)

    try:
        import cairosvg  # type: ignore
    except Exception:
        cairosvg = None
        print("WARNING: cairosvg not available (pip install cairosvg); writing SVG only", file=sys.stderr)

    for name, doc in build(pal, args.initial[:1].upper()).items():
        svg_path = args.out / f"{name}.svg"
        svg_path.write_text(doc, encoding="utf-8")
        if cairosvg:
            cairosvg.svg2png(bytestring=doc.encode("utf-8"), write_to=str(args.out / f"{name}.png"))
        print(f"wrote {svg_path.name}" + (" + png" if cairosvg else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
