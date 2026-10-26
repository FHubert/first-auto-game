"""T-260: testy bramki progow wydajnosci (tools/perf_gate.py)."""
import contextlib
import copy
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import perf_gate  # noqa: E402

REAL_PERF = Path(__file__).resolve().parent.parent / "game" / "test" / "reports" / "perf.json"


def sample() -> dict:
    tri = {"med": 1.0, "p95": 2.0, "max": 3.0}
    return {
        "startup": {s: {"med_ms": 10.0, "p95_ms": 20.0} for s in perf_gate.STARTUP},
        "hint": {b: {"main_thread": dict(tri), "worker": dict(tri)} for b in perf_gate.BRACKETS},
        "prefetch": {lv: {"prefetched_us": 70, "sync_us": 5000} for lv in perf_gate.PREFETCH_LEVELS},
        "moves_stuck": {b: dict(tri, n=3, gate="OK") for b in perf_gate.BRACKETS},
    }


class PerfGateTest(unittest.TestCase):
    def test_pass(self):
        self.assertEqual(perf_gate.violations(sample()), [])

    def test_worker_p95_501_fails_with_path(self):
        perf = sample()
        perf["hint"]["26-55"]["worker"]["p95"] = 501
        out = perf_gate.violations(perf)
        self.assertEqual(len(out), 1)
        self.assertIn("hint.26-55.worker.p95", out[0])
        self.assertIn("501", out[0])

    def test_missing_key_fails_with_name(self):
        perf = sample()
        del perf["startup"]["daily"]["p95_ms"]
        out = perf_gate.violations(perf)
        self.assertEqual(len(out), 1)
        self.assertIn("startup.daily.p95_ms", out[0])

    def test_prefetch_us_converted_to_ms(self):
        perf = sample()
        perf["prefetch"]["2"]["prefetched_us"] = 60000
        self.assertIn("prefetch.2.prefetched_us", perf_gate.violations(perf)[0])

    @staticmethod
    def _main_quiet(argv):
        """T-312: wywolaj main() z przechwyceniem stdout/stderr (czysty log make test-tools)."""
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = perf_gate.main(argv)
        return code, out.getvalue()

    def test_main_exit_codes(self):
        with tempfile.TemporaryDirectory() as d:
            ok, bad = Path(d, "ok.json"), Path(d, "bad.json")
            ok.write_text(json.dumps(sample()))
            worse = copy.deepcopy(sample())
            worse["moves_stuck"]["56+"]["max"] = 501
            bad.write_text(json.dumps(worse))
            self.assertEqual(self._main_quiet(["--perf", str(ok)])[0], 0)
            code, text = self._main_quiet(["--perf", str(bad)])
            self.assertEqual(code, 1)
            self.assertIn("perf gate:", text)
            code, text = self._main_quiet(["--perf", str(Path(d, "none.json"))])
            self.assertEqual(code, 2)
            self.assertIn("none.json", text)

    def test_real_perf_json(self):
        if not REAL_PERF.exists():
            self.skipTest("brak game/test/reports/perf.json (make perf)")
        self.assertEqual(perf_gate.violations(json.loads(REAL_PERF.read_text(encoding="utf-8"))), [])


if __name__ == "__main__":
    unittest.main()
