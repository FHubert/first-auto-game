"""Straznik spojnosci paczek eksperymentow (T-319): docs/EXPERIMENTS.md <-> docs/remote_config/*.json <-> GameConfig."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = (ROOT / "docs" / "EXPERIMENTS.md").read_text(encoding="utf-8")
CFG = (ROOT / "game" / "src" / "systems" / "config.gd").read_text(encoding="utf-8")
VAR = "remote_config_variant"


def packages():
    return {p.stem: json.loads(p.read_text(encoding="utf-8")) for p in sorted((ROOT / "docs" / "remote_config").glob("*.json"))}


def defaults_keys():
    body = re.search(r"const DEFAULTS: Dictionary = \{(.*?)\n\}", CFG, re.S).group(1)
    return set(re.findall(r'^\t"([a-z0-9_]+)":', body, re.M))


def sections():
    return {m.group(1): m.group(2) for m in re.finditer(r"^## (EXP-\d+):.*?\n(.*?)(?=^## |\Z)", DOC, re.M | re.S)}


def exp_package(body):
    lines = re.findall(r"^- Paczka: (.+)$", body, re.M)
    return lines[0].strip() if len(lines) == 1 else None


def keys_of(pkg):
    return {k for k in pkg if k != VAR}


def pairs():
    rows = re.findall(r"^\|\s*(EXP-\d+)\s*\|\s*(EXP-\d+)\s*\|\s*(tak|nie)\b[^|]*\|\s*$", DOC, re.M)
    return [(a, b, v) for a, b, v in rows]


class ExperimentGuard(unittest.TestCase):
    def test_every_exp_has_one_package_line(self):
        pk, secs, used = packages(), sections(), []
        self.assertGreaterEqual(len(secs), 5)
        for exp, body in secs.items():
            line = exp_package(body)
            self.assertIsNotNone(line, f"{exp}: need exactly one '- Paczka:' line")
            if line.startswith("brak"):
                self.assertRegex(line, r"^brak\s+[—-]\s+\S", f"{exp}: 'brak' needs a reason")
                continue
            m = re.fullmatch(r"([a-z0-9_]+)\.json", line)
            self.assertIsNotNone(m, f"{exp}: bad package line '{line}'")
            self.assertIn(m.group(1), pk, f"{exp}: missing file {line}")
            used.append(m.group(1))
        self.assertEqual(len(used), len(set(used)), "package assigned to two EXPs")
        self.assertEqual(set(pk) - {"default"}, set(used), "package without EXP (or default assigned)")

    def test_package_variant_and_keys(self):
        dk = defaults_keys()
        self.assertIn(VAR, dk)
        for name, pkg in packages().items():
            self.assertEqual(pkg.get(VAR), name, f"{name}.json: variant != file name")
            self.assertRegex(name, r"^[a-z0-9_]{1,24}$")
            for k in keys_of(pkg):
                self.assertIn(k, dk, f"{name}.json: key {k} not in DEFAULTS")

    def test_parallel_pairs_have_disjoint_keys(self):
        pk, secs = packages(), sections()
        rows = pairs()
        self.assertTrue(rows, "no '## Równolegle' table rows")
        for a, b, verdict in rows:
            self.assertIn(a, secs)
            self.assertIn(b, secs)
            if verdict != "tak":
                continue
            ka = keys_of(pk[exp_package(secs[a])[:-5]])
            kb = keys_of(pk[exp_package(secs[b])[:-5]])
            self.assertFalse(ka & kb, f"{a} || {b} share keys {ka & kb}")

    def test_exp004_exp005_not_parallel(self):
        found = [v for a, b, v in pairs() if {a, b} == {"EXP-004", "EXP-005"}]
        self.assertEqual(found, ["nie"])

    def test_parametr_line_matches_package_keys(self):
        pk = packages()
        for exp, body in sections().items():
            line = exp_package(body)
            if line.startswith("brak"):
                continue
            name = line[:-5]
            param = re.search(r"^- Parametr[^\n]*", body, re.M)
            self.assertIsNotNone(param, f"{exp}: no '- Parametr' line")
            tokens = set(re.findall(r"`([a-z0-9_]+)`", param.group(0))) - set(pk)
            self.assertEqual(tokens, keys_of(pk[name]), f"{exp}: Parametr keys != package keys")


if __name__ == "__main__":
    unittest.main()
