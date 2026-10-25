#!/usr/bin/env python3
"""T-255: budzet sygnatur ERROR w logu `make test`.

Uzycie: python3 tools/log_budget.py <plik_logu> [--allow tools/log_budget_allow.txt]
T-297: dodatkowo tabela top-20 sygnatur WARNING: -> log_warnings.txt obok logu (bez wplywu na exit).
Exit: 0 = wszystkie sygnatury na allowliscie, 1 = jest nowa sygnatura, 2 = brak pliku logu.
"""
import re
import sys
from pathlib import Path

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
DIGITS_RE = re.compile(r"\d+")
PREFIXES = ("ERROR:", "SCRIPT ERROR:")
WARN_PREFIX = "WARNING:"
WARN_TOP = 20
DEFAULT_ALLOW = Path(__file__).resolve().parent / "log_budget_allow.txt"


def normalize(line):
    """Zdejmij ANSI, zamien ciagi cyfr na N, obetnij biale znaki na koncach."""
    return DIGITS_RE.sub("N", ANSI_RE.sub("", line)).rstrip()


def collect(lines):
    """Zwroc {sygnatura: liczba} dla linii zaczynajacych sie od ERROR: / SCRIPT ERROR:."""
    counts = {}
    for raw in lines:
        clean = ANSI_RE.sub("", raw).strip()
        if clean.startswith(PREFIXES):
            sig = normalize(clean)
            counts[sig] = counts.get(sig, 0) + 1
    return counts


def collect_warnings(lines):
    """Zwroc {sygnatura: liczba} dla linii zaczynajacych sie od WARNING: (raport, bez bramki)."""
    counts = {}
    for raw in lines:
        clean = ANSI_RE.sub("", raw).strip()
        if clean.startswith(WARN_PREFIX):
            sig = normalize(clean)
            counts[sig] = counts.get(sig, 0) + 1
    return counts


def write_warnings(counts, path):
    """Zapisz top-20 sygnatur malejaco (remis: alfabetycznie) jako `%5dx  sygnatura`."""
    top = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:WARN_TOP]
    Path(path).write_text("".join("%5dx  %s\n" % (n, sig) for sig, n in top), encoding="utf-8")


def load_allow(path):
    """Wpisy `fragment | powod | test`; zwraca liste fragmentow. Puste linie i `#` ignorowane."""
    fragments = []
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split(" | ")]
        if len(parts) != 3 or not parts[0]:
            raise ValueError("zly wpis allowlisty (fragment | powod | test): %r" % raw)
        fragments.append(parts[0])
    return fragments


def is_allowed(sig, allow):
    return any(fragment in sig for fragment in allow)


def check(counts, allow):
    """Lista sygnatur spoza allowlisty (posortowana)."""
    return sorted(sig for sig in counts if not is_allowed(sig, allow))


def main(argv):
    args = list(argv)
    allow_path = DEFAULT_ALLOW
    if "--allow" in args:
        i = args.index("--allow")
        if i + 1 >= len(args):
            print("log budget: --allow wymaga sciezki", file=sys.stderr)
            return 2
        allow_path = Path(args[i + 1])
        del args[i : i + 2]
    if len(args) != 1:
        print("uzycie: log_budget.py <plik_logu> [--allow plik]", file=sys.stderr)
        return 2
    log_path = Path(args[0])
    if not log_path.is_file():
        print("log budget: brak pliku logu: %s" % log_path, file=sys.stderr)
        return 2
    if not Path(allow_path).is_file():
        print("log budget: brak pliku allowlisty: %s" % allow_path, file=sys.stderr)
        return 2
    allow = load_allow(allow_path)
    lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    counts = collect(lines)
    warns = collect_warnings(lines)
    warn_path = log_path.parent / "log_warnings.txt"
    write_warnings(warns, warn_path)
    print("log budget: %d WARNING signatures (%d lines) -> %s" % (len(warns), sum(warns.values()), warn_path))
    new = check(counts, allow)
    for sig in sorted(counts):
        status = "NEW" if sig in new else "allowed"
        print("%-7s %3dx  %s" % (status, counts[sig], sig))
    if new:
        print("log budget: %d new ERROR signature(s)" % len(new))
        return 1
    print("log budget: OK (%d signatures, all allowed)" % len(counts))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
