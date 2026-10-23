#!/usr/bin/env python3
"""Offline economy simulation (no Godot needed).

Reads balance parameters from the DEFAULTS dictionary in game/src/systems/config.gd
(keys it recognises override the built-ins below; unknown keys are ignored) and simulates
N players over D days:
  * daily activity follows a retention curve (D0=1, D1, D7, D30 interpolated log-linearly),
  * sessions/day ~ Poisson, per-player engagement multiplier,
  * each round is won with a probability that falls with the player's level (difficulty_curve),
  * coins are earned on rounds, optionally doubled by rewarded ads, spent on continues and shop items.

Exit code 1 when the economy
  * "explodes": median coins after the last day > 100x median coins after day 1, or
  * "starves": median purchases by day 7 < 1, or
  * produces any negative balance.
Statistics are taken over *engaged* players (active on >= 2 of the first 7 days), because the
economy only matters for players who stay.

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
    "starting_coins": 0,
    "daily_reward_base": 50,
    "win_reward_coins": 10,
    "rewarded_multiplier": 2.0,
    "interstitial_every_n_rounds": 3,
    "difficulty_min": 0.1,
    "difficulty_max": 1.0,
    "difficulty_midpoint_level": 20,
    "difficulty_steepness": 0.15,
    # --- simulation-only model parameters ---
    "win_prob_easy": 0.90,  # win probability at difficulty 0
    "win_prob_hard": 0.35,  # win probability at difficulty 1
    "sessions_per_day": 3.0,
    "rounds_per_session": 8,
    "wins_per_level": 6,
    "coins_per_loss": 2,
    "coins_per_level_bonus": 1,
    "continue_cost": 20,  # sink: pay to retry after a loss
    "continue_take_rate": 0.30,
    "shop_base_price": 60,
    "shop_price_growth": 1.12,
    "shop_buy_rate": 0.70,  # chance a player buys when affordable at session end
    "rewarded_offers_per_session": 2.0,
    "rewarded_watch_rate": 0.45,
    "rewarded_completion_rate": 0.90,
    "retention_d1": 0.38,
    "retention_d7": 0.14,
    "retention_d30": 0.05,
}


def load_config(path: Path) -> tuple[dict, list[str]]:
    cfg = dict(BUILTIN)
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
    for key, val in re.findall(r"[\"']([A-Za-z_][\w]*)[\"']\s*:\s*(-?\d+(?:\.\d+)?)", m.group(1)):
        if key in cfg:
            cfg[key] = float(val) if "." in val else int(val)
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


def simulate(cfg: dict, players: int, days: int, seed: int) -> dict:
    rnd = random.Random(seed)
    coins_by_day = [[] for _ in range(days)]  # per day: balances of engaged players
    purchases_d7: list[int] = []
    negative_players = 0
    engaged = 0
    active_days = 0
    ad_impressions = 0.0
    rewarded_started = rewarded_completed = 0
    sessions_total = 0

    for _ in range(players):
        engagement = max(0.3, rnd.lognormvariate(0.0, 0.35))
        coins = cfg["starting_coins"]
        wins = purchases = 0
        activity = [rnd.random() < retention_at(cfg, d) for d in range(days)]
        activity[0] = True
        is_engaged = sum(activity[:7]) >= 2
        purchases_at_7 = 0
        went_negative = False
        balances = []
        for day in range(days):
            if activity[day]:
                active_days += 1
                n_sessions = max(1, poisson(rnd, cfg["sessions_per_day"] * engagement))
                sessions_total += n_sessions
                coins += int(cfg["daily_reward_base"])
                for _s in range(n_sessions):
                    rounds_played = 0
                    for _r in range(int(cfg["rounds_per_session"])):
                        level = 1 + wins // int(cfg["wins_per_level"])
                        rounds_played += 1
                        if rnd.random() < win_probability(cfg, level):
                            wins += 1
                            earn = cfg["win_reward_coins"] + cfg["coins_per_level_bonus"] * level
                            if rnd.random() < cfg["rewarded_offers_per_session"] / cfg["rounds_per_session"]:
                                if rnd.random() < cfg["rewarded_watch_rate"]:
                                    rewarded_started += 1
                                    if rnd.random() < cfg["rewarded_completion_rate"]:
                                        rewarded_completed += 1
                                        ad_impressions += 1
                                        earn *= cfg["rewarded_multiplier"]
                            coins += int(earn)
                        else:
                            coins += int(cfg["coins_per_loss"])
                            if coins >= cfg["continue_cost"] and rnd.random() < cfg["continue_take_rate"]:
                                coins -= int(cfg["continue_cost"])
                        if cfg["interstitial_every_n_rounds"] and rounds_played % int(cfg["interstitial_every_n_rounds"]) == 0:
                            ad_impressions += 1
                    price = int(cfg["shop_base_price"] * cfg["shop_price_growth"] ** purchases)
                    if coins >= price and rnd.random() < cfg["shop_buy_rate"]:
                        coins -= price
                        purchases += 1
                if coins < 0:
                    went_negative = True
            balances.append(coins)
            if day == 6:
                purchases_at_7 = purchases
        if is_engaged:
            engaged += 1
            purchases_d7.append(purchases_at_7)
            for d in range(days):
                coins_by_day[d].append(balances[d])
        negative_players += went_negative

    return {
        "engaged": engaged,
        "coins_by_day": coins_by_day,
        "purchases_d7": purchases_d7,
        "negative_players": negative_players,
        "players": players,
        "active_days": active_days,
        "ad_impressions": ad_impressions,
        "sessions": sessions_total,
        "rewarded_started": rewarded_started,
        "rewarded_completed": rewarded_completed,
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
    med_purchases_d7 = med(res["purchases_d7"])
    neg_pct = 100.0 * res["negative_players"] / max(1, res["players"])
    imp_dau = res["ad_impressions"] / max(1, res["active_days"])

    problems = []
    if last > 100 * max(day1, 1):
        problems.append(f"economy explodes: median coins day {args.days} ({last:.0f}) > 100x day 1 ({day1:.0f})")
    if med_purchases_d7 < 1:
        problems.append(f"economy starves: median purchases by day 7 = {med_purchases_d7:.1f} (< 1)")
    if res["negative_players"] > 0:
        problems.append(f"negative balances: {neg_pct:.2f} % of players (must be 0)")

    out = {
        "players": args.players,
        "days": args.days,
        "seed": args.seed,
        "engaged_players": res["engaged"],
        "median_coins_day1": day1,
        "median_coins_day7": day7,
        f"median_coins_day{args.days}": last,
        "median_purchases_day7": med_purchases_d7,
        "negative_balance_pct": round(neg_pct, 3),
        "est_ad_imp_per_dau": round(imp_dau, 2),
        "sessions_per_dau": round(res["sessions"] / max(1, res["active_days"]), 2),
        "rewarded_completion": round(res["rewarded_completed"] / max(1, res["rewarded_started"]), 3),
        "ok": not problems,
        "problems": problems,
    }
    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"players={args.players} days={args.days} seed={args.seed} engaged={res['engaged']}")
        print(f"median coins: day1={day1:.0f}  day7={day7:.0f}  day{args.days}={last:.0f}")
        print(f"median purchases by day 7: {med_purchases_d7:.1f}")
        print(f"players with a negative balance: {neg_pct:.2f} %")
        print(f"est. ad impressions / DAU: {imp_dau:.2f}  (sessions/DAU {out['sessions_per_dau']})")
        print("RESULT: " + ("OK" if not problems else "FAIL"))
        for p in problems:
            print("  - " + p)
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
