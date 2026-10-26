# EXPERIMENTS

Plan eksperymentów A/B (EXP-001…EXP-004 = H1…H4 z `docs/MONETIZATION.md`; EXP-005 — meta/D7, przegląd 2026-W43). Format wg skilla `analytics-review` (A5). Testy A/B działają od Fazy 6 (ADR-004); wcześniej = porównanie kohort przed/po (nie A/B). Paczki wariantu B: `docs/remote_config/<nazwa>.json` (`remote_config_variant` = nazwa pliku). Spójność paczek, linii `- Paczka:` i tabeli „Równolegle” sprawdza `tools/test_experiments.py` (T-319). Wszystkie: podział 50/50, wariant A = `default.json` (`DEFAULTS` po T-198).

## Wspólne reguły
- Guardraile (każdy EXP): D1 wariantu B nie spada o > 2 pp vs A (KPI cel 35 %, kill-line 25 %); ARPDAU B nie niższe niż A (cel 0,05 USD, kill-line 0,02); crash-free B >= 99,5 % (kill-line 99,0 %). Naruszenie guardrailu = zatrzymanie testu i powrót do A.
- Czas >= 14 dni na wariant; nie zatrzymuj wcześniej poza guardrailem; nie "podglądaj" wyniku do decyzji. DAU < 100 = "za mała próbka" (A2).
- Próbka (α = 0,05 dwustronnie, moc 0,8): proporcje n/wariant = (1,96 + 0,84)² × [p₁(1 − p₁) + p₂(1 − p₂)] / Δ²; zmienna ciągła n = 2 × (1,96 + 0,84)² × σ² / Δ².
- Jednostka = zainstalowany gracz kohorty (instalacje, nie DAU). Progi guardraili służą jako reguła stopu; ich moc nie jest liczona osobno.

## Policzone próbki (python3, wzór wyżej)
| metryka | p₁ → p₂ (Δ) | n/wariant | instalacje łącznie |
|---|---|---|---|
| D7 retention | 12 % → 14 % (2 pp) | 4 430 | 8 860 |
| D1 retention | 35 % → 37 % (2 pp) | 9 028 | 18 056 |
| IAP conversion | 1,5 % → 2,0 % (0,5 pp) | 10 780 | 21 560 |
| Impresje/DAU (ciągła) | Δ = 0,3 impr./DAU | 1 724 gracz-dni przy σ = 3,15 | 3 448 gracz-dni |

Impresje/DAU: σ = 3,15 impresji na gracz-dzień aktywny (`impressions_per_player_day.sd` z `python3 tools/balance_sim.py --players 5000 --seed 1 --json`, `DEFAULTS`, n = 23 039 gracz-dni; T-209) - σ z modelu, ZWERYFIKUJ na danych GA. Wzór: n = 2 × (1,96 + 0,84)² × σ² / Δ² = 2 × 7,84 × 3,145² / 0,3² = 1 724 gracz-dni/wariant (jednostka to gracz-dzień, nie instalacja: gracz daje kilka dni, więc instalacji potrzeba mniej, ale dni tego samego gracza są skorelowane - traktuj 1 724 jako dolną ocenę dni, ZWERYFIKUJ).

## Ruch potrzebny (łącznie 2 warianty, 50/50)
Dni = ceil(instalacje łącznie / instalacje dziennie) + okno obserwacji (D7: +7, D1: +1, IAP: +7 okno zakupu), minimum 14 dni zbierania.

| eksperyment (metryka główna) | instal./wariant | 300/dzień | 1000/dzień | 3000/dzień |
|---|---|---|---|---|
| EXP-004 / D7 | 4 430 | 30 + 7 = 37 d | 14 + 7 = 21 d | 14 + 7 = 21 d |
| D1 (guardrail EXP-002) | 9 028 | 61 + 1 = 62 d | 19 + 1 = 20 d | 14 + 1 = 15 d |
| EXP-003 / IAP conv | 10 780 | 72 + 7 = 79 d | 22 + 7 = 29 d | 14 + 7 = 21 d |
| EXP-001, EXP-002 / impresje (σ = 3,15 z sim, ZWERYFIKUJ; gracz-dni) | 1 724 | 14 d | 14 d | 14 d |

## Kolejność
1. EXP-001 (H1) + EXP-002 (H2): tanie (impresje), mogą iść równolegle. EXP-002 jest też strażnikiem D1 (patrz tabela).
2. EXP-003 (H3, IAP) po zakończeniu EXP-001 lub przy >= 1000 instalacji/dzień; EXP-004 (H4) ostatni, wymaga pełnych kohort D7 (>= 14 dni + 7).
3. Przy < 1000 instalacji/dzień maks. 2 eksperymenty równolegle; parametry nie mogą się nakładać na ten sam ekran/placement (H1 i H2 to różne parametry: OK). Użytkownik jest w jednym eksperymencie naraz tam, gdzie to możliwe.
4. EXP-005 (notyfikacja „powrót”, D7) po EXP-004 albo równolegle z EXP-001/EXP-002 — nigdy równolegle z EXP-004 (ta sama metryka główna D7); wymaga pluginu notyfikacji (Faza 5, ADR-012) i paczki `h5_comeback_2` (T-284).

## Równolegle
Format (parsuje `tools/test_experiments.py`): wiersz `| EXP-A | EXP-B | tak |` = dozwolone równolegle (zbiory kluczy paczek muszą być rozłączne); `| EXP-A | EXP-B | nie — powód |` = zakaz. Pary spoza tabeli: wg „Kolejność”.

| EXP A | EXP B | Równolegle |
|---|---|---|
| EXP-001 | EXP-002 | tak |
| EXP-005 | EXP-001 | tak |
| EXP-005 | EXP-002 | tak |
| EXP-004 | EXP-005 | nie — ta sama metryka główna D7 |

## EXP-001: Mnożnik nagrody `double_coins` ×3 (H1)
- Data startu: do ustalenia (Faza 6) · Status: planned
- Hipoteza: Jeśli zwiększymy `rewarded_multiplier` z 2.0 do 3.0, odsetek obejrzanych reklam i impresje/DAU wzrosną, a inflacja monet nie obniży D7.
- Parametr: `rewarded_multiplier` · paczka `h1_b`
- Paczka: h1_b.json
- Warianty: A 2.0 · B 3.0 · 50/50
- Metryka główna: Ad impressions / DAU (cel >= 3,0); kontrolnie D7 >= 12 %. Sim (seed 1, 5000 graczy) przewiduje 4.35 vs 4.42 total (CI 4.309–4.389 vs 4.375–4.456 nakładają się - w szumie, brak wzrostu w modelu), więc sygnał nie jest oczekiwany z sim.
- Guardraile: D1 −2 pp, ARPDAU, crash-free (wspólne)
- Min. próbka: 1 724 gracz-dni/wariant przy σ = 3,15 (σ z modelu - ZWERYFIKUJ na danych GA); D7 guardrail: czytaj kohortę, 4 430/wariant dla pełnej mocy
- Czas: >= 14 dni
- Decyzja: wdrożyć B, jeśli impresje/DAU +0,3 przy braku regresji D7 (< 1 pp) i guardrailach; inaczej A
- Wynik: (puste)

## EXP-002: Gęstszy interstitial (H2)
- Data startu: do ustalenia · Status: planned
- Hipoteza: Jeśli interstitial pojawia się co 4 rundy (min 90 s, od poziomu 5) zamiast 5/120/8, impresje/DAU wzrosną bez spadku D1.
- Parametry: `interstitial_every_n_rounds`, `interstitial_min_seconds`, `interstitial_min_level` · paczka `h2_b`
- Paczka: h2_b.json
- Warianty: A 5 / 120 / 8 · B 4 / 90 / 5 · 50/50
- Metryka główna: Ad impressions / DAU (cel >= 3,0); guardrail twardy: D1 >= 35 % i −2 pp. Sim (seed 1, 5000 graczy): 4.86 vs 4.42 total (CI 4.813–4.899 vs 4.375–4.456, rozłączne).
- Guardraile: D1 −2 pp (kluczowy, bo interstitial w pierwszej sesji), ARPDAU, crash-free
- Min. próbka: 1 724 gracz-dni/wariant (impresje, σ = 3,15 z sim, ZWERYFIKUJ); D1 guardrail: 9 028/wariant dla mocy 0,8 na Δ = 2 pp
- Czas: >= 14 dni
- Decyzja: wdrożyć B, jeśli impresje/DAU rosną, D1 nie spada o > 2 pp i ARPDAU rośnie; inaczej A
- Wynik: (puste)

## EXP-003: Wcześniejsza oferta `starter_pack` (H3)
- Data startu: do ustalenia · Status: planned
- Hipoteza: Jeśli oferta `starter_pack` pojawia się po poziomie 6 zamiast 12, konwersja IAP wzrośnie.
- Parametr: `starter_offer_min_level` · paczka `h3_b`
- Paczka: h3_b.json
- Warianty: A 12 · B 6 · 50/50 (sim tego nie modeluje)
- Metryka główna: IAP conversion (cel >= 1,5 %), próg efektu 1,5 % → 2,0 %
- Guardraile: D1 −2 pp, ARPDAU, crash-free; dodatkowo odsetek zwrotów/ocen sklepu
- Min. próbka: 10 780/wariant (21 560 instalacji)
- Czas: >= 14 dni + 7 dni okna zakupu
- Decyzja: wdrożyć B, jeśli IAP conv >= 2,0 % (lub różnica istotna, p < 0,05) bez regresji; inaczej A
- Wynik: (puste)

## EXP-004: Pomoc na plateau od 3. próby (H4)
- Data startu: do ustalenia · Status: planned
- Hipoteza: Jeśli pomoc plateau zaczyna się od 3. próby (zamiast 2.), jest mniej natrętna (`level:assist:*`/DAU niżej) bez utraty D7 kohorty 56+ (T-187: 46,0 % vs 34,4 %, górna granica z botem). Sim nie daje argumentu ekonomii: baza 26/2 ma więcej rewarded (3.05 vs 2.84/DAU) i porównywalne monety (d30 565 vs 555), więc EXP-004 testuje wyłącznie natrętność vs D7.
- Parametr: `plateau_assist_from_attempt` · paczka `h4_assist_3`
- Paczka: h4_assist_3.json
- Warianty: A 2 (default od T-198) · B 3 · 50/50
- Metryka główna: D7 kohorty (cel >= 12 %); drugorzędne: `level:assist:*`/DAU, rewarded/DAU. Sim (seed 1, 5000 graczy): ARPDAU ok. −5 % w B (total 4.42 → 4.20, CI rozłączne).
- Guardraile: D1 −2 pp, ARPDAU, crash-free
- Min. próbka: 4 430/wariant (D7 12 → 14 %; kohorta 56+ jest mniejsza, więc dłużej lub analiza całej populacji)
- Czas: >= 14 dni + 7 dni na pełne kohorty D7
- Decyzja: B tylko gdy D7 nie spada istotnie, D1 i natrętność się poprawiają, ARPDAU nie spada > 5 %; inaczej A
- Wynik: (puste)

## EXP-005: Notyfikacja „powrót” w oknie ratowania serii (D7, meta)
- Data startu: do ustalenia (Faza 6; wcześniej porównanie kohort przed/po, nie A/B) · Status: planned
- Hipoteza: Jeśli skrócimy `notif_comeback_days` z 3 do 2, D7 wzrośnie, bo przypomnienie „powrót” przyjdzie w lokalnym dniu D+2 — gdy powracający gracz z serią jest jeszcze w stanie grace (`streak_grace_days` = 1) i może ją uratować rewarded `streak_save` — zamiast w D+3, gdy seria jest już zresetowana do 1 (`NotificationPlanner.plan`: wpis `comeback` = `local_day + notif_comeback_days`; `DailyRewards`: grace gdy `utc_day − last − 1 ≤ streak_grace_days`).
- Parametr (remote config / GameConfig): `notif_comeback_days` (`RANGES` 2..14) · paczka `h5_comeback_2` gotowa (T-284)
- Paczka: h5_comeback_2.json
- Warianty: A (kontrola) 3 · B 2 · podział 50/50
- Metryka główna: D7 retention kohorty (KPI.md, cel ≥ 12 %, kill-line 8 %); drugorzędne: `streak:saved` / DAU i `ads:rewarded:streak_save:*` / DAU (dźwignia, której dotyczy hipoteza), `notif:scheduled:comeback` / DAU (kontrola ekspozycji); guardraile: wspólne (D1 −2 pp, ARPDAU, crash-free) + opt-out powiadomień `settings:notifications:off` / DAU w B ≤ A + 1 pp (event z T-284).
- Min. próbka: >= 4 430 instalacji/wariant (D7 12 % → 14 %, tabela „Policzone próbki”) lub 14 dni + 7 dni na pełne kohorty D7; efekt dotyczy tylko graczy ze zgodą na notyfikacje (`notif:permission:granted` albo `not_required`) — analiza główna na całej kohorcie (intent-to-treat), podgrupa ze zgodą raportowana osobno; zatrzymaj wcześniej tylko przy guardrailu.
- Czas: >= 14 dni zbierania + 7 dni obserwacji D7 (przy 300 instal./dzień ok. 37 dni — tabela „Ruch potrzebny”, wiersz D7).
- Decyzja po teście: wdrożyć B (`DEFAULTS` `notif_comeback_days` = 2), jeśli D7 +≥ 2 pp (lub różnica istotna, p < 0,05) bez naruszenia guardraili i opt-out B ≤ A + 1 pp; inaczej zostaw A. Przed Fazą 6 (bez Remote Config A/B): zmiana w `DEFAULTS` i porównanie tygodniowych kohort D7 przed/po (to NIE jest A/B — sezonowość i mix ruchu zaburzają wynik; decyzja tylko przy różnicy ≥ 2 pp w 2 kolejnych kohortach).
- Wynik: (puste)
