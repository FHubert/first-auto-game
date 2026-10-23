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


CLASSIC = ["#E63946", "#FB8500", "#FFD166", "#80ED99", "#2A9D8F", "#4CC9F0",
           "#3A86FF", "#8338EC", "#FF70A6", "#9C6644", "#ADB5BD", "#F8F9FA"]
NINE_SLICE = {"left": 24, "top": 48, "right": 24, "bottom": 48}
MIN_DELTA_E = 20.0
PASTEL = ["#F4A6A6", "#F9C9A0", "#F6E58D", "#B8E6A1", "#8FD9C0", "#9ADBF5",
          "#8DA0F2", "#D3A4F5", "#F2A9D8", "#B58B66", "#B6BCC8", "#FFFFFF"]
NEON = ["#FF1744", "#FF9100", "#FFEA00", "#76FF03", "#00E676", "#00E5FF",
        "#2979FF", "#651FFF", "#D500F9", "#FF4081", "#8D6E63", "#ECEFF1"]
OCEAN = ["#E76F51", "#F4A261", "#E9C46A", "#9BD1A0", "#2A9D8F", "#4CC9F0",
         "#1D6FB8", "#5E60CE", "#B8A9E8", "#D9C5A0", "#6B7A8F", "#EAF4F4"]
THEMES: list[dict] = [
    {"id": "classic", "name": "Classic", "shape": "tube", "background": "#14213D",
     "background_alt": "#1F3A6B", "glass": "#CAD2E0", "liquids": CLASSIC},
    {"id": "pastel", "name": "Pastel", "shape": "flask", "background": "#F4F1EA",
     "background_alt": "#E6E1D6", "glass": "#5C5C6E",
     "liquids": PASTEL},
    {"id": "neon", "name": "Neon", "shape": "tube", "background": "#0B0B14",
     "background_alt": "#161628", "glass": "#8A8AA8",
     "liquids": NEON},
    {"id": "ocean", "name": "Ocean", "shape": "flask", "background": "#0A2540",
     "background_alt": "#123B63", "glass": "#BFD7EA",
     "liquids": OCEAN},
]


def lab(hex_color: str) -> tuple[float, float, float]:
    """sRGB hex -> CIE Lab (D65)."""
    lin = []
    for i in (1, 3, 5):
        v = int(hex_color[i:i + 2], 16) / 255
        lin.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    r, g, b = lin
    xyz = (
        (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047,
        0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
        (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883,
    )
    fx, fy, fz = [t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116 for t in xyz]
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def delta_e(a: str, b: str) -> float:
    return math.dist(lab(a), lab(b))


def min_delta_e(colors: list[str]) -> float:
    return min(delta_e(a, b) for i, a in enumerate(colors) for b in colors[i + 1:])


def check_themes() -> int:
    bad = 0
    for t in THEMES:
        m = min_delta_e(t["liquids"])
        ok = len(set(t["liquids"])) == 12 and m >= MIN_DELTA_E
        bad += not ok
        print(f"{t['id']}: n={len(t['liquids'])} minDeltaE={m:.1f} {'OK' if ok else 'FAIL'}")
    return 1 if bad else 0


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


W = "#FFFFFF"
UI_ICONS = {
    "icon_undo": f'<path d="M44 40 L20 62 L44 84 Z" fill="{W}"/>'
                 f'<path d="M30 62 A34 34 0 1 1 52 100" fill="none" stroke="{W}" stroke-width="12" stroke-linecap="round"/>',
    "icon_restart": f'<path d="M100 64 A36 36 0 1 1 82 33" fill="none" stroke="{W}" stroke-width="12" stroke-linecap="round"/>'
                    f'<polygon points="70,12 100,34 66,48" fill="{W}"/>',
    "icon_add_tube": f'<rect x="36" y="10" width="56" height="108" rx="24" fill="none" stroke="{W}" stroke-width="10"/>'
                     f'<rect x="58" y="42" width="12" height="44" fill="{W}"/><rect x="42" y="58" width="44" height="12" fill="{W}"/>',
    "icon_hint": f'<circle cx="64" cy="50" r="34" fill="{W}"/><polygon points="50,76 78,76 74,96 54,96" fill="{W}"/>'
                 f'<rect x="48" y="98" width="32" height="14" rx="6" fill="{W}"/>',
    "icon_coin": '<circle cx="64" cy="64" r="52" fill="#FFD166"/><circle cx="64" cy="64" r="34" fill="none" stroke="#14213D" stroke-width="8"/>',
    "icon_streak": '<path d="M64 8 C96 40 108 64 96 92 A36 36 0 0 1 32 92 C24 70 40 56 44 36 C52 46 56 52 58 56 C62 40 62 24 64 8 Z" fill="#FF9F1C"/>'
                   '<path d="M64 62 C80 82 84 96 76 106 A16 16 0 0 1 52 106 C46 96 56 84 64 62 Z" fill="#FFD166"/>',
}


def tube_image(shape: str):
    from PIL import Image, ImageDraw

    def mask(inset: int):
        m = Image.new("L", (128, 384), 0)
        d = ImageDraw.Draw(m)
        if shape == "tube":
            d.rounded_rectangle((8 + inset, 8 + inset, 119 - inset, 375 - inset), 40 - inset, fill=255, corners=(False, False, True, True))
            d.rectangle((8 + inset, 8 + inset, 119 - inset, 60), fill=255)
        else:
            n, top = 32, int(384 * 0.3)
            d.rounded_rectangle((8 + inset, int(384 * 0.4) + inset, 119 - inset, 375 - inset), 40 - inset, fill=255)
            d.polygon([(8 + n + inset, 8 + inset), (119 - n - inset, 8 + inset), (119 - n - inset, top + 20),
                       (119 - inset, int(384 * 0.4)), (8 + inset, int(384 * 0.4)), (8 + n + inset, top + 20)], fill=255)
        return m

    outer, inner = mask(0), mask(4)
    img = Image.new("RGBA", (128, 384), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (128, 384), (0xCA, 0xD2, 0xE0, 200)), mask=outer)
    img.paste(Image.new("RGBA", (128, 384), (0xCA, 0xD2, 0xE0, 90)), mask=inner)
    return img


def write_pngs(out: Path) -> None:
    from PIL import Image, ImageDraw

    (out / "tubes").mkdir(parents=True, exist_ok=True)
    for shape in ("tube", "flask"):
        tube_image(shape).save(out / "tubes" / f"{shape}_body.png")
    hl = Image.new("RGBA", (128, 384), (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle((20, 70, 31, 330), 5, fill=(255, 255, 255, 60))
    hl.save(out / "tubes" / "tube_highlight.png")

    # App icon (RGB, no alpha): vertical gradient + stylized tube with 4 liquid layers.
    top, bot = (0x1F, 0x3A, 0x6B), (0x14, 0x21, 0x3D)
    icon = Image.new("RGB", (1024, 1024))
    d = ImageDraw.Draw(icon)
    for y in range(1024):
        d.line([(0, y), (1023, y)], fill=tuple(round(a + (b - a) * y / 1023) for a, b in zip(top, bot)))
    glass = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(glass).rounded_rectangle((352, 120, 672, 904), 160, fill=255, corners=(False, False, True, True))
    ImageDraw.Draw(glass).rectangle((352, 120, 672, 300), fill=255)
    icon.paste(Image.new("RGB", (1024, 1024), (0x7C, 0x8D, 0xA8)), mask=glass.point(lambda v: v * 0.55))
    liq = Image.new("RGB", (1024, 1024))
    ld = ImageDraw.Draw(liq)
    for i, col in enumerate(("#E63946", "#FFD166", "#2A9D8F", "#3A86FF")):
        ld.rectangle((0, 880 - 120 * (i + 1), 1023, 880 - 120 * i), fill=col)
    inner = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(inner).rounded_rectangle((376, 400, 648, 880), 136, fill=255, corners=(False, False, True, True))
    ImageDraw.Draw(inner).rectangle((376, 400, 648, 600), fill=255)
    icon.paste(liq, mask=inner)
    icon.save(out / "icon_1024.png")
    icon.convert("RGBA").resize((512, 512), Image.LANCZOS).save(out / "icon_512.png")


def themes_doc() -> str:
    return json.dumps({"version": 1, "nine_slice": NINE_SLICE, "themes": THEMES}, indent=2, sort_keys=True) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=ROOT / "game" / "assets" / "sprites")
    ap.add_argument("--palette", type=Path, default=HERE / "palette.json")
    ap.add_argument("--themes-out", type=Path, default=ROOT / "game" / "assets" / "themes.json")
    ap.add_argument("--check-themes", action="store_true", help="print min deltaE per theme, exit 1 if < 20")
    ap.add_argument("--initial", default="F", help="letter on the app icon")
    args = ap.parse_args()

    if args.check_themes:
        return check_themes()
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
    (args.out / "ui").mkdir(exist_ok=True)
    for name, body in UI_ICONS.items():
        (args.out / "ui" / f"{name}.svg").write_text(svg(128, 128, body), encoding="utf-8")
    write_pngs(args.out)
    args.themes_out.parent.mkdir(parents=True, exist_ok=True)
    args.themes_out.write_text(themes_doc(), encoding="utf-8")
    print(f"wrote 6 ui icons, tubes, icons, {args.themes_out.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
