#!/usr/bin/env python3
"""Pull weekly game KPIs and append them to the "## Aktualne" table in KPI.md.

Sources (stdlib only):
  * GameAnalytics  -> --ga-csv export (DAU, retention, sessions, rewarded events, IAP);
                      GameAnalyticsClient is a stub for the Metrics API (see TODO).
  * AdMob          -> Reporting API (mediationReport:generate), OAuth refresh-token flow;
                      stub with the correct endpoint, enabled when ADMOB_* env vars are set.
  * Play Console   -> crash-free sessions (Play Developer Reporting API), stub.

Usage:
  python3 tools/metrics_pull.py --dry-run [--kpi-path /tmp/kpi.md]
  python3 tools/metrics_pull.py --ga-csv export.csv [--week 2026-W43]

Expected --ga-csv columns (one row per day; extra columns ignored):
  date,dau,sessions,d1_retention,d7_retention,d30_retention,ad_impressions,
  rewarded_started,rewarded_completed,iap_buyers,iap_revenue_usd,crash_free
Retention may be a fraction (0.35) or a percent (35). Rows are aggregated over the ISO week.
The resulting JSON is printed on stdout; logs go to stderr.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import random
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parent.parent
TABLE_HEADER = (
    "| Tydzień | DAU | D1 | D7 | D30 | Ses/DAU | AdImp/DAU | RewComp | ARPDAU | IAP conv | Crash-free |"
)


def log(msg: str) -> None:
    print(f"[metrics_pull] {msg}", file=sys.stderr)


# --------------------------------------------------------------------------- data model


@dataclass
class RawWeek:
    """Raw weekly aggregates from all sources (None = source unavailable)."""

    week: str
    dau: float = 0.0  # mean DAU over the week
    dau_days: int = 0
    sessions: float = 0.0  # total sessions in the week
    dau_sum: float = 0.0  # sum of daily DAU (denominator for per-DAU ratios)
    d1: Optional[float] = None  # fractions 0..1
    d7: Optional[float] = None
    d30: Optional[float] = None
    ad_impressions: Optional[float] = None
    ad_revenue_usd: float = 0.0
    iap_revenue_usd: float = 0.0
    rewarded_started: float = 0.0
    rewarded_completed: float = 0.0
    iap_buyers: float = 0.0
    crash_free: Optional[float] = None  # fraction 0..1
    sources: list = field(default_factory=list)


def iso_week(day: dt.date) -> str:
    y, w, _ = day.isocalendar()
    return f"{y}-W{w:02d}"


def week_bounds(week: str) -> tuple[dt.date, dt.date]:
    y, w = week.split("-W")
    start = dt.date.fromisocalendar(int(y), int(w), 1)
    return start, start + dt.timedelta(days=6)


# --------------------------------------------------------------------------- sources


class GameAnalyticsClient:
    """Stub for the GameAnalytics Metrics API.

    The API exists (PipelineIQ "Metrics API"): base https://metrics.gameanalytics.com,
    header `X-API-Key` (created in Organization settings), per-metric endpoints under
    /metrics/v1/metrics/<metric> with a JSON body {interval, granularity, query, game...}.
    Docs: https://docs.gameanalytics.com/products-and-features/pipeline-iq/metrics-api/how-to-use-the-metrics-api
    TODO: confirm which metric names expose DAU / retention (days_since_install) / sessions and
    that the account has API access, then implement fetch_week(). Until then use --ga-csv.
    """

    BASE_URL = "https://metrics.gameanalytics.com"

    def __init__(self, api_key: str, game_id: str) -> None:
        self.api_key = api_key
        self.game_id = game_id

    def fetch_week(self, week: str) -> RawWeek:
        raise NotImplementedError("TODO: GameAnalytics Metrics API (see class docstring); use --ga-csv")


def _num(row: dict, key: str) -> Optional[float]:
    v = (row.get(key) or "").strip().replace(",", ".")
    if v == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def _frac(v: Optional[float]) -> Optional[float]:
    if v is None:
        return None
    return v / 100.0 if v > 1.0 else v


def read_ga_csv(path: Path, week: str) -> RawWeek:
    start, end = week_bounds(week)
    raw = RawWeek(week=week, sources=["ga-csv"])
    ret = {"d1": [], "d7": [], "d30": []}
    crash = []
    ad_imp = 0.0
    saw_ad = False
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            try:
                day = dt.date.fromisoformat((row.get("date") or "").strip()[:10])
            except ValueError:
                continue
            if not (start <= day <= end):
                continue
            dau = _num(row, "dau") or 0.0
            raw.dau_sum += dau
            raw.dau_days += 1
            raw.sessions += _num(row, "sessions") or 0.0
            for k in ret:
                v = _frac(_num(row, f"{k}_retention"))
                if v is not None:
                    ret[k].append(v)
            if _num(row, "ad_impressions") is not None:
                saw_ad = True
                ad_imp += _num(row, "ad_impressions") or 0.0
            raw.rewarded_started += _num(row, "rewarded_started") or 0.0
            raw.rewarded_completed += _num(row, "rewarded_completed") or 0.0
            raw.iap_buyers += _num(row, "iap_buyers") or 0.0
            raw.iap_revenue_usd += _num(row, "iap_revenue_usd") or 0.0
            cf = _frac(_num(row, "crash_free"))
            if cf is not None:
                crash.append(cf)
    if raw.dau_days == 0:
        raise SystemExit(f"No rows for {week} in {path}")
    raw.dau = raw.dau_sum / raw.dau_days
    for k, vals in ret.items():
        setattr(raw, k, sum(vals) / len(vals) if vals else None)
    raw.ad_impressions = ad_imp if saw_ad else None
    raw.crash_free = sum(crash) / len(crash) if crash else None
    return raw


class AdMobClient:
    """AdMob Reporting API (v1). OAuth2 refresh-token flow, stdlib urllib only.

    Env: ADMOB_REFRESH_TOKEN, ADMOB_CLIENT_ID, ADMOB_CLIENT_SECRET, ADMOB_PUBLISHER_ID (pub-XXXX).
    Scope needed: https://www.googleapis.com/auth/admob.report
    Docs: https://developers.google.com/admob/api/v1/reference/rest/v1/accounts.mediationReport/generate
    TODO: verify against a live account (response is a JSON array of header/row/footer objects;
    mediation report may need the `AD_SOURCE`/`FORMAT` dimension tuned) before trusting numbers.
    """

    TOKEN_URL = "https://oauth2.googleapis.com/token"
    API = "https://admob.googleapis.com/v1"

    def __init__(self, publisher_id: str, client_id: str, client_secret: str, refresh_token: str) -> None:
        self.publisher_id = publisher_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.refresh_token = refresh_token

    @classmethod
    def from_env(cls) -> Optional["AdMobClient"]:
        keys = ("ADMOB_PUBLISHER_ID", "ADMOB_CLIENT_ID", "ADMOB_CLIENT_SECRET", "ADMOB_REFRESH_TOKEN")
        if not all(os.environ.get(k) for k in keys):
            return None
        return cls(*(os.environ[k] for k in keys))

    def _access_token(self) -> str:
        body = urllib.parse.urlencode(
            {
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "refresh_token": self.refresh_token,
                "grant_type": "refresh_token",
            }
        ).encode()
        with urllib.request.urlopen(urllib.request.Request(self.TOKEN_URL, data=body), timeout=30) as r:
            return json.load(r)["access_token"]

    def mediation_report(self, start: dt.date, end: dt.date) -> dict:
        """Returns {'impressions': float, 'revenue_usd': float} for the date range."""
        url = f"{self.API}/accounts/{self.publisher_id}/mediationReport:generate"
        spec = {
            "dateRange": {
                "startDate": {"year": start.year, "month": start.month, "day": start.day},
                "endDate": {"year": end.year, "month": end.month, "day": end.day},
            },
            "metrics": ["IMPRESSIONS", "ESTIMATED_EARNINGS"],
            "dimensions": ["DATE"],
        }
        req = urllib.request.Request(
            url,
            data=json.dumps({"reportSpec": spec}).encode(),
            headers={"Authorization": f"Bearer {self._access_token()}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=60) as r:
            payload = json.load(r)
        imp = rev_micros = 0.0
        for item in payload if isinstance(payload, list) else [payload]:
            m = item.get("row", {}).get("metricValues", {})
            imp += float(m.get("IMPRESSIONS", {}).get("integerValue", 0))
            rev_micros += float(m.get("ESTIMATED_EARNINGS", {}).get("microsValue", 0))
        return {"impressions": imp, "revenue_usd": rev_micros / 1e6}


class PlayCrashClient:
    """Stub: crash-free sessions from the Play Developer Reporting API.

    Endpoint: POST https://playdeveloperreporting.googleapis.com/v1beta1/apps/{package}/crashRateMetricSet:query
    (metrics: userPerceivedCrashRate / crashRate; crash-free = 1 - rate). Needs the
    `https://www.googleapis.com/auth/playdeveloperreporting` scope on a service account.
    Docs: https://developers.google.com/play/developer/reporting
    TODO: implement with the service-account JWT flow; for now crash-free comes from the CSV
    `crash_free` column, otherwise it is reported as n/a.
    """

    def crash_free(self, start: dt.date, end: dt.date) -> Optional[float]:
        return None


# --------------------------------------------------------------------------- synthetic data


def synthetic_week(week: str) -> RawWeek:
    """Deterministic fake data (seeded by the week) for dry runs and tests."""
    rnd = random.Random(week)
    dau = rnd.randint(800, 1500)
    return RawWeek(
        week=week,
        dau=float(dau),
        dau_days=7,
        dau_sum=float(dau * 7),
        sessions=dau * 7 * rnd.uniform(2.6, 3.4),
        d1=rnd.uniform(0.30, 0.40),
        d7=rnd.uniform(0.09, 0.14),
        d30=rnd.uniform(0.03, 0.05),
        ad_impressions=dau * 7 * rnd.uniform(2.5, 3.5),
        ad_revenue_usd=dau * 7 * rnd.uniform(0.03, 0.05),
        iap_revenue_usd=dau * 7 * rnd.uniform(0.005, 0.015),
        rewarded_started=dau * 7 * 1.5,
        rewarded_completed=dau * 7 * 1.5 * rnd.uniform(0.75, 0.9),
        iap_buyers=dau * rnd.uniform(0.01, 0.02) * 7,
        crash_free=rnd.uniform(0.995, 0.999),
        sources=["synthetic"],
    )


# --------------------------------------------------------------------------- KPIs


def _div(a: Optional[float], b: float) -> Optional[float]:
    return None if a is None or b <= 0 else a / b


def compute_kpis(raw: RawWeek) -> dict:
    total_rev = raw.ad_revenue_usd + raw.iap_revenue_usd
    return {
        "week": raw.week,
        "sources": raw.sources,
        "dau": round(raw.dau),
        "d1": raw.d1,
        "d7": raw.d7,
        "d30": raw.d30,
        "sessions_per_dau": _div(raw.sessions, raw.dau_sum),
        "ad_imp_per_dau": _div(raw.ad_impressions, raw.dau_sum),
        "rewarded_completion": _div(raw.rewarded_completed, raw.rewarded_started),
        "arpdau_usd": _div(total_rev, raw.dau_sum),
        # Share of DAU-days with a purchase (buyers/day summed over the week).
        "iap_conversion": _div(raw.iap_buyers, raw.dau_sum),
        "crash_free": raw.crash_free,
    }


def _pct(v: Optional[float], digits: int = 1) -> str:
    return "n/a" if v is None else f"{v * 100:.{digits}f} %".replace(".", ",")


def _dec(v: Optional[float], digits: int) -> str:
    return "n/a" if v is None else f"{v:.{digits}f}".replace(".", ",")


def format_row(k: dict) -> str:
    cells = [
        k["week"],
        str(k["dau"]),
        _pct(k["d1"]),
        _pct(k["d7"]),
        _pct(k["d30"]),
        _dec(k["sessions_per_dau"], 2),
        _dec(k["ad_imp_per_dau"], 2),
        _pct(k["rewarded_completion"], 0),
        _dec(k["arpdau_usd"], 3),
        _pct(k["iap_conversion"], 2),
        _pct(k["crash_free"]),
    ]
    return "| " + " | ".join(cells) + " |"


def update_kpi_md(path: Path, row: str, week: str) -> str:
    """Insert/replace the row for `week` in the '## Aktualne' table. Returns 'added'|'replaced'."""
    lines = path.read_text(encoding="utf-8").split("\n")
    try:
        sec = next(i for i, l in enumerate(lines) if l.strip() == "## Aktualne")
    except StopIteration:
        raise SystemExit(f"{path}: no '## Aktualne' section")
    end = next((i for i in range(sec + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    hdr = next((i for i in range(sec + 1, end) if lines[i].startswith("| Tydzie")), None)
    if hdr is None:
        raise SystemExit(f"{path}: no table header under '## Aktualne'")
    last = hdr + 1  # separator row
    result = "added"
    for i in range(hdr + 2, end):
        if not lines[i].startswith("|"):
            break
        last = i
        if lines[i].startswith(f"| {week} |"):
            lines[i] = row
            result = "replaced"
            row = None
            break
    if row is not None:
        lines.insert(last + 1, row)
    # Drop the "no data yet" placeholder once there is data.
    lines = [l for l in lines if not l.startswith("_(brak danych")]
    path.write_text("\n".join(lines), encoding="utf-8")
    return result


# --------------------------------------------------------------------------- main


def main(argv: Optional[list] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="use synthetic data (no network)")
    ap.add_argument("--ga-csv", type=Path, help="GameAnalytics CSV export")
    ap.add_argument("--kpi-path", type=Path, default=ROOT / "KPI.md")
    ap.add_argument("--week", help="ISO week YYYY-Www (default: last full week)")
    ap.add_argument("--no-write", action="store_true", help="print JSON only, leave KPI.md untouched")
    ap.add_argument("--package", default="pl.allinit.firstautogame")
    args = ap.parse_args(argv)

    if args.week:
        week = args.week
    else:
        week = iso_week(dt.date.today() - dt.timedelta(days=7))
    start, end = week_bounds(week)

    if args.dry_run:
        raw = synthetic_week(week)
    else:
        if not args.ga_csv:
            log("GameAnalytics Metrics API is not implemented yet: pass --ga-csv <export.csv>")
            return 2
        raw = read_ga_csv(args.ga_csv, week)
        admob = AdMobClient.from_env()
        if admob:
            try:
                rep = admob.mediation_report(start, end)
                raw.ad_revenue_usd = rep["revenue_usd"]
                raw.ad_impressions = rep["impressions"]
                raw.sources.append("admob")
            except (urllib.error.URLError, KeyError, ValueError) as exc:
                log(f"AdMob failed ({exc}); ad revenue/impressions fall back to CSV (revenue 0)")
        else:
            log("ADMOB_* env not set: ad revenue unavailable, ARPDAU counts IAP only")
        if raw.crash_free is None:
            raw.crash_free = PlayCrashClient().crash_free(start, end)
            if raw.crash_free is None:
                log("crash-free unavailable (Play client is a stub, no crash_free column)")

    kpis = compute_kpis(raw)
    if not args.no_write:
        result = update_kpi_md(args.kpi_path, format_row(kpis), week)
        log(f"{args.kpi_path}: row for {week} {result}")
    json.dump(kpis, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
