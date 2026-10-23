# Status projektu

## Aktualna faza
**Faza 4 — Pipeline wydań** (od 2026-10-23; Faza 1 zamknięta: GDD `APPROVED` + backlog MVP, PR #11/#12; Faza 2 zamknięta: T-001 zmergowane, CI zielone, PR #13; Faza 3 zamknięta: grywalny core loop end-to-end, PR #26–#42, `make playtest` 200/200 rund bez softlocka (solver i random), 231 testów gdUnit4)

Faza 4 bez sekretów: podbicie akcji CI, `Gemfile.lock`, monotoniczny `version_code`, pluginy IAP (T-047/T-048), niepodpisane buildy Android/iOS w CI (dry-run exportów), font z diakrytykami, screenshoty i metadata sklepowe EN/PL/DE, polityka prywatności i odpowiedzi Data Safety / Privacy Labels; `blocked` do czasu kont z tabeli niżej: podpisany AAB na Play Internal, build na TestFlight, QA na urządzeniu i Firebase Test Lab (T-054) — czyli samo kryterium wyjścia z fazy.

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
