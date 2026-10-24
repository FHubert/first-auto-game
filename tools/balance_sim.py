#!/usr/bin/env python3
"""Offline economy simulation for the sort puzzle (no Godot needed).

Reads balance parameters from the DEFAULTS dictionary in game/src/systems/config.gd
(scalar and number-array keys it recognises override the built-ins below; unknown keys are
ignored) and simulates N players over D days:
  * daily activity follows a retention curve (D0=1, D1, D7, D30 interpolated log-linearly),
  * login streak with a 7-day reward cycle (daily_reward_multipliers), optional rewarded x2
    and rewarded streak save,
  * sessions/day ~ Poisson x engagement, levels per session ~ Poisson; a level is won with a
    probability falling with level (difficulty curve); a loss = stuck, the same level is retried,
  * wins give coins (+ par bonus, optional rewarded double), daily challenge gives coins,
  * sinks: hint / extra tube / undo refill (coins or rewarded) and up to 3 paid themes
    (theme_cost_base x theme_cost_growth^n),
  * interstitials after a level, gated by level, round count and elapsed time, never right
    after a rewarded ad.

Exit code 1 when the economy
  * "explodes": median coins after the last day > 100x median coins after day 1, or
  * "starves": median themes owned by day 7 < 1, or
  * produces any negative balance.
Ad density (interstitial <= 2.5, total >= 3.0 per DAU) only prints a WARN, it does not fail.
Statistics are taken over *engaged* players (active on >= 2 of the first 7 days).

Usage: python3 tools/balance_sim.py --players 1000 --days 30 --seed 1 [--json] [--config PATH]
"""
from __future__ import annotations

import argparse
import json
import math
import random
import re
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = ROOT / "game" / "src" / "systems" / "config.gd"

# Built-in defaults (used when config.gd is missing or lacks a key).
BUILTIN = {
    # --- keys that mirror GameConfig.DEFAULTS (overridden from config.gd) ---
    "starting_coins": 100,
    "win_reward_coins": 10,
    "par_bonus_coins": 5,
    "rewarded_multiplier": 2.0,
    "daily_reward_base": 50,
    "daily_reward_multipliers": [1, 1, 2, 2, 3, 3, 6],
    "daily_challenge_coins": 50,
    "daily_unlock_level": 3,
    "daily_month_goal": 20,
    "daily_month_goal_coins": 300,
    "hint_cost_coins": 25,
    "extra_tube_cost_coins": 60,
    "undo_refill_cost_coins": 20,
    "theme_cost_base": 600,
    "theme_cost_growth": 1.8,
    "interstitial_every_n_rounds": 3,
    "interstitial_min_seconds": 90,
    "interstitial_min_level": 8,
    "rewarded_double_coins_min_level": 2,
    "streak_grace_days": 1,
    "difficulty_min": 0.1,
    "difficulty_max": 1.0,
    "difficulty_midpoint_level": 20,
    "difficulty_steepness": 0.15,
    # --- sim-only model parameters ---
    "sessions_per_day": 3.0,  # sim-only
    "levels_per_session": 3.5,  # sim-only
    "level_seconds": 40,  # sim-only: time of one level attempt
    "win_prob_easy": 0.95,  # sim-only
    "win_prob_hard": 0.55,  # sim-only
    "perfect_rate": 0.40,  # sim-only
    "double_coins_watch_rate": 0.25,  # sim-only
    "hint_rate_per_level": 0.10,  # sim-only (per stuck attempt)
    "extra_tube_rate_per_level": 0.05,  # sim-only
    "undo_refill_rate_per_level": 0.05,  # sim-only
    "booster_ad_share": 0.5,  # sim-only
    "daily_challenge_play_rate": 0.6,  # sim-only
    "daily_x2_watch_rate": 0.5,  # sim-only
    "streak_save_watch_rate": 0.5,  # sim-only
    "theme_buy_rate": 0.7,  # sim-only
    "max_paid_themes": 3,  # sim-only
    "retention_d1": 0.38,  # sim-only
    "retention_d7": 0.14,  # sim-only
    "retention_d30": 0.05,  # sim-only
}


def _num(v: str):
    return float(v) if "." in v else int(v)


def load_config(path: Path) -> tuple[dict, list[str]]:
    cfg = {k: (list(v) if isinstance(v, list) else v) for k, v in BUILTIN.items()}
    notes: list[str] = []
    if not path.exists():
        notes.append(f"WARNING: {path} not found, using built-in defaults")
        return cfg, notes
    text = path.read_text(encoding="utf-8")
    m = re.search(r"\bDEFAULTS\b[^=\n]*=\s*\{(.*?)^\}", text, re.S | re.M)
    if not m:
        notes.append(f"WARNING: no DEFAULTS dictionary in {path}, using built-in defaults")
        return cfg, notes
    found = 0
    for key, val in re.findall(r"[\"']([A-Za-z_][\w]*)[\"']\s*:\s*(-?\d+(?:\.\d+)?)\s*,", m.group(1)):
        if key in cfg and not isinstance(cfg[key], list):
            cfg[key] = _num(val)
            found += 1
    for key, val in re.findall(r"[\"']([A-Za-z_][\w]*)[\"']\s*:\s*\[([^\]]*)\]", m.group(1)):
        nums = re.findall(r"-?\d+(?:\.\d+)?", val)
        if key in cfg and isinstance(cfg[key], list) and nums:
            cfg[key] = [_num(n) for n in nums]
            found += 1
    notes.append(f"loaded {found} known key(s) from {path.name}")
    return cfg, notes


def poisson(rnd: random.Random, lam: float) -> int:
    limit, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rnd.random()
        if p <= limit:
            return k
        k += 1


def retention_at(cfg: dict, day: int) -> float:
    """Probability a player is active on `day` (0 = install day), log-linear between anchors."""
    pts = [(0, 1.0), (1, cfg["retention_d1"]), (7, cfg["retention_d7"]), (30, cfg["retention_d30"])]
    if day >= 30:
        return cfg["retention_d30"]
    for (d0, v0), (d1, v1) in zip(pts, pts[1:]):
        if d0 <= day <= d1:
            t = (day - d0) / (d1 - d0)
            return math.exp(math.log(v0) * (1 - t) + math.log(v1) * t)
    return cfg["retention_d30"]


def difficulty(cfg: dict, level: int) -> float:
    """Logistic difficulty curve, same shape as GameConfig's difficulty_* keys."""
    span = cfg["difficulty_max"] - cfg["difficulty_min"]
    x = -cfg["difficulty_steepness"] * (level - cfg["difficulty_midpoint_level"])
    return cfg["difficulty_min"] + span / (1.0 + math.exp(x))


def win_probability(cfg: dict, level: int) -> float:
    d = difficulty(cfg, level)
    return cfg["win_prob_easy"] - (cfg["win_prob_easy"] - cfg["win_prob_hard"]) * d


PLACEMENTS = ("double_coins", "daily_x2", "streak_save", "extra_tube", "undo_refill")


def simulate(cfg: dict, players: int, days: int, seed: int) -> dict:
    rnd = random.Random(seed)
    coins_by_day = [[] for _ in range(days)]  # per day: balances of engaged players
    themes_d7: list[int] = []
    first_days: list[int] = []
    third_days: list[int] = []
    first_active: list[int] = []
    third_active: list[int] = []
    coins_active7: list[int] = []
    daily_players = daily_third = 0
    negative_players = engaged = active_days = sessions_total = interstitials = 0
    rewarded = {k: 0 for k in PLACEMENTS}
    mults = cfg["daily_reward_multipliers"]
    grace = int(cfg["streak_grace_days"])

    for _ in range(players):
        engagement = max(0.3, rnd.lognormvariate(0.0, 0.35))
        coins = int(cfg["starting_coins"])
        level = 1
        themes = 0
        streak = 0
        last_active = None
        last_save_day = -100
        game_time = 0.0
        last_inter = -1e9
        since_inter = 0
        buy_days: list[int] = []
        buy_active: list[int] = []
        active_count = 0
        daily_done = 0
        coins_at_active7 = None
        activity = [rnd.random() < retention_at(cfg, d) for d in range(days)]
        activity[0] = True
        is_engaged = sum(activity[:7]) >= 2
        themes_at_7 = 0
        went_negative = False
        balances = []

        def spend_or_ad(cost: int, key: str, coins: int) -> int:
            if coins < cost or rnd.random() < cfg["booster_ad_share"]:
                rewarded[key] += 1
                return coins
            return coins - cost

        for day in range(days):
            if activity[day]:
                active_days += 1
                active_count += 1
                gap = None if last_active is None else day - last_active
                if gap is None:
                    streak = 1
                elif gap == 1:
                    streak += 1
                elif gap == grace + 1 and day - last_save_day >= 7 and rnd.random() < cfg["streak_save_watch_rate"]:
                    rewarded["streak_save"] += 1
                    last_save_day = day
                    streak += 1
                else:
                    streak = 1
                last_active = day
                reward = cfg["daily_reward_base"] * mults[(streak - 1) % 7 % len(mults)]
                if rnd.random() < cfg["daily_x2_watch_rate"]:
                    rewarded["daily_x2"] += 1
                    reward *= cfg["rewarded_multiplier"]
                coins += int(round(reward))
                if level >= cfg["daily_unlock_level"] and rnd.random() < cfg["daily_challenge_play_rate"]:
                    coins += int(cfg["daily_challenge_coins"])
                    daily_done += 1
                    if daily_done == cfg["daily_month_goal"]:  # month goal bonus (T-137)
                        coins += int(cfg["daily_month_goal_coins"])
                n_sessions = max(1, poisson(rnd, cfg["sessions_per_day"] * engagement))
                sessions_total += n_sessions
                for _s in range(n_sessions):
                    for _l in range(max(1, poisson(rnd, cfg["levels_per_session"]))):
                        game_time += cfg["level_seconds"]
                        if rnd.random() < win_probability(cfg, level):
                            total = int(cfg["win_reward_coins"])
                            if rnd.random() < cfg["perfect_rate"]:
                                total += int(cfg["par_bonus_coins"])
                            rewarded_in_break = False
                            if level >= cfg["rewarded_double_coins_min_level"] and rnd.random() < cfg["double_coins_watch_rate"]:
                                rewarded["double_coins"] += 1
                                rewarded_in_break = True
                                total = int(round(total * cfg["rewarded_multiplier"]))
                            coins += total
                            level += 1
                            since_inter += 1
                            if (
                                level >= cfg["interstitial_min_level"]
                                and since_inter >= cfg["interstitial_every_n_rounds"]
                                and game_time - last_inter >= cfg["interstitial_min_seconds"]
                                and not rewarded_in_break
                            ):
                                interstitials += 1
                                since_inter = 0
                                last_inter = game_time
                        else:
                            if coins >= cfg["hint_cost_coins"] and rnd.random() < cfg["hint_rate_per_level"]:
                                coins -= int(cfg["hint_cost_coins"])
                            if rnd.random() < cfg["extra_tube_rate_per_level"]:
                                coins = spend_or_ad(int(cfg["extra_tube_cost_coins"]), "extra_tube", coins)
                            if rnd.random() < cfg["undo_refill_rate_per_level"]:
                                coins = spend_or_ad(int(cfg["undo_refill_cost_coins"]), "undo_refill", coins)
                    cost = round(cfg["theme_cost_base"] * cfg["theme_cost_growth"] ** themes)
                    if themes < cfg["max_paid_themes"] and coins >= cost and rnd.random() < cfg["theme_buy_rate"]:
                        coins -= cost
                        themes += 1
                        buy_days.append(day + 1)
                        buy_active.append(active_count)
                if coins < 0:
                    went_negative = True
                if active_count == 7:
                    coins_at_active7 = coins
            balances.append(coins)
            if day == 6:
                themes_at_7 = themes
        if is_engaged:
            engaged += 1
            themes_d7.append(themes_at_7)
            if len(buy_days) >= 1:
                first_days.append(buy_days[0])
            if len(buy_days) >= 3:
                third_days.append(buy_days[2])
            if buy_active:
                first_active.append(buy_active[0])
            if len(buy_active) >= 3:
                third_active.append(buy_active[2])
            if coins_at_active7 is not None:
                coins_active7.append(coins_at_active7)
            if active_count >= 20:
                daily_players += 1
                daily_third += len(buy_active) >= 3
            for d in range(days):
                coins_by_day[d].append(balances[d])
        negative_players += went_negative

    return {
        "engaged": engaged,
        "coins_by_day": coins_by_day,
        "themes_d7": themes_d7,
        "first_days": first_days,
        "third_days": third_days,
        "first_active": first_active,
        "third_active": third_active,
        "coins_active7": coins_active7,
        "daily_players": daily_players,
        "daily_third": daily_third,
        "negative_players": negative_players,
        "players": players,
        "active_days": active_days,
        "sessions": sessions_total,
        "interstitials": interstitials,
        "rewarded": rewarded,
    }


def main(argv: list | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--players", type=int, default=1000)
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    ap.add_argument("--json", action="store_true", help="print machine-readable JSON only")
    args = ap.parse_args(argv)
    if args.days < 8:
        ap.error("--days must be >= 8 (day-7 statistics)")

    cfg, notes = load_config(args.config)
    for n in notes:
        print(f"[balance_sim] {n}", file=sys.stderr)

    res = simulate(cfg, args.players, args.days, args.seed)
    if res["engaged"] == 0:
        print("[balance_sim] no engaged players; increase --players", file=sys.stderr)
        return 1

    med = lambda xs: statistics.median(xs) if xs else 0
    day1 = med(res["coins_by_day"][0])
    day7 = med(res["coins_by_day"][6])
    last = med(res["coins_by_day"][args.days - 1])
    med_themes_d7 = med(res["themes_d7"])
    eng = res["engaged"]
    dau = max(1, res["active_days"])
    neg_pct = 100.0 * res["negative_players"] / max(1, res["players"])
    inter_dau = res["interstitials"] / dau
    rew_total = sum(res["rewarded"].values())
    rew_dau = rew_total / dau
    imp_dau = inter_dau + rew_dau
    first_med = med(res["first_days"]) if res["first_days"] else None
    third_med = med(res["third_days"]) if res["third_days"] else None
    first_pct = 100.0 * len(res["first_days"]) / eng
    third_pct = 100.0 * len(res["third_days"]) / eng

    first_act = med(res["first_active"]) if res["first_active"] else None
    third_act = med(res["third_active"]) if res["third_active"] else None
    daily_pct = 100.0 * res["daily_third"] / res["daily_players"] if res["daily_players"] else 0.0

    problems = []
    if last > 100 * max(day1, 1):
        problems.append(f"economy explodes: median coins day {args.days} ({last:.0f}) > 100x day 1 ({day1:.0f})")
    if med_themes_d7 < 1:
        problems.append(f"economy starves: median themes owned by day 7 = {med_themes_d7:.1f} (< 1)")
    if res["negative_players"] > 0:
        problems.append(f"negative balances: {neg_pct:.2f} % of players (must be 0)")

    by_place = {k: round(v / dau, 3) for k, v in res["rewarded"].items()}
    out = {
        "players": args.players,
        "days": args.days,
        "seed": args.seed,
        "engaged_players": eng,
        "median_coins_day1": day1,
        "median_coins_day7": day7,
        f"median_coins_day{args.days}": last,
        "median_themes_day7": med_themes_d7,
        "first_theme_day_median": first_med,
        "third_theme_day_median": third_med,
        "first_theme_active_day_median": first_act,
        "third_theme_active_day_median": third_act,
        "third_theme_pct_daily_players": round(daily_pct, 1),
        "median_coins_active_day7": med(res["coins_active7"]),
        "first_theme_pct": round(first_pct, 1),
        "third_theme_pct": round(third_pct, 1),
        "interstitials_per_dau": round(inter_dau, 3),
        "rewarded_per_dau": round(rew_dau, 3),
        "rewarded_by_placement": by_place,
        "impressions_per_dau": round(imp_dau, 3),
        "sessions_per_dau": round(res["sessions"] / dau, 2),
        "negative_balance_pct": round(neg_pct, 3),
        "ok": not problems,
        "problems": problems,
    }
    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"players={args.players} days={args.days} seed={args.seed} engaged={eng}")
        print(f"median coins: day1={day1:.0f}  day7={day7:.0f}  day{args.days}={last:.0f}")
        print(f"median themes owned by day 7: {med_themes_d7:.1f}")
        fm = "n/a" if first_med is None else f"{first_med:.0f}"
        tm = "n/a" if third_med is None else f"{third_med:.0f}"
        fa = "n/a" if first_act is None else f"{first_act:.0f}"
        ta = "n/a" if third_act is None else f"{third_act:.0f}"
        print(f"1st theme: calendar day {fm} / active day {fa} ({first_pct:.1f} %)")
        print(f"3rd theme: calendar day {tm} / active day {ta} ({third_pct:.1f} %; daily players >=20/30 days: {daily_pct:.1f} %)")
        print(f"median coins after 7th active day: {med(res['coins_active7']):.0f}")
        parts = ", ".join(f"{k} {v:.2f}" for k, v in by_place.items())
        print(f"ads/DAU: interstitial {inter_dau:.2f}, rewarded {rew_dau:.2f} ({parts}), total {imp_dau:.2f}")
        print(f"players with a negative balance: {neg_pct:.2f} %  (sessions/DAU {out['sessions_per_dau']})")
        if inter_dau > 2.5:
            print("WARN interstitials/DAU > 2.5")
        if imp_dau < 3.0:
            print("WARN impressions/DAU < 3.0")
        print("RESULT: " + ("OK" if not problems else "FAIL"))
        for p in problems:
            print("  - " + p)
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
