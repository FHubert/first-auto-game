#!/usr/bin/env python3
"""Wrap raw screenshots in a simple phone frame (needs Pillow; copies unframed if missing).

Usage: python3 tools/frame_screenshots.py --in DIR --out DIR [--lang xx --captions FILE --size WxH]

With --size the canvas is exactly WxH: a caption band on top (caption key = file name after "NN_"),
the framed shot scaled to fit below.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

FONT = Path(__file__).resolve().parent.parent / "game" / "assets" / "fonts" / "nunito.ttf"
CAPTION_COLOR = "#FFFFFF"


def caption_for(name: str, captions: dict, lang: str) -> str:
    key = Path(name).stem.split("_", 1)[-1]
    text = captions.get(key, {}).get(lang, "")
    if not text:
        print(f"WARNING: no caption for key '{key}' lang '{lang}'", file=sys.stderr)
    return text


def compose(framed, size: tuple[int, int], text: str, bg: str):
    from PIL import Image, ImageDraw

    cw, ch = size
    canvas = Image.new("RGB", size, bg)
    d = ImageDraw.Draw(canvas)
    margin = cw // 24
    top = margin
    if text:
        font = load_font(cw // 16)
        lines = wrap(d, text, font, int(cw * 0.9))
        line_h = int(font.size * 1.25)
        for i, line in enumerate(lines):
            d.text((cw // 2, top + i * line_h), line, font=font, fill=CAPTION_COLOR, anchor="ma")
        top += len(lines) * line_h + margin
    avail_h, avail_w = ch - top - margin, cw - 2 * margin
    scale = min(avail_w / framed.width, avail_h / framed.height)
    fw, fh = int(framed.width * scale), int(framed.height * scale)
    framed = framed.resize((fw, fh), Image.LANCZOS)
    canvas.paste(framed, ((cw - fw) // 2, top + (avail_h - fh) // 2))
    return canvas


def load_font(size: int):
    from PIL import ImageFont

    font = ImageFont.truetype(str(FONT), size)
    try:
        font.set_variation_by_name("Bold")
    except Exception:  # static font or missing axis
        pass
    return font


def wrap(draw, text: str, font, max_w: int) -> list[str]:
    if draw.textlength(text, font=font) <= max_w:
        return [text]
    words = text.split()
    best = [text]
    for i in range(1, len(words)):  # balanced 2-line split: minimise the wider line
        lines = [" ".join(words[:i]), " ".join(words[i:])]
        if best == [text] or max(draw.textlength(x, font=font) for x in lines) < max(
            draw.textlength(x, font=font) for x in best
        ):
            best = lines
    return best


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--bg", default="#14213D", help="canvas colour")
    ap.add_argument("--lang", default="")
    ap.add_argument("--captions", type=Path)
    ap.add_argument("--size", default="", help="WxH canvas, e.g. 1080x1920")
    args = ap.parse_args()
    target = tuple(int(v) for v in args.size.lower().split("x")) if args.size else None
    captions = json.loads(args.captions.read_text(encoding="utf-8")) if args.captions else {}
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
        if target:
            canvas = compose(canvas, target, caption_for(p.name, captions, args.lang), args.bg)
        canvas.save(args.out / p.name, optimize=True)
        print(f"framed {p.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
