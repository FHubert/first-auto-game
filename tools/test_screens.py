"""Static checks for the screenshot lists (no Godot): scenes exist, fixtures known, out dir per size."""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURES_GD = ROOT / "game" / "src" / "core" / "screenshot_fixtures.gd"
LISTS = [ROOT / "tools" / "screens.txt", ROOT / "tools" / "screens_store.txt"]
SCRIPT = ROOT / "tools" / "gen_screenshots.sh"


def known_fixtures() -> set:
    text = FIXTURES_GD.read_text(encoding="utf-8")
    body = text.split("match fixture:", 1)[1]
    names = {"default"}
    for arm in re.findall(r'^\t\t((?:"[^"]+"(?:,\s*)?)+):', body, re.M):
        names.update(re.findall(r'"([^"]+)"', arm))
    return names


def entries():
    for path in LISTS:
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.strip() and not line.startswith("#"):
                yield path, no, line


def dry_run(*args: str) -> str:
    res = subprocess.run(
        ["bash", str(SCRIPT), "--dry-run", *args], capture_output=True, text=True, check=True
    )
    return res.stdout


def out_dir(output: str) -> str:
    return re.search(r"^OUT_DIR=(.+)$", output, re.M).group(1)


class ScreenListTest(unittest.TestCase):
    def test_scenes_and_fixtures_exist(self) -> None:
        fixtures = known_fixtures()
        self.assertIn("aso_level", fixtures)
        for path, no, line in entries():
            parts = line.split("|")
            scene = parts[0]
            fixture = parts[1] if len(parts) > 1 else "default"
            where = f"{path.name}:{no}: {line}"
            self.assertTrue(scene.startswith("res://"), where)
            self.assertTrue((ROOT / "game" / scene[len("res://"):]).is_file(), where)
            self.assertIn(fixture, fixtures, where)

    def test_output_dir_per_size(self) -> None:
        default = out_dir(dry_run())
        small = out_dir(dry_run("--size", "720x1560"))
        self.assertTrue(small.endswith("720x1560"), small)
        self.assertNotEqual(default, small)

    def test_dry_run_lists_all_smoke_entries(self) -> None:
        smoke = [line for path, _, line in entries() if path.name == "screens.txt"]
        listed = [l for l in dry_run().splitlines() if l.startswith("ENTRY ")]
        self.assertEqual(len(listed), len(smoke))


if __name__ == "__main__":
    unittest.main()
