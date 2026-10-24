# Status projektu

## Aktualna faza
**Faza 4 — Pipeline wydań** (od 2026-10-23; Faza 1 zamknięta: GDD `APPROVED` + backlog MVP, PR #11/#12; Faza 2 zamknięta: T-001 zmergowane, CI zielone, PR #13; Faza 3 zamknięta: grywalny core loop end-to-end, PR #26–#42, `make playtest` 200/200 rund bez softlocka (solver i random), 231 testów gdUnit4)

Stan Fazy 4 (2026-10-24):
- Zrobione bez sekretów (PR w review/auto-merge): `Gemfile.lock` (T-004, #45), `tools/version_code.sh` (T-002 cz. 1, #46), font z diakrytykami (T-040, #47), tryb `--screenshot` (T-003, #48), screenshoty sklepowe 5×EN/PL/DE (T-050, #49), nieprzezroczyste panele (T-060, #50), metadata Play/ASC EN/PL/DE (T-051, #51), polityka prywatności DRAFT + Data Safety / Privacy Labels (T-052, #52). Wcześniej: akcje CI 5/12 (T-011, #44).
- Czeka na Huberta (sesja interaktywna — sesja scheduled nie edytuje `.github/workflows/**` i nie pobiera z GitHub Releases): workflowy T-002b, T-005, T-053, T-055; pluginy IAP T-047, T-048 (pobranie zip + SHA-256); publikacja i przegląd prawny polityki prywatności; konta z tabeli niżej → T-054 (podpisany AAB na Play Internal, TestFlight, QA na urządzeniu, Firebase Test Lab) — czyli samo kryterium wyjścia z fazy. Checklista: `docs/SETUP_HUBERT.md` (aktualizacja w T-065).

**Decyzja (refill #3, 2026-10-24): faza pozostaje „Faza 4”; nie wprowadzamy „Fazy 4b”.** Uzasadnienie: kryterium wyjścia (AAB na Play Internal + TestFlight) jest niezmienione i zależy wyłącznie od kont Huberta, więc nowa nazwa fazy nie zmieniłaby żadnej bramki, a sugerowałaby postęp, którego nie ma. Formalne przejście do Fazy 5 następuje dopiero po T-054.

Prace równoległe bez kont (Faza 5 prep, w backlogu P1): bramka `make test-tools` w `make check` (T-034), zgoda UMP/ATT jako logika + `FakeConsentProvider` i „Opcje prywatności” w Settings (T-062, T-063), `PrivacyInfo.xcprivacy` jako plik źródłowy (T-064), polish kadrów sklepowych i regeneracja screenshotów (T-057, T-056, T-061), Shop jako overlay (T-049), audio UI/reklam (T-041), dokumentacja kroków ręcznych (T-065). Zasada: nic, co wymaga workflowów, binarek z GitHub Releases lub kont — takie zadania od razu `blocked` z powodem.

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
