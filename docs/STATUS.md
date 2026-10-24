# Status projektu

## Aktualna faza
**Faza 4 — Pipeline wydań** (od 2026-10-23; Faza 1 zamknięta: GDD `APPROVED` + backlog MVP, PR #11/#12; Faza 2 zamknięta: T-001 zmergowane, CI zielone, PR #13; Faza 3 zamknięta: grywalny core loop end-to-end, PR #26–#42, `make playtest` 200/200 rund bez softlocka (solver i random), 231 testów gdUnit4)

Stan Fazy 4 (2026-10-24):
- Zrobione bez sekretów (PR w review/auto-merge): `Gemfile.lock` (T-004, #45), `tools/version_code.sh` (T-002 cz. 1, #46), font z diakrytykami (T-040, #47), tryb `--screenshot` (T-003, #48), screenshoty sklepowe 5×EN/PL/DE (T-050, #49), nieprzezroczyste panele (T-060, #50), metadata Play/ASC EN/PL/DE (T-051, #51), polityka prywatności DRAFT + Data Safety / Privacy Labels (T-052, #52). Wcześniej: akcje CI 5/12 (T-011, #44).
- Czeka na Huberta (sesja interaktywna — sesja scheduled nie edytuje `.github/workflows/**` i nie pobiera z GitHub Releases): workflowy T-002b, T-005, T-053, T-055; pluginy IAP T-047, T-048 (pobranie zip + SHA-256); publikacja i przegląd prawny polityki prywatności; konta z tabeli niżej → T-054 (podpisany AAB na Play Internal, TestFlight, QA na urządzeniu, Firebase Test Lab) — czyli samo kryterium wyjścia z fazy. Checklista: `docs/SETUP_HUBERT.md` (aktualizacja w T-065).

**Decyzja (refill #3, 2026-10-24): faza pozostaje „Faza 4”; nie wprowadzamy „Fazy 4b”.** Uzasadnienie: kryterium wyjścia (AAB na Play Internal + TestFlight) jest niezmienione i zależy wyłącznie od kont Huberta, więc nowa nazwa fazy nie zmieniłaby żadnej bramki, a sugerowałaby postęp, którego nie ma. Formalne przejście do Fazy 5 następuje dopiero po T-054.

Sesja #6 (2026-10-24, continuous-dev): paczka „Faza 5 prep” wyczerpana — ConsentFlow + `FakeConsentProvider` (T-062, #55), bramka reklam do `finished` + „Opcje prywatności” w Settings (T-063, #56), `game/ios/PrivacyInfo.xcprivacy` + test (T-064, #57), fixture pre-win (T-057, #58), warstwy przycięte do probówki (T-056, #59), odstępy karty Poziomu dnia + 15 PNG (T-061, #60), `SETUP_HUBERT.md` sekcja Fazy 4 (T-065), Shop jako overlay (T-049), audio UI/reklam (T-041) — PR #61–#63, auto-merge. Testy: 264 → 284 gdUnit4, 29 tools.

Sesja #7 (2026-10-24, continuous-dev): paczka „Faza 5 prep II” P1 wykonana w całości — czysty log testów (T-075, #66), PL/DE + test „≠ EN” (T-076, #67), `tube_deselected`/FTUE (T-077, #68), przelew 3-fazowy (T-078, #69), puls + haptyka (T-079, #70), motyw od razu (T-080, #71), serializacja rundy + schema v3 (T-081, #72), wznowienie rundy — G-014 kompletne (T-082, #73); P2: Economy (T-083, #74), bot bez zawyżonych interstitiali (T-084, #75). Testy: 284 → 338 gdUnit4. P2 domknięte w sesji #8 (T-085), po czym refill #5.

Sesja #8 (2026-10-24, continuous-dev): błąd `request_consent_info_update` w ConsentFlow → `consent:ump:error` i start niespersonalizowany (T-085, PR #76, auto-merge; 342 gdUnit4) — paczka refill #4 wyczerpana (T-074…T-085). Refill #5 (game-designer): T-075…T-084 przeniesione do Done (PR #66–#75), 10 nowych zadań (P1: T-093…T-098, P2: T-099…T-102), 7 pozycji Inbox awansowanych (w całości T-091, T-086, T-088, T-090, T-073, T-070; część kodowa T-089), GDD: Analityka (`level_pause`, `level_fail` reason `abandon`, parametry `level_complete`, `tutorial_step`, `nav`, `ads_watchdog`), klucze `confetti_seconds` i `ad_unmute_timeout_seconds`, zdanie w Sesji zgodne z G-014. Faza bez zmian: kryterium wyjścia z Fazy 4 (T-054: AAB na Play Internal + TestFlight) nadal wymaga kont Huberta, a żadne zadanie refillu go nie dotyka.

Następna paczka (refill #5, P1/P2): **„Faza 5 prep III: wiarygodna analityka, brakujące elementy MVP, odporność zapisu”** — P1: pauza ≠ porażka i `level:fail:abandon` (T-093), parametry `level_complete` z czasem rundy (T-094), lejek FTUE `tutorial:step:<n>` (T-095), komunikat „+1 kolor”/postęp motywu na LevelComplete (T-096), konfetti (T-097), odporność `schema_version`/`min_moves` (T-098); P2: watchdog odciszenia po reklamie (T-099), ponowna personalizacja po „Opcjach prywatności” (T-100), refaktor `LevelOffers` (T-101), PL „seria” zamiast „streak” (T-102). Uzasadnienie kolejności: przed soft launchem (Faza 6, decyzja skaluj/pivot po 4 tygodniach) reguły decyzyjne z `KPI.md` (D1 < 25 % → FTUE) są ślepe bez lejka tutorialu i rzetelnego fail-rate — po G-014 każda pauza zaniżałaby win-rate jako `quit`; następnie dwa brakujące elementy MVP z GDD (hook sesji „+1 kolor”/pasek motywu, konfetti) wspierające D1 ≥ 35 %; P2 to odporność ścieżek reklamowych/consent przed podpięciem prawdziwych SDK w Fazie 5 i refaktor po zamknięciu zmian w `level.gd` (T-093…T-097 dotykają tego pliku, więc T-101 idzie po nich).

Poprzednia paczka (refill #4, P1/P2, wykonana): **„Faza 5 prep II: jakość zapisu, polish core loopu, FTUE, czysty log CI”** — odporny `GameState.from_dict` (T-074), czysty log testów (T-075), tłumaczenia PL/DE + test „≠ EN” (T-076), `tube_deselected` + test tutorialu (T-077), pełna animacja przelewu i puls/haptyka (T-078, T-079), motyw stosowany od razu (T-080), wznowienie przerwanej rundy — mechanika awansowana do MVP jako G-014 (T-081, T-082); P2: Economy drobiazgi (T-083), raport bota bez zawyżonych interstitiali (T-084), błąd UMP w ConsentFlow (T-085). Uzasadnienie kolejności: utrata postępu i przerwana runda bezpośrednio obniżają D1 (cel ≥ 35 %), polish przelewu i FTUE to pierwsze 2 minuty gry; wiarygodność `make playtest`/`make sim` potrzebna do szacunku ARPDAU przed soft launchem.

Prace równoległe bez kont (Faza 5 prep, sesje #5–#6): bramka `make test-tools` w `make check` (T-034), zgoda UMP/ATT jako logika + `FakeConsentProvider` i „Opcje prywatności” w Settings (T-062, T-063), `PrivacyInfo.xcprivacy` jako plik źródłowy (T-064), polish kadrów sklepowych i regeneracja screenshotów (T-057, T-056, T-061), Shop jako overlay (T-049), audio UI/reklam (T-041), dokumentacja kroków ręcznych (T-065). Zasada: nic, co wymaga workflowów, binarek z GitHub Releases lub kont — takie zadania od razu `blocked` z powodem.

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
