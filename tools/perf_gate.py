#!/usr/bin/env python3
"""T-260: bramka progow wydajnosci na game/test/reports/perf.json (po tools/perf_merge.py).

Uzycie: python3 tools/perf_gate.py --perf game/test/reports/perf.json
Exit: 0 = wszystkie progi spelnione, 1 = naruszenie lub brakujacy klucz, 2 = brak pliku.
"""
import argparse
import json
import sys
from pathlib import Path

BRACKETS = ("8-25", "26-55", "56+", "daily")
STARTUP = ("first_run", "resume_prefetch", "resume_no_prefetch", "daily")
# Prefetch (T-260): `prefetched_us` to czas take() gotowego wyniku na watku glownym. Zmierzone
# (make perf, CI x86): 66-72 us (poziomy 2/26/50/120); prog = 2x zmierzony max (0,144 ms)
# zaokraglone w gore do pelnych 50 ms = 50 ms. Wynik sync (2-62 ms) nie jest bramkowany.
PREFETCH_LEVELS = ("2", "26", "50", "120")
PREFETCH_LIMIT_MS = 50.0

# (sciezka kluczy w JSON, limit w ms, odwolanie do zadania)
THRESHOLDS: list[tuple[tuple[str, ...], float, str]] = (
    [(("hint", b, "worker", "p95"), 500.0, "T-237") for b in BRACKETS]
    + [(("hint", b, "worker", "max"), 1000.0, "T-237") for b in BRACKETS]
    + [(("hint", b, "main_thread", "p95"), 100.0, "T-210/T-222") for b in BRACKETS]
    + [(("moves_stuck", b, "p95"), 100.0, "T-253") for b in BRACKETS]
    + [(("moves_stuck", b, "max"), 500.0, "T-253") for b in BRACKETS]
    + [(("startup", s, "p95_ms"), 100.0, "T-145") for s in STARTUP]
    + [(("prefetch", lv, "prefetched_us"), PREFETCH_LIMIT_MS, "T-260") for lv in PREFETCH_LEVELS]
)


def lookup(perf: dict, path: tuple[str, ...]):
    """Zwroc wartosc w ms (klucze `*_us` przeliczone) albo None, gdy brak klucza / nie liczba."""
    node = perf
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    if isinstance(node, bool) or not isinstance(node, (int, float)):
        return None
    return node / 1000.0 if path[-1].endswith("_us") else float(node)


def check(perf: dict) -> list[tuple[str, str, str]]:
    """Lista (sciezka, status PASS/FAIL, komunikat) dla kazdego progu."""
    rows = []
    for path, limit, task in THRESHOLDS:
        name = ".".join(path)
        value = lookup(perf, path)
        if value is None:
            rows.append((name, "FAIL", f"{name}: brak klucza ({task})"))
        elif value > limit:
            rows.append((name, "FAIL", f"{name}: {value:g} ms > {limit:g} ms ({task})"))
        else:
            rows.append((name, "PASS", f"{name}: {value:g} ms <= {limit:g} ms ({task})"))
    return rows


def violations(perf: dict) -> list[str]:
    return [msg for _, status, msg in check(perf) if status == "FAIL"]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--perf", required=True)
    a = ap.parse_args(argv)
    try:
        perf = json.loads(Path(a.perf).read_text(encoding="utf-8"))
    except OSError as e:
        print(f"perf gate: brak pliku {a.perf} ({e})", file=sys.stderr)
        return 2
    except ValueError as e:
        print(f"perf gate: niepoprawny JSON ({e})", file=sys.stderr)
        return 1
    rows = check(perf)
    for _, status, msg in rows:
        print(f"{status} {msg}")
    bad = [r for r in rows if r[1] == "FAIL"]
    if bad:
        print(f"perf gate: {len(bad)} naruszen")
        return 1
    print(f"perf gate: OK ({len(rows)} progow)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
