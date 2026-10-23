#!/usr/bin/env bash
# Replace secret placeholders in game/export_presets.cfg with values from the environment.
# Usage: tools/inject_secrets.sh android|ios
# Never prints secret values. Fails when a required variable is missing/empty.
set -euo pipefail
set +x # belt and braces: tracing would leak values

PRESETS="${PRESETS_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/game/export_presets.cfg}"

case "${1:-}" in
  android) VARS=(ANDROID_KEYSTORE_PATH ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD) ;;
  ios) VARS=(APPLE_TEAM_ID) ;;
  *) echo "usage: $0 android|ios" >&2; exit 2 ;;
esac

[ -f "$PRESETS" ] || { echo "inject_secrets: $PRESETS not found" >&2; exit 1; }

# Validate first, so a failure never leaves a half-patched file.
missing=()
for name in "${VARS[@]}"; do
  value="${!name:-}"
  if [ -z "$value" ]; then
    missing+=("$name")
  elif [[ "$value" == *'"'* || "$value" == *$'\n'* ]]; then
    echo "inject_secrets: $name contains a double quote or newline (would corrupt the .cfg)" >&2
    exit 1
  fi
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "inject_secrets: missing env: ${missing[*]}" >&2
  exit 1
fi

# Escape for use in the replacement part of sed s|||: backslash, ampersand, delimiter.
escape_sed() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cp "$PRESETS" "$tmp"
for name in "${VARS[@]}"; do
  esc="$(escape_sed "${!name}")"
  # Portable (GNU + BSD sed): write to a new file instead of using -i.
  sed "s|__${name}__|${esc}|g" "$tmp" > "$tmp.new"
  mv "$tmp.new" "$tmp"
done

# Every placeholder of this platform must be gone.
for name in "${VARS[@]}"; do
  if grep -q "__${name}__" "$tmp"; then
    echo "inject_secrets: placeholder __${name}__ still present" >&2
    exit 1
  fi
done

cat "$tmp" > "$PRESETS"
echo "inject_secrets: injected ${#VARS[@]} value(s) for $1 into $(basename "$PRESETS")"
