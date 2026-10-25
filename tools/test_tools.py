"""Self-tests for the python/bash tools. Run: python3 -m unittest discover -s tools -p "test_*.py"."""
import importlib.util
import json
import os
import re
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


def load_sim():
    spec = importlib.util.spec_from_file_location("balance_sim_t199", TOOLS / "balance_sim.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


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

    def test_theme_metrics_below_min_n_are_na(self):
        # 40 graczy -> < 30 kupujacych 3. motyw: wartosc null + n w JSON, "n/a (n=" w tekscie
        r = run(TOOLS / "balance_sim.py", "--players", "40", "--json")
        j = json.loads(r.stdout)
        self.assertLess(j["third_theme_active_day_median_n"], 30)
        self.assertIsNone(j["third_theme_active_day_median"])
        self.assertIsNone(j["theme3_buy_day_active_p50"])
        t = run(TOOLS / "balance_sim.py", "--players", "40")
        self.assertIn("n/a (n=", t.stdout)

    def test_theme3_by_d30_pct_range_and_zero_for_huge_cost(self):
        ok = json.loads(run(TOOLS / "balance_sim.py", "--players", "300", "--json").stdout)
        self.assertGreaterEqual(ok["theme3_by_d30_pct"], 0)
        self.assertLessEqual(ok["theme3_by_d30_pct"], 100)
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "o.json"
            ov.write_text('{"theme_cost_base": 100000000}')
            r = run(TOOLS / "balance_sim.py", "--players", "300", "--json", "--overlay", ov)
            j = json.loads(r.stdout)  # exit 1 (economy starves) is expected, JSON still printed
            self.assertEqual(j["theme3_by_d30_pct"], 0)
            self.assertIsNone(j["theme3_buy_day_active_p50"])

    def test_plateau_assist_take_rate_zero_equals_disabled(self):
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "o.json"
            ov.write_text('{"plateau_assist_take_rate": 0}')
            a = run(TOOLS / "balance_sim.py", "--players", "200", "--json", "--overlay", ov)
            b = run(TOOLS / "balance_sim.py", "--players", "200", "--json", "--no-plateau-assist")
            self.assertEqual(a.returncode, 0, a.stdout)
            ja, jb = json.loads(a.stdout), json.loads(b.stdout)
            ja.pop("overlay"), jb.pop("overlay")
            self.assertEqual(ja, jb)
            self.assertEqual(ja["plateau_assist_coins_per_dau"], 0)

    def test_plateau_assist_take_rate_one_uses_rewarded_extra_tube(self):
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "o.json"
            ov.write_text('{"plateau_assist_take_rate": 1}')
            r = run(TOOLS / "balance_sim.py", "--players", "200", "--json", "--overlay", ov)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            j = json.loads(r.stdout)
            self.assertGreater(j["rewarded_extra_tube_per_dau"], 0)
            self.assertGreater(j["plateau_assist_coins_per_dau"], 0)

    def test_plateau_assist_buys_not_above_attempts(self):
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "o.json"
            ov.write_text('{"plateau_assist_take_rate": 1}')
            r = run(TOOLS / "balance_sim.py", "--players", "200", "--json", "--overlay", ov)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            j = json.loads(r.stdout)
            self.assertGreater(j["plateau_assist_buys"], 0)
            self.assertLessEqual(j["plateau_assist_buys"], j["plateau_assist_attempts"])

    def test_plateau_assist_win_prob_is_monotonic_in_attempts(self):
        # Mniejszy mnoznik porazki (0 = zawsze wygrana) -> szybszy awans -> nie wiecej prob na plateau
        # (mediana monet nie jest monotoniczna: szybszy awans zmienia tez sciezke wydatkow).
        def attempts(p: str) -> float:
            with tempfile.TemporaryDirectory() as d:
                ov = Path(d) / "o.json"
                ov.write_text('{"plateau_assist_fail_mult_26_55": %s, "plateau_assist_fail_mult_56": %s}' % (p, p))
                r = run(TOOLS / "balance_sim.py", "--players", "300", "--seed", "1", "--json", "--overlay", ov)
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
                return json.loads(r.stdout)["plateau_assist_attempts"]

        self.assertGreaterEqual(attempts("1"), attempts("0"))

    def _sim_json(self, *extra, players="200"):
        r = run(TOOLS / "balance_sim.py", "--players", players, "--seed", "1", "--json", *extra)
        self.assertIn(r.returncode, (0, 1), r.stdout + r.stderr)  # 1 = "starves" przy absurdalnych kosztach
        return json.loads(r.stdout)

    def test_without_always_active_flag_metrics_unchanged(self):
        # T-202: zlote wartosci z gałęzi bazowej (BUILTIN, seed 1, 200 graczy) - flaga nie moze zmienic sciezki domyslnej
        # (kolejnosc losowan rnd). Zmiana modelu sim = swiadoma aktualizacja tych wartosci.
        j = self._sim_json("--config", "/nonexistent")
        golden = {
            "engaged_players": 165, "median_coins_day1": 320, "median_coins_day7": 410, "median_coins_day30": 590,
            "median_themes_day7": 1, "first_theme_day_median_n": 161, "median_coins_active_day7": 565.0,
            "interstitials_per_dau": 1.358, "rewarded_per_dau": 3.031, "plateau_assist_coins_per_dau": 18.0,
            "plateau_assist_buys": 556, "plateau_assist_attempts": 4711, "sessions_per_dau": 3.24,
        }
        self.assertFalse(j["always_active"])
        self.assertEqual({k: j[k] for k in golden}, golden)

    def _yday_json(self, on, *extra, players="400"):
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "o.json"
            ov.write_text('{"sim_yesterday_daily": %d}' % on)
            return self._sim_json("--overlay", ov, *extra, players=players)

    def test_t226_lever_off_by_default_and_raises_rewarded_per_dau(self):
        off, on = self._yday_json(0), self._yday_json(1)
        self.assertEqual(off["rewarded_yesterday_daily_per_dau"], 0)
        self.assertNotIn("yesterday_daily", off["rewarded_by_placement"])  # bez flagi wyjscie jak przed T-226
        self.assertGreater(on["rewarded_yesterday_daily_per_dau"], 0)
        self.assertGreater(on["rewarded_per_dau"], off["rewarded_per_dau"])

    def test_t226_active_pattern_7_has_no_missed_days_so_lever_is_noop(self):
        a, b = self._yday_json(0, "--active-pattern", "7"), self._yday_json(1, "--active-pattern", "7")
        for k in ("rewarded_per_dau", "impressions_per_dau", "coins_earned_per_dau", "daily_month_goal_hit_pct",
                  "daily_month_goal_day_p50", "median_coins_day30", "rewarded_yesterday_daily_per_dau"):
            self.assertEqual(a[k], b[k], k)
        self.assertEqual(b["rewarded_yesterday_daily_per_dau"], 0)
        always = self._yday_json(0, "--always-active")  # --always-active = K 7
        for k in ("rewarded_per_dau", "impressions_per_dau", "daily_month_goal_hit_pct", "daily_month_goal_day_p50"):
            self.assertEqual(a[k], always[k], k)

    def test_t226_pattern_4_cannot_hit_month_goal_even_with_lever(self):
        # UDOKUMENTOWANE "nie": K=4 -> 18 aktywnych dni z 30 + 4 zalegle (po przerwie) = max 22 poziomy, a przy
        # play_rate 0.6 / take_rate 0.5 cel 20 praktycznie nie pada (0 z 400); dzwignia daje wiecej rewarded, ale nie cel.
        off, on = self._yday_json(0, "--active-pattern", "4"), self._yday_json(1, "--active-pattern", "4")
        self.assertEqual((off["daily_month_goal_hit_pct"], on["daily_month_goal_hit_pct"]), (0.0, 0.0))
        self.assertGreater(on["rewarded_yesterday_daily_per_dau"], 0)

    def test_t226_pattern_6_lever_raises_month_goal_hit(self):
        off, on = self._yday_json(0, "--active-pattern", "6"), self._yday_json(1, "--active-pattern", "6")
        self.assertGreater(on["daily_month_goal_hit_pct"], off["daily_month_goal_hit_pct"])

    def test_t209_sd_nonnegative_and_ci_contains_mean(self):
        j = self._sim_json()
        ipd = j["impressions_per_player_day"]
        self.assertGreaterEqual(ipd["sd"], 0)
        self.assertGreater(ipd["n"], 0)
        for key, mean in (("total", j["impressions_per_dau"]), ("rewarded", j["rewarded_per_dau"]),
                          ("interstitial", j["interstitials_per_dau"])):
            lo, hi = j["ads_per_dau_ci95"][key]
            self.assertLessEqual(lo, mean + 1e-3, key)
            self.assertGreaterEqual(hi, mean - 1e-3, key)

    def _ci_half(self, players, seed="1"):
        r = run(TOOLS / "balance_sim.py", "--players", players, "--seed", seed, "--json")
        lo, hi = json.loads(r.stdout)["ads_per_dau_ci95"]["total"]
        return (lo, hi)

    def test_t209_ci_width_shrinks_with_sqrt_n(self):
        w1 = self._ci_half("500")
        w4 = self._ci_half("2000")
        ratio = (w1[1] - w1[0]) / (w4[1] - w4[0])
        self.assertAlmostEqual(ratio, 2.0, delta=0.5)

    def test_t209_ci_overlap_between_seeds(self):
        a, b = self._ci_half("1000", "1"), self._ci_half("1000", "2")
        self.assertLessEqual(max(a[0], b[0]), min(a[1], b[1]))

    def test_always_active_everyone_active_14_days(self):
        j = self._sim_json("--always-active")
        self.assertTrue(j["always_active"])
        self.assertEqual(j["active14_players"], 200)
        self.assertEqual(j["engaged_players"], 200)
        self.assertEqual(j["coins_earned_cum_active_day30_p50_n"], 200)
        self.assertEqual(self._sim_json()["active14_players"], 0)

    def test_t203_defaults_meet_theme_goal_on_daily_player_proxy(self):
        # T-203: straznik regresji ekonomii - DEFAULTS (600/1.8): 3. motyw <= 14. dnia aktywnego, 1. >= 2.
        j = self._sim_json("--always-active", players="1000")
        self.assertLessEqual(j["theme3_buy_day_active_p50"], 14)
        self.assertGreaterEqual(j["theme1_buy_day_active_p50"], 2)

    def test_coins_earned_cum_monotonic_by_active_day(self):
        j = self._sim_json("--always-active")
        for q in ("p50", "p90"):
            d7, d14, d30 = (j[f"coins_earned_cum_active_day{d}_{q}"] for d in (7, 14, 30))
            self.assertLessEqual(d7, d14)
            self.assertLessEqual(d14, d30)
        self.assertLessEqual(j["coins_earned_cum_active_day7_p50"], j["coins_earned_cum_active_day7_p90"])
        self.assertEqual(list(load_sim().theme_thresholds(load_sim().BUILTIN)), [600, 1680, 3624])

    def test_theme_affordable_active_day_cost_overlay(self):
        base = self._sim_json("--always-active")
        self.assertLessEqual(base["theme1_affordable_active_day_p50"], base["theme3_affordable_active_day_p50"])
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "o.json"
            ov.write_text('{"theme_cost_base": 6000}')
            j = self._sim_json("--always-active", "--overlay", ov)
        t3 = j["theme3_affordable_active_day_p50"]
        self.assertTrue(t3 is None or t3 > 30, t3)

    def test_assisted_win_prob_table(self):
        sim = load_sim()
        self.assertAlmostEqual(sim.assisted_win_prob(0.55, 0.67), 0.6985, delta=1e-9)
        for w in (0.0, 0.3, 0.55, 0.9):
            self.assertAlmostEqual(sim.assisted_win_prob(w, 1.0), w, delta=1e-9)
            self.assertAlmostEqual(sim.assisted_win_prob(w, 0.0), 1.0, delta=1e-9)
            for m in (0.5, 0.67, 0.74):
                self.assertGreaterEqual(sim.assisted_win_prob(w, m), w)

    def test_plateau_assist_fail_mult_lever_changes_outcome(self):
        def metrics(m: str) -> tuple:
            with tempfile.TemporaryDirectory() as d:
                ov = Path(d) / "o.json"
                ov.write_text('{"plateau_assist_fail_mult_26_55": %s, "plateau_assist_fail_mult_56": %s}' % (m, m))
                r = run(TOOLS / "balance_sim.py", "--players", "300", "--seed", "1", "--json", "--overlay", ov)
                j = json.loads(r.stdout)
                return (j["median_coins_day30"], j["plateau_assist_buys"], j["plateau_assist_attempts"])

        self.assertNotEqual(metrics("0.5"), metrics("1.0"))

    def test_plateau_assist_coins_per_dau_positive_by_default(self):
        r = run(TOOLS / "balance_sim.py", "--players", "300", "--seed", "1", "--json")
        self.assertGreater(json.loads(r.stdout)["plateau_assist_coins_per_dau"], 0)

    def test_old_plateau_win_prob_overlay_key_is_ignored_with_warning(self):
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "o.json"
            ov.write_text('{"plateau_assist_win_prob_26_55": 1.0}')
            r = run(TOOLS / "balance_sim.py", "--players", "100", "--json", "--overlay", ov)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("ignored overlay key", r.stdout + r.stderr)

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

    def _sim_module(self):
        spec = importlib.util.spec_from_file_location("balance_sim", TOOLS / "balance_sim.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    def test_overlay_h1_changes_rewarded_multiplier_and_coins(self):
        ov = ROOT / "docs" / "remote_config" / "h1_b.json"
        args = ("--json", "--players", "200", "--seed", "1")
        with_ov = json.loads(run(TOOLS / "balance_sim.py", *args, "--overlay", ov).stdout)
        base = json.loads(run(TOOLS / "balance_sim.py", *args).stdout)
        self.assertTrue(with_ov["overlay"].endswith("h1_b.json"))
        self.assertIsNone(base["overlay"])
        self.assertNotEqual(with_ov["median_coins_day7"], base["median_coins_day7"])
        sim = self._sim_module()
        cfg, _ = sim.load_config(sim.DEFAULT_CONFIG)
        applied, _ignored = sim.apply_overlay(cfg, ov)
        self.assertEqual(cfg["rewarded_multiplier"], 3.0)
        self.assertIn("rewarded_multiplier", applied)

    def test_overlay_unknown_key_is_ignored(self):
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "ov.json"
            ov.write_text(json.dumps({"starter_offer_min_level": 6, "remote_config_variant": "x"}))
            r = run(TOOLS / "balance_sim.py", "--players", "100", "--overlay", ov)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("ignored overlay key: starter_offer_min_level", r.stderr)
            self.assertIn("overlay=ov.json", r.stdout)

    def test_overlay_meta_key_is_silent_unknown_key_warns(self):
        with tempfile.TemporaryDirectory() as d:
            meta = Path(d) / "meta.json"
            meta.write_text(json.dumps({"remote_config_variant": "h1_b", "rewarded_multiplier": 3.0}))
            r = run(TOOLS / "balance_sim.py", "--players", "100", "--overlay", meta)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertNotIn("ignored overlay key", r.stderr)
            unk = Path(d) / "unk.json"
            unk.write_text(json.dumps({"remote_config_variant": "h1_b", "no_such_key": 1}))
            r = run(TOOLS / "balance_sim.py", "--players", "100", "--overlay", unk)
            self.assertIn("ignored overlay key: no_such_key", r.stderr)
            self.assertNotIn("ignored overlay key: remote_config_variant", r.stderr)

    def test_overlay_bad_json_exits_2(self):
        with tempfile.TemporaryDirectory() as d:
            ov = Path(d) / "bad.json"
            ov.write_text("{not json")
            self.assertEqual(run(TOOLS / "balance_sim.py", "--overlay", ov).returncode, 2)
            ov.write_text("[1, 2]")
            self.assertEqual(run(TOOLS / "balance_sim.py", "--overlay", ov).returncode, 2)

    def test_overlay_missing_file_exits_2(self):
        r = run(TOOLS / "balance_sim.py", "--overlay", ROOT / "nope" / "missing.json")
        self.assertEqual(r.returncode, 2)
        self.assertIn("overlay not found", r.stderr)


class SimConfigMirrorTest(unittest.TestCase):
    """balance_sim.BUILTIN mirror keys must match GameConfig.DEFAULTS."""

    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("balance_sim_mirror", TOOLS / "balance_sim.py")
        cls.sim = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.sim)
        text = cls.sim.DEFAULT_CONFIG.read_text(encoding="utf-8")
        body = re.search(r"\bDEFAULTS\b[^=\n]*=\s*\{(.*?)^\}", text, re.S | re.M).group(1)
        cls.defaults = dict(re.findall(r"[\"']([A-Za-z_]\w*)[\"']\s*:\s*([^,\n]+),", body))
        src = (TOOLS / "balance_sim.py").read_text(encoding="utf-8")
        mirror_src = src.split("# --- sim-only", 1)[0]
        cls.mirror_keys = [k for k in cls.sim.BUILTIN if f'"{k}":' in mirror_src]

    def test_mirror_keys_exist_in_defaults(self):
        self.assertGreater(len(self.mirror_keys), 20)
        missing = [k for k in self.mirror_keys if k not in self.defaults]
        self.assertEqual(missing, [], f"BUILTIN mirror keys missing in DEFAULTS: {missing}")

    def test_mirror_numeric_values_match_defaults(self):
        diffs = []
        for k in self.mirror_keys:
            v = self.sim.BUILTIN[k]
            raw = self.defaults.get(k, "").strip()
            if isinstance(v, (int, float)) and re.fullmatch(r"-?\d+(\.\d+)?", raw) and float(raw) != float(v):
                diffs.append(f"{k}: BUILTIN={v} DEFAULTS={raw}")
        self.assertEqual(diffs, [], f"BUILTIN differs from config.gd: {diffs}")

    def test_mirror_array_values_match_defaults(self):
        body = re.search(r"\bDEFAULTS\b[^=\n]*=\s*\{(.*?)^\}", self.sim.DEFAULT_CONFIG.read_text(encoding="utf-8"), re.S | re.M).group(1)
        arrays = {k: [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", v)]
                  for k, v in re.findall(r"[\"']([A-Za-z_]\w*)[\"']\s*:\s*\[([^\]]*)\]", body)}
        checked, diffs = [], []
        for k in self.mirror_keys:
            v = self.sim.BUILTIN[k]
            if isinstance(v, (list, tuple)):
                checked.append(k)
                if arrays.get(k) != [float(x) for x in v]:
                    diffs.append(f"{k}: BUILTIN={v} DEFAULTS={arrays.get(k)}")
        self.assertIn("daily_reward_multipliers", checked)
        self.assertEqual(diffs, [], f"BUILTIN arrays differ from config.gd: {diffs}")

    def test_load_default_config_has_no_warning(self):
        _cfg, notes = self.sim.load_config(self.sim.DEFAULT_CONFIG)
        self.assertFalse([n for n in notes if "WARNING" in n], notes)


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
                with Image.open(p / "tubes" / f"{n}.png") as im:
                    self.assertEqual(im.size, (128, 384))
            with Image.open(p / "icon_1024.png") as big:
                self.assertEqual((big.mode, big.size), ("RGB", (1024, 1024)))
            with Image.open(p / "icon_512.png") as im:
                self.assertEqual(im.size, (512, 512))


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


class MakeWorktreeIsolationTest(unittest.TestCase):
    # T-221: osobny user:// per checkout (XDG_DATA_HOME) + gdUnit4 symlink nie w git status.
    @staticmethod
    def recipes() -> dict:
        out, name = {}, None
        for line in (ROOT / "Makefile").read_text(encoding="utf-8").splitlines():
            m = re.match(r"^([a-z-]+):", line)
            if m:
                name = m.group(1)
                out[name] = []
            elif name and line.startswith("\t"):
                out[name].append(line)
            elif line.strip():
                name = None
        return out

    def test_gitignore_covers_gdunit_symlink_and_userdata(self):
        for path in ("game/addons/gdUnit4", ".godot-userdata/x"):
            with self.subTest(path=path):
                r = subprocess.run(["git", "check-ignore", "-q", "--no-index", path], cwd=ROOT)
                self.assertEqual(r.returncode, 0, f"{path} must be git-ignored")

    def test_test_and_playtest_recipes_use_isolated_userdata(self):
        recipes = self.recipes()
        for name in ("test", "playtest"):
            with self.subTest(recipe=name):
                body = "\n".join(recipes[name])
                self.assertIn("XDG_DATA_HOME", body)
                for line in recipes[name]:
                    for m in re.finditer(r"\$\(GODOT_BIN\)", line):
                        self.assertTrue(line[: m.start()].rstrip().endswith("XDG_DATA_HOME=$(ROOT)/.godot-userdata"), line)
        self.assertNotIn("XDG_DATA_HOME", "\n".join(recipes["export-check"]))


class SetupEnvAndroidTemplate(unittest.TestCase):
    def test_android_build_template_wired(self):
        script = (TOOLS / "setup_env.sh").read_text(encoding="utf-8")
        for needle in ("android_source.zip", ".build_version", ".gdignore"):
            self.assertIn(needle, script)
        self.assertIn("game/android/build/", (ROOT / ".gitignore").read_text(encoding="utf-8"))


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

    def test_every_gdd_event_is_in_dashboard(self):
        events = self.gdd_events()
        self.assertGreaterEqual(len(events), 17)
        dashboard = (ROOT / "docs" / "DASHBOARD.md").read_text(encoding="utf-8")
        for ev in events:
            with self.subTest(event=ev):
                self.assertIn(ev, dashboard)

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




class PerfReportTest(unittest.TestCase):
    # T-241: schemat perf.json + `make perf` poza zaleznosciami `check`.
    def load_merge(self):
        spec = importlib.util.spec_from_file_location("perf_merge_t241", TOOLS / "perf_merge.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    def example(self, mod):
        stat = [1.0, 2.0, 3.0]
        hint = {"summary": {b: {"main_ms": stat, "worker_ms": stat} for b in mod.BRACKETS}}
        startup = {k: {"med_ms": 5.0, "p95_ms": 9.0} for k in ("a", "b2", "b3", "c")}
        return mod.merge(startup, hint, {"2": {"sync_us": 10, "prefetched_us": 1}}, "abc1234", "4.7.2-stable")

    def test_perf_json_schema(self):
        mod = self.load_merge()
        report = self.example(mod)
        mod.validate(report)
        self.assertEqual(report["hint"]["56+"]["worker"], {"med": 1.0, "p95": 2.0, "max": 3.0})
        del report["startup"]["daily"]
        with self.assertRaises(ValueError):
            mod.validate(report)
        report = self.example(mod)
        report["prefetch"]["2"]["sync_us"] = -1
        with self.assertRaises(ValueError):
            mod.validate(report)

    def test_merge_fails_on_missing_input(self):
        r = run(TOOLS / "perf_merge.py", "--startup", "/nonexistent", "--hint", "/nonexistent",
                "--prefetch", "/nonexistent", "--out", "/nonexistent/o.json", "--commit", "x", "--godot-version", "y")
        self.assertNotEqual(r.returncode, 0)

    def test_perf_target_exists_and_not_in_check(self):
        recipes = MakeWorktreeIsolationTest.recipes()
        self.assertIn("perf", recipes)
        self.assertIn("perf_merge.py", "\n".join(recipes["perf"]))
        deps = re.search(r"^check:(.*)$", (ROOT / "Makefile").read_text(encoding="utf-8"), re.M).group(1).split()
        self.assertNotIn("perf", deps)


class AdsTestHygieneTest(unittest.TestCase):
    """T-240: suites that dirty the Ads singleton must call Ads.reset_for_test()."""

    def test_ads_singleton_state_is_reset_in_suites(self):
        dirty = re.compile(r"(?<![\w.])Ads\.(set_ads_removed\(true\)|ads_removed = true)")
        for f in sorted((ROOT / "game" / "test").rglob("*.gd")):
            text = f.read_text(encoding="utf-8")
            if dirty.search(text):
                with self.subTest(file=f.name):
                    self.assertIn("Ads.reset_for_test()", text)


if __name__ == "__main__":
    unittest.main()
