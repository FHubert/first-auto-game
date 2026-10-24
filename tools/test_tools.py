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
            cfg.write_text('const DEFAULTS: Dictionary = {\n\t"theme_cost_base": 100000,\n}\n')
            r = run(TOOLS / "balance_sim.py", "--players", "100", "--days", "30", "--config", cfg)
            self.assertEqual(r.returncode, 1, r.stdout)
            self.assertIn("starves", r.stdout)


    def _json(self, cfg_text, players="200"):
        with tempfile.TemporaryDirectory() as d:
            cfg = Path(d) / "config.gd"
            cfg.write_text("const DEFAULTS: Dictionary = {\n" + cfg_text + "}\n")
            r = run(TOOLS / "balance_sim.py", "--json", "--players", players, "--days", "30", "--config", cfg)
            return json.loads(r.stdout)

    def test_json_has_ad_and_theme_metrics(self):
        r = run(TOOLS / "balance_sim.py", "--json", "--players", "200")
        data = json.loads(r.stdout)
        for k in ("interstitials_per_dau", "rewarded_per_dau", "first_theme_day_median", "median_themes_day7",
                  "first_theme_active_day_median", "third_theme_active_day_median",
                  "third_theme_pct_daily_players", "median_coins_active_day7"):
            self.assertIn(k, data)

    def test_parses_array_keys(self):
        hi = self._json('\t"daily_reward_base": 50,\n\t"daily_reward_multipliers": [10, 10, 10, 10, 10, 10, 10],\n')
        lo = self._json('\t"daily_reward_base": 50,\n\t"daily_reward_multipliers": [1, 1, 1, 1, 1, 1, 1],\n')
        self.assertGreater(hi["median_coins_day7"], lo["median_coins_day7"])

    def test_interstitial_min_level_caps(self):
        data = self._json('\t"interstitial_min_level": 1000,\n')
        self.assertEqual(data["interstitials_per_dau"], 0)


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


class GenSfxTest(unittest.TestCase):
    def test_generates_valid_audio(self):
        import wave

        with tempfile.TemporaryDirectory() as d:
            r = run(TOOLS / "gen_sfx.py", d)
            self.assertEqual(r.returncode, 0, r.stderr)
            wavs = sorted(Path(d).glob("*.wav"))
            ogg = Path(d) / "ambient_loop.ogg"
            sfx = [p for p in wavs if p.stem != "ambient_loop"]
            self.assertEqual(len(sfx), 8)
            self.assertEqual(len(wavs) + len(list(Path(d).glob("*.ogg"))), 9)
            for p in sfx:
                with wave.open(str(p)) as w:
                    dur = w.getnframes() / w.getframerate()
                    self.assertEqual((w.getnchannels(), w.getframerate()), (1, 44100), p.name)
                    self.assertTrue(0.03 <= dur <= 2.0, f"{p.name} {dur}")
            if ogg.exists():
                self.assertLess(ogg.stat().st_size, 1_000_000)
                if shutil.which("ffprobe"):
                    out = subprocess.run(
                        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(ogg)],
                        capture_output=True,
                        text=True,
                    ).stdout
                    self.assertGreaterEqual(float(out), 20.0)
            else:
                with wave.open(str(Path(d) / "ambient_loop.wav")) as w:
                    self.assertGreaterEqual(w.getnframes() / w.getframerate(), 20.0)


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


class VersionCodeTest(unittest.TestCase):
    EPOCH = 1767225600  # 2026-01-01T00:00:00Z

    def vc(self, *args, sde=None):
        env = {k: v for k, v in os.environ.items() if k != "SOURCE_DATE_EPOCH"}
        if sde is not None:
            env["SOURCE_DATE_EPOCH"] = str(sde)
        return subprocess.run(["bash", str(TOOLS / "version_code.sh"), *args], env=env, capture_output=True, text=True)

    def test_minutes_since_epoch(self):
        r = self.vc(sde=self.EPOCH + 600)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "10")

    def test_monotonic(self):
        a = int(self.vc(sde=self.EPOCH + 60).stdout)
        b = int(self.vc(sde=self.EPOCH + 120).stdout)
        self.assertLess(a, b)

    def test_year_2100_under_play_limit(self):
        r = self.vc(sde=4102444800)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(int(r.stdout), 2100000000)

    def test_check(self):
        self.assertEqual(self.vc("--check", "0").returncode, 2)
        self.assertEqual(self.vc("--check", "abc").returncode, 2)
        self.assertEqual(self.vc("--check", "2100000000").returncode, 2)
        self.assertEqual(self.vc("--check", "12345").returncode, 0)

    def test_before_epoch_fails(self):
        self.assertEqual(self.vc(sde=self.EPOCH - 1).returncode, 1)


class StoreScreenshotsTest(unittest.TestCase):
    LOCALES = ("en-US", "pl-PL", "de-DE")

    def test_store_pngs_are_1080x1920(self):
        from PIL import Image

        for loc in self.LOCALES:
            d = ROOT / "fastlane/metadata/android" / loc / "images/phoneScreenshots"
            files = sorted(d.glob("*.png"))
            self.assertEqual(len(files), 5, loc)
            for f in files:
                with Image.open(f) as im:
                    self.assertEqual(im.size, (1080, 1920), f)
                    self.assertLessEqual(max(im.size) / min(im.size), 2.0)

    def test_captions_cover_all_languages(self):
        caps = json.loads((TOOLS / "captions.json").read_text(encoding="utf-8"))
        self.assertEqual(len(caps), 5)
        for key, langs in caps.items():
            for lang in ("en", "pl", "de"):
                self.assertTrue(langs.get(lang, "").strip(), f"{key}/{lang}")

    def test_frame_size_option(self):
        from PIL import Image

        with tempfile.TemporaryDirectory() as tmp:
            src, out = Path(tmp) / "in", Path(tmp) / "out"
            src.mkdir()
            Image.new("RGB", (540, 960), "#3A86FF").save(src / "01_pour.png")
            r = run(TOOLS / "frame_screenshots.py", "--in", src, "--out", out, "--lang", "pl",
                    "--captions", TOOLS / "captions.json", "--size", "1080x1920")
            self.assertEqual(r.returncode, 0, r.stderr)
            with Image.open(out / "01_pour.png") as im:
                self.assertEqual(im.size, (1080, 1920))


class StoreMetadataTest(unittest.TestCase):
    TITLE_MAX, SHORT_MAX, FULL_MAX, CHANGELOG_MAX, KEYWORDS_MAX_BYTES = 30, 80, 4000, 500, 100
    META = ROOT / "fastlane" / "metadata"
    ANDROID = {"en-US": ("ads", "in-app"), "pl-PL": ("reklam", "zakup"), "de-DE": ("werbung", "in-app")}
    IOS = ("en-US", "pl", "de-DE")

    def read(self, *parts):
        return self.META.joinpath(*parts).read_text(encoding="utf-8").strip()

    def test_android_limits_and_disclosure(self):
        for loc, (ads, iap) in self.ANDROID.items():
            with self.subTest(loc=loc):
                self.assertTrue(0 < len(self.read("android", loc, "title.txt")) <= self.TITLE_MAX)
                self.assertTrue(0 < len(self.read("android", loc, "short_description.txt")) <= self.SHORT_MAX)
                full = self.read("android", loc, "full_description.txt")
                self.assertTrue(0 < len(full) <= self.FULL_MAX)
                self.assertTrue(0 < len(self.read("android", loc, "changelogs", "default.txt")) <= self.CHANGELOG_MAX)
                self.assertIn(ads, full.lower())
                self.assertIn(iap, full.lower())

    def test_ios_limits_and_keywords(self):
        import re

        for loc in self.IOS:
            with self.subTest(loc=loc):
                name, sub = self.read("ios", loc, "name.txt"), self.read("ios", loc, "subtitle.txt")
                kw = self.read("ios", loc, "keywords.txt")
                self.assertTrue(0 < len(name) <= self.TITLE_MAX)
                self.assertTrue(0 < len(sub) <= self.TITLE_MAX)
                self.assertLessEqual(len(kw.encode("utf-8")), self.KEYWORDS_MAX_BYTES)
                self.assertNotIn(" ", kw)
                used = {t for t in re.findall(r"\w+", (name + " " + sub).lower()) if len(t) >= 3}
                self.assertFalse(used & set(kw.lower().split(",")), "keywords repeat title/subtitle")
                self.assertTrue(0 < len(self.read("ios", loc, "description.txt")) <= self.FULL_MAX)
                self.assertTrue(self.read("ios", loc, "privacy_url.txt"))

    def test_no_tbd_in_metadata(self):
        for f in self.META.rglob("*.txt"):
            self.assertNotIn("TBD", f.read_text(encoding="utf-8"), str(f))


class PrivacyDocsTest(unittest.TestCase):
    PRIVACY = ROOT / "docs" / "privacy"

    def gdd_events(self):
        import re

        text = (ROOT / "docs" / "GDD.md").read_text(encoding="utf-8")
        section = text.split("\n## Analityka", 1)[1].split("\n## ", 1)[0]
        names = []
        for line in section.splitlines():
            m = re.match(r"- ((?:`[a-z_]+`(?: / )?)+)", line)
            if m:
                names += re.findall(r"`([a-z_]+)`", m.group(1))
        return names

    def test_every_gdd_event_is_in_checklist(self):
        events = self.gdd_events()
        self.assertGreaterEqual(len(events), 17)
        checklist = (ROOT / "docs" / "RELEASE_CHECKLIST.md").read_text(encoding="utf-8")
        for ev in events:
            with self.subTest(event=ev):
                self.assertIn(ev, checklist)

    def test_policies_content_and_link_dates(self):
        for name in ("index.md", "pl.md"):
            text = (self.PRIVACY / name).read_text(encoding="utf-8")
            for needle in ("__PRIVACY_CONTACT__", "All In IT", "GameAnalytics", "AdMob", "13"):
                with self.subTest(file=name, needle=needle):
                    self.assertIn(needle, text)
            for line in text.splitlines():
                if "https://" in line:
                    with self.subTest(file=name, line=line[:60]):
                        self.assertTrue("(2026-" in line or "ZWERYFIKUJ" in line)


class PrivacyManifestTest(unittest.TestCase):
    PLIST = ROOT / "game" / "ios" / "PrivacyInfo.xcprivacy"
    CHECKLIST = ROOT / "docs" / "RELEASE_CHECKLIST.md"
    CATEGORY_MAP = {
        "Identifiers → Device ID": "NSPrivacyCollectedDataTypeDeviceID",
        "Usage Data → Product Interaction": "NSPrivacyCollectedDataTypeProductInteraction",
        "Usage Data → Advertising Data": "NSPrivacyCollectedDataTypeAdvertisingData",
        "Purchases → Purchase History": "NSPrivacyCollectedDataTypePurchaseHistory",
        "Diagnostics → Crash Data": "NSPrivacyCollectedDataTypeCrashData",
        "Location → Coarse Location": "NSPrivacyCollectedDataTypeCoarseLocation",
    }

    def load(self):
        import plistlib

        with open(self.PLIST, "rb") as f:
            return plistlib.load(f)

    def table_categories(self):
        cats = []
        in_table = False
        for line in self.CHECKLIST.read_text(encoding="utf-8").splitlines():
            if "| Kategoria (ASC) |" in line:
                in_table = True
                continue
            if in_table:
                if not line.strip():
                    break
                if line.startswith("  | ") and not line.startswith("  |---"):
                    cats.append(line.split("|")[1].strip())
        return cats

    def test_plist_parses_and_has_main_keys(self):
        data = self.load()
        for key in ("NSPrivacyTracking", "NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"):
            self.assertIn(key, data)
        self.assertIs(data["NSPrivacyTracking"], True)
        self.assertIsInstance(data["NSPrivacyTrackingDomains"], list)
        if not data["NSPrivacyTrackingDomains"]:
            lines = self.CHECKLIST.read_text(encoding="utf-8").splitlines()
            self.assertTrue(
                any("ZWERYFIKUJ" in l and ("PrivacyInfo.xcprivacy" in l or "tracking domains" in l) for l in lines)
            )

    def test_collected_types_match_checklist(self):
        import re

        cats = self.table_categories()
        unknown = [c for c in cats if c not in self.CATEGORY_MAP]
        self.assertEqual(unknown, [], "category missing from CATEGORY_MAP")
        expected = {self.CATEGORY_MAP[c] for c in cats}
        items = self.load()["NSPrivacyCollectedDataTypes"]
        actual = {i["NSPrivacyCollectedDataType"] for i in items}
        self.assertEqual(expected, actual, f"diff: {expected ^ actual}")
        self.assertEqual(len(items), len(actual), "duplicate data type")
        for i in items:
            with self.subTest(t=i["NSPrivacyCollectedDataType"]):
                self.assertEqual(
                    set(i),
                    {
                        "NSPrivacyCollectedDataType",
                        "NSPrivacyCollectedDataTypeLinked",
                        "NSPrivacyCollectedDataTypeTracking",
                        "NSPrivacyCollectedDataTypePurposes",
                    },
                )
                self.assertTrue(i["NSPrivacyCollectedDataTypePurposes"])
                for p in i["NSPrivacyCollectedDataTypePurposes"]:
                    self.assertTrue(re.match(r"^NSPrivacyCollectedDataTypePurpose\w+$", p))

    def test_accessed_api_types(self):
        import re

        apis = {a["NSPrivacyAccessedAPIType"]: a["NSPrivacyAccessedAPITypeReasons"] for a in self.load()["NSPrivacyAccessedAPITypes"]}
        for cat in ("UserDefaults", "FileTimestamp", "SystemBootTime"):
            name = "NSPrivacyAccessedAPICategory" + cat
            with self.subTest(cat=name):
                self.assertTrue(apis.get(name))
                for code in apis[name]:
                    self.assertTrue(re.match(r"^[0-9A-F]{4}\.[0-9]$", code), code)

    def test_tracking_flags_consistent(self):
        data = self.load()
        if any(i["NSPrivacyCollectedDataTypeTracking"] is True for i in data["NSPrivacyCollectedDataTypes"]):
            self.assertIs(data["NSPrivacyTracking"], True)


if __name__ == "__main__":
    unittest.main()
