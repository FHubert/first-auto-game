#!/usr/bin/env bash
# Shared monotonic version_code for build-android.yml, build-ios.yml and release.yml.
# Prints minutes elapsed since 2026-01-01T00:00:00Z (floor).
# Why minutes: monotonic across workflows (github.run_number is per workflow file, so it
# cannot be shared); Google Play caps versionCode at 2100000000 (minutes give headroom to
# ~year 6000); iOS CFBundleVersion accepts an integer. Pure arithmetic on unix seconds -
# no `date -d`, because macOS (build-ios.yml) lacks GNU date.
# SOURCE_DATE_EPOCH (unix seconds) overrides "now" for tests and reproducibility.
# Usage: version_code.sh            -> prints code
#        version_code.sh --check N  -> exit 0 if N is an int in 1..2099999999, else exit 2
set -euo pipefail

readonly EPOCH=1767225600 # 2026-01-01T00:00:00Z
readonly LIMIT=2100000000

if [ "${1:-}" = "--check" ]; then
  code="${2:-}"
  if [[ "$code" =~ ^[0-9]+$ ]] && [ "${#code}" -le 10 ] && [ "$((10#$code))" -gt 0 ] && [ "$((10#$code))" -lt "$LIMIT" ]; then
    exit 0
  fi
  echo "version_code '$code' must be a positive integer < $LIMIT" >&2
  exit 2
fi

now="${SOURCE_DATE_EPOCH:-$(date -u +%s)}"
code=$(((now - EPOCH) / 60))
if [ "$now" -lt "$EPOCH" ] || [ "$code" -le 0 ]; then
  echo "clock is before the 2026-01-01 epoch (now=$now); refusing to emit version_code" >&2
  exit 1
fi
echo "$code"
