#!/usr/bin/env bash
# Capture one screenshot per scene listed in tools/screens.txt and wrap them in a phone frame.
# Output: fastlane/metadata/android/en-US/images/phoneScreenshots/NN_<scene>.png
#
# TODO(main.gd): this needs a `--screenshot=<scene>` user-arg handler in game/src/core/main.gd:
#   parse OS.get_cmdline_user_args(), change_scene_to_file(<scene>), `await RenderingServer.frame_post_draw`
#   (one frame), then `get_viewport().get_texture().get_image().save_png(<--out path>)` and `get_tree().quit()`.
# Until that exists the capture step logs a warning per screen and no images are produced.
# Rendering needs a GPU/software GL context, so --headless (dummy renderer) cannot be used for the
# actual capture; on CI use xvfb-run. Add every new screen to tools/screens.txt (one scene per line).
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
  # Scene change + save_png happen inside main.gd (see TODO above).
  "${runner[@]}" "$GODOT" --path "$ROOT/game" --resolution "$RESOLUTION" --quit-after 600 \
    -- "--screenshot=$scene" "--out=$RAW/$name.png" >/dev/null 2>&1 || true
  [ -f "$RAW/$name.png" ] || echo "[screenshots] WARNING: no image produced for $scene (main.gd --screenshot not implemented?)" >&2
done < "$SCREENS"

if ls "$RAW"/*.png >/dev/null 2>&1; then
  python3 "$ROOT/tools/frame_screenshots.py" --in "$RAW" --out "$OUT"
else
  echo "[screenshots] nothing to frame" >&2
fi
