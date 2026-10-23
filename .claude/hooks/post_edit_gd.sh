#!/usr/bin/env bash
# PostToolUse(Edit|Write) hook: formatuje edytowane pliki *.gd przez gdformat (jeśli dostępny).
# Nigdy nie failuje — formatowanie to wygoda, nie bramka (bramką jest `make lint`).
set -euo pipefail

INPUT="$(cat || true)"

json_get() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r ".$1 // empty" 2>/dev/null || true
  else
    printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = None
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$1" 2>/dev/null || true
  fi
}

FILE="$(json_get tool_input.file_path)"

case "$FILE" in
  *.gd) ;;
  *) exit 0 ;;
esac
case "$FILE" in
  */addons/*) exit 0 ;; # kod zewnętrzny (gdUnit4 itd.) — nie formatujemy
esac
[ -f "$FILE" ] || exit 0

if command -v gdformat >/dev/null 2>&1; then
  gdformat "$FILE" >/dev/null 2>&1 || echo "[post_edit_gd] gdformat nie sformatował $FILE (błąd składni?) — sprawdź 'make lint'" >&2
fi
exit 0
