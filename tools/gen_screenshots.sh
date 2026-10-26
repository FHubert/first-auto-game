#!/usr/bin/env bash
# Capture screenshots via main.gd (`--screenshot=<scene> --out=<png> [--lang=xx] [--fixture=<name>]`).
# Smoke (default): every scene in tools/screens.txt -> export/screenshots_framed/<WxH>/NN_<name>.png
#   (parent overridable with SCREENSHOT_OUT; raw captures in export/screenshots_raw/<WxH>/)
# Store (`--store` or SCREENSHOT_STORE=1): tools/screens_store.txt x {en-US,pl-PL,de-DE}
#   -> fastlane/metadata/android/<locale>/images/phoneScreenshots/NN_<caption_key>.png (1080x1920)
#
# Usage: gen_screenshots.sh [--store] [--size WxH] [--print-config] [--dry-run] [--help]
#   --size WxH      capture resolution (default 1080x1920, env SCREENSHOT_RESOLUTION; the flag wins);
#                   works with --store in any order, store framing uses the same size
#   --print-config  print "RESOLUTION=... STORE=..." and exit 0 (no Godot needed)
#   --dry-run       print the parsed entries (scene|fixture|name) and the output dir, exit 0 (no Godot)
#
# Capture needs a real GL context: runs under xvfb-run with --rendering-driver opengl3 (not --headless).
# Add every new screen to tools/screens.txt (smoke) and, if it is a store shot, tools/screens_store.txt
# (format: <scene>|<fixture>|<caption_key>).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/.tools/godot}"
RESOLUTION="${SCREENSHOT_RESOLUTION:-1080x1920}"
STORE="${SCREENSHOT_STORE:-0}"
PRINT_CONFIG=0
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --store) STORE=1 ;;
    --print-config) PRINT_CONFIG=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --size)
      [ $# -ge 2 ] || { echo "--size needs a WxH value" >&2; exit 2; }
      RESOLUTION="$2"; shift ;;
    --size=*) RESOLUTION="${1#--size=}" ;;
    -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
if ! [[ "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "invalid size '$RESOLUTION' (expected WxH, e.g. 720x1560)" >&2
  exit 2
fi
if [ "$PRINT_CONFIG" = "1" ]; then
  echo "RESOLUTION=$RESOLUTION STORE=$STORE"
  exit 0
fi
LOCALES=(en-US pl-PL de-DE)
OUT="${SCREENSHOT_OUT:-$ROOT/export/screenshots_framed}/$RESOLUTION"
RAW="$ROOT/export/screenshots_raw/$RESOLUTION"

if [ "$DRY_RUN" = "1" ]; then
  list="$ROOT/tools/screens.txt"
  [ "$STORE" = "1" ] && list="$ROOT/tools/screens_store.txt"
  echo "RESOLUTION=$RESOLUTION STORE=$STORE"
  echo "OUT_DIR=$OUT"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    IFS='|' read -r scene fixture key <<< "$line"
    echo "ENTRY $scene|${fixture:-default}|${key:-$(basename "${scene%.tscn}")}"
  done < "$list"
  exit 0
fi

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
      --lang "$lang" --captions "$ROOT/tools/captions.json" --size "$RESOLUTION"
  done
else
  capture "$ROOT/tools/screens.txt" "$RAW" "${SCREENSHOT_LANG:-}"
  python3 "$ROOT/tools/frame_screenshots.py" --in "$RAW" --out "$OUT"
fi
