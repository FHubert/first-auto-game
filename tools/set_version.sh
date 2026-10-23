#!/usr/bin/env bash
# Set the app version in both export presets and in game/src/core/version.gd.
# Usage: tools/set_version.sh <version_name> <version_code>
#   Android preset: version/name, version/code
#   iOS preset:     application/short_version (name), application/version (build number = code)
#   version.gd:     VERSION = name, BUILD_INFO = "<name>+<code>"
set -euo pipefail

NAME="${1:-}"
CODE="${2:-}"
if [ -z "$NAME" ] || [ -z "$CODE" ]; then
  echo "usage: $0 <version_name> <version_code>" >&2
  exit 2
fi
[[ "$NAME" =~ ^[0-9]+(\.[0-9]+)*([-+][0-9A-Za-z.-]+)?$ ]] || { echo "set_version: bad version_name '$NAME'" >&2; exit 2; }
[[ "$CODE" =~ ^[0-9]+$ ]] || { echo "set_version: version_code must be an integer" >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRESETS="${PRESETS_FILE:-$ROOT/game/export_presets.cfg}"
VERSION_GD="${VERSION_GD_FILE:-$ROOT/game/src/core/version.gd}"

# replace_line <file> <regex matching the whole line> <new line>; returns 1 when nothing matched.
replace_line() {
  local file="$1" regex="$2" new="$3" tmp
  grep -Eq "$regex" "$file" || return 1
  tmp="$(mktemp)"
  awk -v re="$regex" -v new="$new" '$0 ~ re { print new; next } { print }' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

if [ -f "$PRESETS" ]; then
  found=0
  replace_line "$PRESETS" '^version/name=' "version/name=\"$NAME\"" && found=$((found + 1)) || true
  replace_line "$PRESETS" '^version/code=' "version/code=$CODE" && found=$((found + 1)) || true
  replace_line "$PRESETS" '^application/short_version=' "application/short_version=\"$NAME\"" && found=$((found + 1)) || true
  replace_line "$PRESETS" '^application/version=' "application/version=\"$CODE\"" && found=$((found + 1)) || true
  if [ "$found" -eq 0 ]; then
    echo "set_version: no version keys found in $PRESETS" >&2
    exit 1
  fi
  echo "set_version: updated $found key(s) in $(basename "$PRESETS")"
else
  echo "set_version: $PRESETS not found" >&2
  exit 1
fi

if [ -f "$VERSION_GD" ]; then
  replace_line "$VERSION_GD" '^const VERSION: String = ' "const VERSION: String = \"$NAME\"" || echo "set_version: warning: VERSION line not found in version.gd" >&2
  replace_line "$VERSION_GD" '^const BUILD_INFO: String = ' "const BUILD_INFO: String = \"$NAME+$CODE\"" || echo "set_version: warning: BUILD_INFO line not found in version.gd" >&2
else
  echo "set_version: warning: $VERSION_GD not found, skipped" >&2
fi
echo "set_version: $NAME ($CODE)"
