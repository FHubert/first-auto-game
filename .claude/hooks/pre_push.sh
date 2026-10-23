#!/usr/bin/env bash
# PreToolUse(Bash) hook: blokuje `git push`, dopóki `make check` nie jest zielone.
# Wejście: JSON hooka na stdin (tool_input.command). Wyjście: exit 0 = przepuść, exit 2 = zablokuj
# (stderr trafia do Claude jako komunikat blokady).
# settings.json filtruje wywołanie polem "if": "Bash(git push *)", ale skrypt sam też sprawdza komendę.
set -euo pipefail

INPUT="$(cat || true)"

json_get() { # $1 = ścieżka z kropkami, np. tool_input.command
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

CMD="$(json_get tool_input.command)"
case "$CMD" in
  *"git push"*|*"git -C"*push*) ;;
  *) exit 0 ;; # to nie push (np. `if` nie zadziałał) — nic nie robimy
esac

cd "${CLAUDE_PROJECT_DIR:-$PWD}"
LOG="$(mktemp "${TMPDIR:-/tmp}/pre_push_check.XXXXXX")"
trap 'rm -f "$LOG"' EXIT

echo "[pre_push] uruchamiam make check..." >&2
if make check >"$LOG" 2>&1; then
  echo "[pre_push] make check zielone — push dozwolony." >&2
  exit 0
fi

{
  echo "ZABLOKOWANO git push: 'make check' jest czerwone."
  echo "Napraw błędy (nie osłabiaj testów), uruchom 'make check' do zielonego i dopiero wtedy ponów push."
  echo "Jeśli brakuje narzędzi (godot/gdlint), uruchom najpierw 'make setup'."
  echo "--- ostatnie 40 linii wyjścia ---"
  tail -n 40 "$LOG"
} >&2
exit 2
