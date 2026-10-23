"""Self-tests for the python/bash tools. Run: python3 -m unittest discover -s tools -p "test_*.py"."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent


def run(*args, env=None, **kw):
    return subprocess.run([sys.executable, *map(str, args)], capture_output=True, text=True, env=env, **kw)


class MetricsPullTest(unittest.TestCase):
    def test_dry_run_updates_kpi_copy_idempotently(self):
        with tempfile.TemporaryDirectory() as d:
            kpi = Path(d) / "KPI.md"
            shutil.copy(ROOT / "KPI.md", kpi)
            for _ in range(2):
                r = run(TOOLS / "metrics_pull.py", "--dry-run", "--kpi-path", kpi)
                self.assertEqual(r.returncode, 0, r.stderr)
            data = json.loads(r.stdout)
            rows = [l for l in kpi.read_text(encoding="utf-8").splitlines() if l.startswith(f"| {data['week']} |")]
            self.assertEqual(len(rows), 1, "same ISO week must not be duplicated")
            self.assertNotIn("_(brak danych", kpi.read_text(encoding="utf-8"))

    def test_csv_import(self):
        with tempfile.TemporaryDirectory() as d:
            csv_path, kpi = Path(d) / "ga.csv", Path(d) / "KPI.md"
            shutil.copy(ROOT / "KPI.md", kpi)
            csv_path.write_text(
                "date,dau,sessions,d1_retention,d7_retention,d30_retention,ad_impressions,"
                "rewarded_started,rewarded_completed,iap_buyers,iap_revenue_usd,crash_free\n"
                "2026-10-12,100,300,35,12,4,300,100,80,2,4.5,99.6\n"
                "2026-10-13,100,300,35,12,4,300,100,80,1,2.0,99.6\n",
                encoding="utf-8",
            )
            env = {k: v for k, v in os.environ.items() if not k.startswith("ADMOB_")}
            r = run(TOOLS / "metrics_pull.py", "--ga-csv", csv_path, "--week", "2026-W42", "--kpi-path", kpi, env=env)
            self.assertEqual(r.returncode, 0, r.stderr)
            out = json.loads(r.stdout)
            self.assertAlmostEqual(out["sessions_per_dau"], 3.0)
            self.assertAlmostEqual(out["rewarded_completion"], 0.8)
            self.assertAlmostEqual(out["d1"], 0.35)
            self.assertAlmostEqual(out["iap_conversion"], 0.015)


class BalanceSimTest(unittest.TestCase):
    def test_default_economy_is_healthy(self):
        r = run(TOOLS / "balance_sim.py", "--players", "200", "--days", "30", "--seed", "1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_starving_economy_fails(self):
        with tempfile.TemporaryDirectory() as d:
            cfg = Path(d) / "config.gd"
            cfg.write_text('const DEFAULTS: Dictionary = {\n\t"shop_base_price": 100000,\n}\n')
            r = run(TOOLS / "balance_sim.py", "--players", "100", "--days", "30", "--config", cfg)
            self.assertEqual(r.returncode, 1, r.stdout)
            self.assertIn("starves", r.stdout)


class GenAssetsTest(unittest.TestCase):
    def test_deterministic_svg(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            for out in (a, b):
                r = run(TOOLS / "gen_assets.py", "--out", out, "--themes-out", Path(out) / "themes.json")
                self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual((Path(a) / "themes.json").read_bytes(), (Path(b) / "themes.json").read_bytes())
            for p in Path(a).glob("*.svg"):
                self.assertEqual(p.read_bytes(), (Path(b) / p.name).read_bytes())
            self.assertEqual(len(list(Path(a).glob("*.svg"))), 7)

    def test_themes_have_12_unique_liquids_and_delta_e(self):
        self.assertEqual(run(TOOLS / "gen_assets.py", "--check-themes").returncode, 0)
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(run(TOOLS / "gen_assets.py", "--out", d, "--themes-out", Path(d) / "themes.json").returncode, 0)
            data = json.loads((Path(d) / "themes.json").read_text(encoding="utf-8"))
        self.assertEqual({"left": 24, "top": 48, "right": 24, "bottom": 48}, data["nine_slice"])
        self.assertEqual([t["id"] for t in data["themes"]], ["classic", "pastel", "neon", "ocean"])
        for t in data["themes"]:
            self.assertEqual(len(t["liquids"]), 12)
            self.assertEqual(len(set(t["liquids"])), 12, t["id"])
            for c in t["liquids"]:
                self.assertRegex(c, r"^#[0-9A-F]{6}$")
            self.assertIn(t["shape"], ("tube", "flask"))
        self.assertEqual(data["themes"][0]["liquids"][0], "#E63946")

    def test_icons_and_tubes_generated(self):
        from PIL import Image

        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(run(TOOLS / "gen_assets.py", "--out", d, "--themes-out", Path(d) / "themes.json").returncode, 0)
            p = Path(d)
            self.assertEqual(len(list((p / "ui").glob("icon_*.svg"))), 6)
            for n in ("tube_body", "flask_body", "tube_highlight"):
                self.assertEqual(Image.open(p / "tubes" / f"{n}.png").size, (128, 384))
            big = Image.open(p / "icon_1024.png")
            self.assertEqual((big.mode, big.size), ("RGB", (1024, 1024)))
            self.assertEqual(Image.open(p / "icon_512.png").size, (512, 512))


class ShellToolsTest(unittest.TestCase):
    def test_inject_and_set_version(self):
        with tempfile.TemporaryDirectory() as d:
            cfg, gd = Path(d) / "export_presets.cfg", Path(d) / "version.gd"
            cfg.write_text(
                'version/code=1\nversion/name="1.0"\nkeystore/release="__ANDROID_KEYSTORE_PATH__"\n'
                'keystore/release_user="__ANDROID_KEY_ALIAS__"\nkeystore/release_password="__ANDROID_KEY_PASSWORD__"\n'
                'application/short_version="1.0"\napplication/version="1.0"\n'
            )
            gd.write_text('const VERSION: String = "0.0.1"\nconst BUILD_INFO: String = "dev"\n')
            base = {**os.environ, "PRESETS_FILE": str(cfg), "VERSION_GD_FILE": str(gd)}

            r = subprocess.run(["bash", TOOLS / "inject_secrets.sh", "android"], env=base, capture_output=True, text=True)
            self.assertNotEqual(r.returncode, 0, "must fail when env is missing")

            env = {**base, "ANDROID_KEYSTORE_PATH": "/x/a&b.jks", "ANDROID_KEY_ALIAS": "al", "ANDROID_KEY_PASSWORD": "s3cr&t"}
            r = subprocess.run(["bash", TOOLS / "inject_secrets.sh", "android"], env=env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertNotIn("s3cr", r.stdout + r.stderr)
            self.assertIn('keystore/release_password="s3cr&t"', cfg.read_text())

            r = subprocess.run(["bash", TOOLS / "set_version.sh", "1.2.3", "142"], env=base, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn("version/code=142", cfg.read_text())
            self.assertIn('const BUILD_INFO: String = "1.2.3+142"', gd.read_text())


if __name__ == "__main__":
    unittest.main()
