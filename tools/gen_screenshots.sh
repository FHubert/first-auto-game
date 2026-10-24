#!/usr/bin/env bash
# Capture screenshots via main.gd (`--screenshot=<scene> --out=<png> [--lang=xx] [--fixture=<name>]`).
# Smoke (default): every scene in tools/screens.txt -> export/screenshots_framed/NN_<scene>.png
# Store (`--store` or SCREENSHOT_STORE=1): tools/screens_store.txt x {en-US,pl-PL,de-DE}
#   -> fastlane/metadata/android/<locale>/images/phoneScreenshots/NN_<caption_key>.png (1080x1920)
#
# Capture needs a real GL context: runs under xvfb-run with --rendering-driver opengl3 (not --headless).
# Add every new screen to tools/screens.txt (smoke) and, if it is a store shot, tools/screens_store.txt
# (format: <scene>|<fixture>|<caption_key>).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/.tools/godot}"
RESOLUTION="${SCREENSHOT_RESOLUTION:-1080x1920}"
STORE="${SCREENSHOT_STORE:-0}"
[ "${1:-}" = "--store" ] && STORE=1
LOCALES=(en-US pl-PL de-DE)

[ -x "$GODOT" ] || GODOT="$(command -v godot || true)"
[ -n "$GODOT" ] || { echo "Godot not found; run 'make setup'" >&2; exit 1; }

runner=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
  runner=(xvfb-run -a -s "-screen 0 1280x2048x24")
fi

# capture <list> <raw_dir> <lang>: writes NN_<name>.png per list line; exits 1 on a missing image.
capture() {
  local list="$1" raw="$2" lang="$3" i=0 line scene fixture key name extra produced
  [ -f "$list" ] || { echo "$list missing" >&2; exit 1; }
  mkdir -p "$raw"
  rm -f "$raw"/*.png
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    scene="${line%%|*}"; fixture=""; key=""
    if [ "$scene" != "$line" ]; then
      IFS='|' read -r scene fixture key <<< "$line"
    fi
    fixture="${fixture:-${SCREENSHOT_FIXTURE:-default}}"
    i=$((i + 1))
    name="$(printf '%02d_%s' "$i" "${key:-$(basename "${scene%.tscn}")}")"
    echo "[screenshots] $scene ($fixture${lang:+, $lang}) -> $name.png"
    extra=("--fixture=$fixture")
    [ -z "$lang" ] || extra+=("--lang=$lang")
    # --quit-after is a safety net only (main.gd quits itself after 2 frames).
    "${runner[@]}" "$GODOT" --path "$ROOT/game" --rendering-driver opengl3 --resolution "$RESOLUTION" \
      --quit-after 600 -- "--screenshot=$scene" "--out=$raw/$name.png" "${extra[@]}" >/dev/null 2>&1 || true
    [ -f "$raw/$name.png" ] || echo "[screenshots] WARNING: no image produced for $scene" >&2
  done < "$list"
  produced="$(find "$raw" -maxdepth 1 -name '*.png' | wc -l)"
  if [ "$produced" -ne "$i" ]; then
    echo "[screenshots] ERROR: expected $i images, got $produced" >&2
    exit 1
  fi
}

if [ "$STORE" = "1" ]; then
  for locale in "${LOCALES[@]}"; do
    lang="${locale%%-*}"
    capture "$ROOT/tools/screens_store.txt" "$ROOT/export/screenshots_raw/$locale" "$lang"
    python3 "$ROOT/tools/frame_screenshots.py" --in "$ROOT/export/screenshots_raw/$locale" \
      --out "$ROOT/fastlane/metadata/android/$locale/images/phoneScreenshots" \
      --lang "$lang" --captions "$ROOT/tools/captions.json" --size 1080x1920
  done
else
  OUT="${SCREENSHOT_OUT:-$ROOT/export/screenshots_framed}"
  capture "$ROOT/tools/screens.txt" "$ROOT/export/screenshots_raw" "${SCREENSHOT_LANG:-}"
  python3 "$ROOT/tools/frame_screenshots.py" --in "$ROOT/export/screenshots_raw" --out "$OUT"
fi
