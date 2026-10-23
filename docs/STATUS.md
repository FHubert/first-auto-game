# Status projektu

## Aktualna faza
**Faza 1 — Research i koncepcja** (od 2026-10-23)

Wybrany gatunek: sort puzzle (ball/water sort z progresją poziomów, content proceduralny + solver) — decyzja 2026-10-23 (R-001, docs/RESEARCH.md)

Fazy:
1. Research i koncepcja → wyjście: GDD `APPROVED`, backlog MVP
2. Szkielet i pętla → wyjście: T-001 zmergowane, CI zielone
3. Vertical slice → wyjście: grywalny core loop, bot przechodzi 200 tur bez softlocka
4. Pipeline wydań → wyjście: AAB na Play Internal, build na TestFlight
5. Monetyzacja i analityka → wyjście: eventy GA w dashboardzie, rewarded działa na urządzeniu
6. Soft launch → wyjście: 4 tygodnie danych w KPI.md, decyzja skaluj/pivot
7. Scale / live ops / gra nr 2

## Blokery wymagające Huberta
Patrz `docs/SETUP_HUBERT.md` — lista jednorazowych kroków ręcznych i ich status.

| Krok | Status |
|---|---|
| Repo GitHub + Claude Code Remote environment | ⬜ |
| Google Play Developer (konto firmowe All In IT) | ⬜ |
| Apple Developer Program | ⬜ |
| AdMob app IDs + ad units | ⬜ |
| GameAnalytics game keys | ⬜ |
| Keystore Android w GitHub Secrets | ⬜ |
| App Store Connect API key + match repo | ⬜ |
| Firebase Remote Config (opcjonalne, Faza 6) | ⬜ |
