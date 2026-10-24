#!/usr/bin/env bash
# Capture one screenshot per scene listed in tools/screens.txt and wrap them in a phone frame.
# Output: fastlane/metadata/android/en-US/images/phoneScreenshots/NN_<scene>.png
#
# main.gd handles `--screenshot=<scene> --out=<png> [--lang=xx] [--fixture=<name>]` (ScreenshotArgs) and quits itself.
# Capture needs a real GL context: runs under xvfb-run with --rendering-driver opengl3 (not --headless).
# Add every new screen to tools/screens.txt (one scene per line).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/.tools/godot}"
SCREENS="$ROOT/tools/screens.txt"
RAW="$ROOT/export/screenshots_raw"
OUT="${SCREENSHOT_OUT:-$ROOT/fastlane/metadata/android/en-US/images/phoneScreenshots}"
RESOLUTION="${SCREENSHOT_RESOLUTION:-1080x1920}"

[ -x "$GODOT" ] || GODOT="$(command -v godot || true)"
[ -n "$GODOT" ] || { echo "Godot not found; run 'make setup'" >&2; exit 1; }
[ -f "$SCREENS" ] || { echo "$SCREENS missing" >&2; exit 1; }

mkdir -p "$RAW" "$OUT"
rm -f "$RAW"/*.png

runner=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
  runner=(xvfb-run -a -s "-screen 0 1280x2048x24")
fi

i=0
while IFS= read -r scene || [ -n "$scene" ]; do
  case "$scene" in ''|'#'*) continue ;; esac
  i=$((i + 1))
  name="$(printf '%02d_%s' "$i" "$(basename "${scene%.tscn}")")"
  echo "[screenshots] $scene -> $name.png"
  extra=("--fixture=${SCREENSHOT_FIXTURE:-default}")
  [ -z "${SCREENSHOT_LANG:-}" ] || extra+=("--lang=${SCREENSHOT_LANG}")
  # --quit-after is a safety net only (main.gd quits itself after 2 frames).
  "${runner[@]}" "$GODOT" --path "$ROOT/game" --rendering-driver opengl3 --resolution "$RESOLUTION" \
    --quit-after 600 -- "--screenshot=$scene" "--out=$RAW/$name.png" "${extra[@]}" >/dev/null 2>&1 || true
  [ -f "$RAW/$name.png" ] || echo "[screenshots] WARNING: no image produced for $scene" >&2
done < "$SCREENS"

if ls "$RAW"/*.png >/dev/null 2>&1; then
  python3 "$ROOT/tools/frame_screenshots.py" --in "$RAW" --out "$OUT"
else
  echo "[screenshots] nothing to frame" >&2
fi

produced="$(find "$RAW" -maxdepth 1 -name '*.png' | wc -l)"
if [ "$produced" -ne "$i" ]; then
  echo "[screenshots] ERROR: expected $i images, got $produced" >&2
  exit 1
fi
