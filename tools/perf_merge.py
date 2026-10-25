"""T-241: scala raporty measure_startup/hint/prefetch w game/test/reports/perf.json (exit != 0 przy braku/bledzie)."""
import argparse
import json
import sys
from pathlib import Path

STARTUP_MAP = {"first_run": "a", "resume_prefetch": "b2", "resume_no_prefetch": "b3", "daily": "c"}
BRACKETS = ("8-25", "26-55", "56+", "daily")
TOP_KEYS = ("commit", "godot_version", "startup", "hint", "prefetch", "moves_stuck", "moves_midround")


def merge(startup: dict, hint: dict, prefetch: dict, commit: str, godot_version: str) -> dict:
    summary = hint["summary"]
    return {
        "commit": commit,
        "godot_version": godot_version,
        "startup": {k: startup[v] for k, v in STARTUP_MAP.items()},
        "hint": {
            b: {
                part: dict(zip(("med", "p95", "max"), summary[b][src]))
                for part, src in (("main_thread", "main_ms"), ("worker", "worker_ms"))
            }
            for b in BRACKETS
        },
        "prefetch": prefetch,
        # T-253: moves_gate liczony na stanach utkniecia (to wola gra); midround = sciezka niewolana.
        "moves_stuck": {b: _stat3(summary[b]["moves_stuck_ms"], n=summary[b]["stuck_n"], gate=summary[b]["moves_gate"]) for b in BRACKETS},
        "moves_midround": {
            **{b: _stat3(summary[b]["moves_midround_ms"]) for b in BRACKETS},
            "note": "sciezka niewolana w grze (bez bramki)",
        },
    }


def _stat3(stat, **extra) -> dict:
    return {**dict(zip(("med", "p95", "max"), stat)), **extra}


def _numbers(node, path=""):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from _numbers(v, f"{path}/{k}")
    elif isinstance(node, (int, float)) and not isinstance(node, bool):
        yield path, node
    elif not isinstance(node, str):
        raise ValueError(f"unexpected value at {path}: {node!r}")


def validate(report: dict) -> None:
    """Rzuca ValueError, gdy brak kluczy lub liczba < 0."""
    for key in TOP_KEYS:
        if key not in report:
            raise ValueError(f"missing key: {key}")
    for key in STARTUP_MAP:
        if not {"med_ms", "p95_ms"} <= set(report["startup"].get(key, {})):
            raise ValueError(f"startup.{key} needs med_ms, p95_ms")
    for b in BRACKETS:
        for part in ("main_thread", "worker"):
            if not {"med", "p95", "max"} <= set(report["hint"].get(b, {}).get(part, {})):
                raise ValueError(f"hint.{b}.{part} needs med, p95, max")
    for key in ("moves_stuck", "moves_midround"):
        for b in BRACKETS:
            if not {"med", "p95", "max"} <= set(report[key].get(b, {})):
                raise ValueError(f"{key}.{b} needs med, p95, max")
    if not report["prefetch"]:
        raise ValueError("prefetch is empty")
    for path, value in _numbers({k: v for k, v in report.items() if k not in ("commit", "godot_version")}):
        if value < 0:
            raise ValueError(f"negative number at {path}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    for name in ("startup", "hint", "prefetch", "out", "commit", "godot-version"):
        ap.add_argument(f"--{name}", required=True)
    a = ap.parse_args(argv)
    try:
        src = [json.loads(Path(p).read_text(encoding="utf-8")) for p in (a.startup, a.hint, a.prefetch)]
        report = merge(*src, a.commit, a.godot_version)
        validate(report)
    except (OSError, ValueError, KeyError) as e:
        print(f"perf_merge: {e!r}", file=sys.stderr)
        return 1
    Path(a.out).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
