#!/usr/bin/env bash
# Stop hook: nie pozwala zakończyć sesji, gdy została niedokończona praca:
#   (a) lokalna gałąź task/* ma commity wobec main, ale nie ma dla niej PR (ani otwartego, ani zmergowanego),
#   (b) BACKLOG.md ma zadanie `in_progress` bez `→ PR`.
# Blokada = JSON {"decision":"block","reason":"..."} na stdout + exit 0.
# Licznik w /tmp (per sesja) ogranicza blokady do MAX_BLOCKS, żeby nie zapętlić sesji.
set -euo pipefail

MAX_BLOCKS=2
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
print("" if d is None else str(d).lower() if isinstance(d, bool) else d)' "$1" 2>/dev/null || true
  fi
}

SID="$(json_get session_id | tr -c 'A-Za-z0-9_-' '_')"
[ -n "$SID" ] || SID="nosession"
COUNTER="${TMPDIR:-/tmp}/claude_stop_guard_${SID}"
COUNT=0
[ -f "$COUNTER" ] && COUNT="$(cat "$COUNTER" 2>/dev/null || echo 0)"
case "$COUNT" in ''|*[!0-9]*) COUNT=0 ;; esac
[ "$COUNT" -ge "$MAX_BLOCKS" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-$PWD}"

with_timeout() { # timeout nie istnieje domyślnie na macOS
  if command -v timeout >/dev/null 2>&1; then timeout 20 "$@"; else "$@"; fi
}

PROBLEMS=""

# (a) gałęzie task/* bez PR
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  BASE=""
  for cand in origin/main main; do
    if git rev-parse --verify -q "$cand" >/dev/null 2>&1; then BASE="$cand"; break; fi
  done
  if [ -n "$BASE" ]; then
    for br in $(git for-each-ref --format='%(refname:short)' 'refs/heads/task/*' 2>/dev/null); do
      ahead="$(git rev-list --count "$BASE..$br" 2>/dev/null || echo 0)"
      [ "$ahead" -gt 0 ] || continue
      has_pr=""
      if command -v gh >/dev/null 2>&1; then
        has_pr="$(with_timeout gh pr list --head "$br" --state all --json number --jq 'length' 2>/dev/null || true)"
      fi
      if [ -n "$has_pr" ]; then
        [ "$has_pr" -gt 0 ] 2>/dev/null && continue
        PROBLEMS="${PROBLEMS}- Gałąź ${br} ma ${ahead} commit(y) wobec ${BASE}, ale NIE MA dla niej PR.\n"
      elif ! git rev-parse --verify -q "origin/$br" >/dev/null 2>&1; then
        # gh niedostępne: brak gałęzi na origin = na pewno nie ma PR
        PROBLEMS="${PROBLEMS}- Gałąź ${br} ma ${ahead} commit(y) wobec ${BASE} i nie została wypchnięta (brak PR).\n"
      fi
    done
  fi
fi

# (b) BACKLOG.md: in_progress bez `→ PR`
if [ -f BACKLOG.md ]; then
  STUCK="$(awk '
    function flush() { if (inblock && !haspr) print id; inblock = 0 }
    /^- \[.\] / { flush(); if ($0 ~ /`in_progress`/) { inblock = 1; haspr = ($0 ~ /→ PR/); match($0, /[A-Z]+-[0-9]+/); id = substr($0, RSTART, RLENGTH) } next }
    /^## /      { flush(); next }
    inblock && /→ PR/ { haspr = 1 }
    END { flush() }
  ' BACKLOG.md 2>/dev/null || true)"
  for id in $STUCK; do
    PROBLEMS="${PROBLEMS}- BACKLOG.md: zadanie ${id} ma status in_progress bez '→ PR #N'.\n"
  done
fi

[ -n "$PROBLEMS" ] || exit 0

COUNT=$((COUNT + 1))
echo "$COUNT" >"$COUNTER" 2>/dev/null || true

REASON="Niedokończona praca (blokada ${COUNT}/${MAX_BLOCKS}):\n${PROBLEMS}Dokończ pętlę z CLAUDE.md: uruchom 'make check' (musi być zielone), 'gh pr create --fill --label bot', 'gh pr merge --auto --squash', zmień status zadania w BACKLOG.md na 'review' z '→ PR #N' i dopisz wpis do docs/LOG.md. Jeśli zadania nie da się dokończyć: ustaw je na 'blocked', opisz powód w '## Pytania do Huberta' i skończ."

if command -v jq >/dev/null 2>&1; then
  printf '%b' "$REASON" | jq -Rs '{decision: "block", reason: .}'
else
  printf '%b' "$REASON" | python3 -c 'import json,sys; print(json.dumps({"decision":"block","reason":sys.stdin.read()}))'
fi
exit 0
