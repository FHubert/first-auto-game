"""T-253: straznik wolajacych solvera na watku glownym (ADR-014). Sprawdzenie tekstowe game/src/**."""
import re
import unittest
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "game" / "src"

# (plik, funkcja) -> dlaczego wolno wolac moves_to_goal() (tylko przy braku legalnych ruchow).
MOVES_ALLOWED = {
    ("ui/stuck_panel.gd", "show_for"): "wolane tylko z _check_stuck (po is_stuck()) i ze screenshotu",
}
# (plik, funkcja) -> dlaczego wolno wolac StuckPanel.show_for( (posrednio moves_to_goal).
SHOW_FOR_ALLOWED = {
    ("levels/level.gd", "_check_stuck"): "wola po is_stuck()",
    ("core/main.gd", "_show_screenshot_screen"): "sciezka --screenshot: jednorazowo, stan startowy, poza gra",
}
# plik -> funkcja: dlaczego wolno wolac SortSolver.solve( (inaczej: solver na watku glownym).
SOLVE_ALLOWED = {
    "systems/content_generator.gd": "generator: watek prefetchu / Poziom dnia, nie klatka gry",
    "systems/hint_job.gd": "worker podpowiedzi (WorkerThreadPool, ADR-014)",
    "core/game_round.gd": "_solve_cached: hint()/moves_to_goal() - ta ostatnia tylko po is_stuck()",
    "levels/level.gd": "_solver_first_move: tutorial, poziom 1, 2 kolory (maly stan)",
}
DEF_RE = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)\(")


def calls(needle):
    """Yield (rel_path, func_name, line_no, text) dla kazdej linii z needle (bez komentarzy)."""
    for path in sorted(SRC.rglob("*.gd")):
        func = ""
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            m = DEF_RE.match(line)
            if m:
                func = m.group(1)
            code = line.split("#", 1)[0]
            if needle in code and not DEF_RE.match(line):
                yield path.relative_to(SRC).as_posix(), func, no, code


class SolverCallersTest(unittest.TestCase):
    def test_moves_to_goal_only_from_allowed_stuck_paths(self):
        found = list(calls("moves_to_goal("))
        self.assertTrue(found, "no moves_to_goal( callers found - guard is blind")
        for rel, func, no, _ in found:
            self.assertIn((rel, func), MOVES_ALLOWED, f"{rel}:{no} {func}: moves_to_goal poza lista - solver na watku glownym, ADR-014")
        for rel, func, no, _ in calls("stuck_panel.show_for("):
            self.assertIn((rel, func), SHOW_FOR_ALLOWED, f"{rel}:{no} {func}: show_for poza lista - solver na watku glownym, ADR-014")
        text = (SRC / "levels/level.gd").read_text(encoding="utf-8")
        fn = re.search(r"^func _check_stuck\(.*?(?=^func |\Z)", text, re.S | re.M).group(0)
        self.assertNotIn("moves_to_goal(", fn, "T-254: _check_stuck nie liczy solverem (panel robi to sam)")
        self.assertLess(fn.index("is_stuck()"), fn.index("show_for("), "show_for przed is_stuck()")

    def test_solver_solve_only_from_allowed_files(self):
        found = list(calls("SortSolver.solve("))
        self.assertTrue(found)
        for rel, func, no, _ in found:
            self.assertIn(rel, SOLVE_ALLOWED, f"{rel}:{no} {func}: solver na watku glownym — ADR-014")

    def test_allowlists_are_documented_and_current(self):
        for (rel, func), why in {**MOVES_ALLOWED, **SHOW_FOR_ALLOWED}.items():
            self.assertTrue(why)
            self.assertIn(f"func {func}(", (SRC / rel).read_text(encoding="utf-8"), f"{rel}:{func} nie istnieje")


if __name__ == "__main__":
    unittest.main()
