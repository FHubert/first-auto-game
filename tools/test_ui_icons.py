"""T-229: UI v2 icon generator tests."""
import hashlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
NAMES = (
    "pause undo restart hint add_tube coin streak calendar palette bag gear play video close back "
    "arrow_right check skip music speaker vibration symbols globe shield bell chevron_right "
    "clock coins_stack video_off undo_clock star"
).split()


def generate(out: Path) -> None:
    r = subprocess.run(
        [sys.executable, TOOLS / "gen_assets.py", "--out", out, "--themes-out", out / "themes.json"],
        capture_output=True, text=True,
    )
    assert r.returncode == 0, r.stderr


def digests(out: Path) -> dict:
    return {n: hashlib.sha256((out / "ui" / "v2" / f"{n}.png").read_bytes()).hexdigest() for n in NAMES}


class UiIconsTest(unittest.TestCase):
    def test_complete_deterministic_rgba(self):
        from PIL import Image

        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            generate(Path(a))
            generate(Path(b))
            self.assertEqual(sorted(p.stem for p in (Path(a) / "ui" / "v2").glob("*.png")), sorted(NAMES))
            self.assertEqual(digests(Path(a)), digests(Path(b)))
            for n in NAMES:
                im = Image.open(Path(a) / "ui" / "v2" / f"{n}.png")
                self.assertEqual((im.size, im.mode), ((96, 96), "RGBA"), n)
                lo, hi = im.getchannel("A").getextrema()
                self.assertEqual((lo, hi), (0, 255), n)

    def test_filled_icons_colors(self):
        from PIL import Image

        def near(path, rgb):
            px = Image.open(path).convert("RGBA").get_flattened_data()
            return any(p[3] == 255 and all(abs(p[i] - rgb[i]) < 12 for i in range(3)) for p in px)

        with tempfile.TemporaryDirectory() as a:
            generate(Path(a))
            self.assertTrue(near(Path(a) / "ui" / "v2" / "coin.png", (0xFF, 0xD1, 0x66)))
            self.assertTrue(near(Path(a) / "ui" / "v2" / "streak.png", (0xFB, 0x85, 0x00)))


if __name__ == "__main__":
    unittest.main()
