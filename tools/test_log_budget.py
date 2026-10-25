"""T-255: testy tools/log_budget.py (budzet sygnatur ERROR w logu make test)."""
import contextlib
import io
import tempfile
import unittest
from pathlib import Path

import log_budget

ALLOW_TEXT = (
    "# komentarz\n\n"
    "SaveSystem: cannot open | celowo | test_save_system.gd > x\n"
    "N resources still in use at exit | silnik | -\n"
)


def run_main(log_text, allow_text=ALLOW_TEXT, log_exists=True):
    """Zwroca (kod, stdout, stderr) dla main() na plikach tymczasowych."""
    with tempfile.TemporaryDirectory() as tmp:
        log = Path(tmp) / "test_output.log"
        allow = Path(tmp) / "allow.txt"
        allow.write_text(allow_text, encoding="utf-8")
        if log_exists:
            log.write_text(log_text, encoding="utf-8")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = log_budget.main([str(log), "--allow", str(allow)])
    return code, out.getvalue(), err.getvalue()


class LogBudgetTest(unittest.TestCase):
    def test_allowed_signature_passes(self):
        code, out, _ = run_main("ok line\nERROR: SaveSystem: cannot open user://a_12 (err 3)\n")
        self.assertEqual(code, 0)
        self.assertIn("log budget: OK (1 signatures, all allowed)", out)

    def test_new_signature_fails_and_is_printed(self):
        code, out, _ = run_main("ERROR: xyz 12\nERROR: 2 resources still in use at exit\n")
        self.assertEqual(code, 1)
        self.assertIn("ERROR: xyz N", out)
        self.assertIn("log budget: 1 new ERROR signature(s)", out)

    def test_missing_log_file_fails_with_message(self):
        code, _, err = run_main("", log_exists=False)
        self.assertEqual(code, 2)
        self.assertIn("brak pliku logu", err)

    def test_normalize_strips_ansi_and_digits(self):
        self.assertEqual(log_budget.normalize("\x1b[31mERROR: a 12 b7  \x1b[0m"), "ERROR: a N bN")

    def test_script_error_is_counted(self):
        counts = log_budget.collect(["SCRIPT ERROR: Parse 5", "SCRIPT ERROR: Parse 9", "WARNING: x"])
        self.assertEqual(counts, {"SCRIPT ERROR: Parse N": 2})
        code, out, _ = run_main("SCRIPT ERROR: boom 1\n")
        self.assertEqual(code, 1)
        self.assertIn("SCRIPT ERROR: boom N", out)

    def test_ansi_prefixed_line_is_collected(self):
        counts = log_budget.collect(["\x1b[91mERROR: bad 3\x1b[0m"])
        self.assertEqual(counts, {"ERROR: bad N": 1})

    def test_warnings_counted_and_sorted_descending(self):
        lines = ["WARNING: a 1", "\x1b[33mWARNING: b 2\x1b[0m", "WARNING: b 7", "WARNING: b 9", "WARNING: a 4", "x"]
        counts = log_budget.collect_warnings(lines)
        self.assertEqual(counts, {"WARNING: a N": 2, "WARNING: b N": 3})
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "w.txt"
            log_budget.write_warnings(counts, out)
            self.assertEqual(out.read_text(encoding="utf-8").splitlines(), ["    3x  WARNING: b N", "    2x  WARNING: a N"])

    def test_only_warnings_exit_zero_and_summary(self):
        code, out, _ = run_main("WARNING: leak 3\nWARNING: leak 5\n")
        self.assertEqual(code, 0)
        self.assertIn("log budget: 1 WARNING signatures (2 lines) -> ", out)

    def test_repo_allowlist_parses(self):
        allow = log_budget.load_allow(log_budget.DEFAULT_ALLOW)
        self.assertEqual(len(allow), 3)


if __name__ == "__main__":
    unittest.main()
