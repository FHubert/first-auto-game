# DASHBOARD — eventy GA → metryki KPI i kalibracja

Jedno miejsce dla `analytics-review` po soft launchu (Faza 5, kryterium wyjścia „eventy GA w dashboardzie”).
Nazwy w kolumnie „Wzór” to nazwy z `docs/GDD.md` → Analityka (id GA: `track_design("a:b:c")`, w GA rozdzielone `:`);
progi pochodzą wyłącznie z `KPI.md` (Cele i Reguły decyzyjne) oraz z bramek w GDD. Brak danych rynkowych poza tymi plikami.
Strażnik: `tools/test_tools.py::test_every_gdd_event_is_in_dashboard` (każdy event z GDD musi tu wystąpić).

Oznaczenia: DAU = unikalni gracze z `session_start` danego dnia; przedział = `lv1_7` / `lv8_25` / `lv26_55` / `lv56p` (`LevelBrackets`);
„próba” = parametr `attempt` (`GameRound.restarts() + 1`). KPI-n = reguła decyzyjna n z `KPI.md`.

## Tabela metryk

| # | Metryka | Wzór (eventy) | Próg / reguła | Kalibruje |
|---|---|---|---|---|
| 1 | D1 retention | gracze z `session_start` w dniu instalacji+1 / kohorta instalacji (pierwszy `session_start`) | min 25 %, cel 35 % (KPI); < 25 % → KPI-2 | `make playtest` (trudność 1. sesji), `tutorial_step` |
| 2 | D7 retention | jak D1, dzień +7 | min 8 %, cel 12 %; D1 OK i D7 < 8 % → KPI-3 | `plateau_assist_min_level`, `plateau_assist_from_attempt`, paczka H4 (GDD pyt. 12, 18) |
| 3 | Sesje / DAU | `session_start` / DAU (`session_end` z czasem w [s] daje średnią długość sesji) | min 2,0, cel 3,0; długość min 2 min, cel 4 min (KPI) | okno `session:start` na powrót fokusu (`App.track_session_start`) |
| 4 | Fail-rate per przedział | (`level_fail` reason `restart` + `skip` + `abandon`) / `level_start`, z przedziałem z `level:fail:attempt:<przedział>` i `level:fail:abandon:<przedział>` | 1–7 i 8–25 bez porażek w modelu bota (GDD Progresja); wzrost → KPI-2 (1–25) albo KPI-3 (26+); definicja z refillu #5 (BACKLOG, Pytania do Huberta) | `gen_*` (generator), `min_moves_factor_*` |
| 5 | Wygrane w ≤ 3 próbach per przedział | licznik `level:complete:attempt:<przedział>` z wartością ≤ 3 / liczba rund przedziału zamkniętych (te + `level:fail:attempt:<przedział>` z wartością ≤ 3) | bramka T-162/T-175 z GDD Progresja: 56+ ≥ 35 % w ≤ 3 próbach (zmierzone `make playtest --assist`: 46,0 % dla 26/2) | `win_prob_easy` / `win_prob_hard` w `tools/balance_sim.py` (sim-only, `level_attempt`) |
| 6 | P(wygrana w 1. próbie) | `level:complete:attempt:<przedział>`=1 / (to + `level:fail:attempt:<przedział>`=1) | model gracza `win_prob_hard` 0,55 (GDD „Kalibracja po soft launchu”) | `win_prob_hard`, `win_prob_easy` |
| 7 | Take rate pomocy na plateau | (`level:assist:coins` + `level:assist:rewarded`) / `level:assist:offered` (event `level_assist`) | założenie sim 0,3 (`plateau_assist_take_rate`); poniżej → pasek za słaby/za drogi (KPI-3) | `plateau_assist_take_rate` (sim-only), `plateau_assist_min_level`, `plateau_assist_from_attempt` |
| 8 | Udział wygranych z probówką | `level:complete:tube:<przedział>`: liczba wartości 1 / wszystkie wygrane w przedziale | porównaj P(wygrana \| probówka) vs bez (wartość 1 vs 0) | `plateau_assist_fail_mult_26_55`, `plateau_assist_fail_mult_56` (model `1 − (1 − win_p) × m`) |
| 9 | Rewarded completion | `ads:rewarded:<placement>:granted` / (`granted` + `skipped`) (eventy `rewarded_offered`, `rewarded_completed`) | min 60 %, cel 80 % (KPI); < 60 % → KPI-5 (nagroda/placement) | wartości nagród w `docs/MONETIZATION.md`, `make sim` (rewarded/DAU) |
| 10 | Dostępność rewarded | 1 − `ads:rewarded:<placement>:unavailable` / `ads:rewarded:<placement>:offered` | fill rate: im niższy, tym mniej impresji → KPI-4; porównaj z metryką 11 | `ad_load_retry_*`, `ad_load_max_retries` |
| 11 | Błędy ładowania reklam / DAU | `ads:load:fail:<rewarded\|interstitial>` / DAU oraz `ads:load:giveup:<format>` / DAU (event `ads_load`) | `giveup` 1× na sesję i format (ADR-013); częste → sieć/SDK, nie wartość nagrody | `ad_load_retry_base_seconds`, `ad_load_retry_max_seconds`, `ad_load_max_retries` |
| 12 | Interstitial / DAU | `ads:interstitial:shown` (event `interstitial_shown`) / DAU; razem z `granted` daje Ad impr / DAU | min 1,5 (łącznie), cel 3,0 (KPI); < 1,5 → KPI-4 | `interstitial_every_n_rounds`, `interstitial_min_seconds`, `interstitial_min_level` |
| 13 | Zgoda UMP / ATT | `consent:ump:<status>` i `consent:att:<status>` (event `consent_result`): udział `obtained`/`authorized` wśród wszystkich statusów (nowy status końcowy po „Opcjach prywatności” liczy się jako zmiana) | brak progu w KPI; niska zgoda obniża eCPM → ARPDAU (min 0,02, cel 0,05) | `consent_form_timeout_seconds` (statusy `timeout`, `form_timeout`) |
| 14 | Zgoda na notyfikacje | `notif:permission:granted` / (`granted` + `denied`) (event `notif_permission`); `notif:scheduled:<streak\|daily\|comeback>` (event `notif_scheduled`) = zaplanowane | brak progu w KPI; wspiera D7 (KPI-3) | ustawienia notyfikacji (GDD pyt. 8, 21) |
| 15 | Zapisy odzyskane | `save:recovered:<backup\|fresh>` (event `save_recovered`) / DAU | crash-free min 99,0 %, cel 99,5 % (KPI); `fresh` = utrata postępu → KPI-1 | weryfikacja zapisu + `save.json.bak` (T-163) |
| 16 | ARPDAU / IAP conversion | `iap_purchase` (`track_business`) + przychód z reklam (SDK) / DAU; płacący / DAU | ARPDAU min 0,02, cel 0,05; IAP min 0,5 %, cel 1,5 % (KPI) | `make sim` (ads/DAU, monety), `docs/MONETIZATION.md` |

## Diagnostyka i lejki (bez własnej metryki KPI)

Eventy potrzebne do rozbicia metryk wyżej, bez progu w `KPI.md`:
- Lejek rundy: `level_start`, `level_complete` (czas, `moves`, `perfect`), `level_fail`, `level_pause` (pauza to nie porażka, G-014), `level_stuck` (`moves_to_goal` przy `StuckPanel`), `daily_challenge_complete`.
- Lejek FTUE (KPI-2): `tutorial_step` (kroki 1–3 → `tutorial:done`).
- Ekonomia: `coins_earned`, `booster_used` (`booster:<type>:<free\|coins\|rewarded>`), `theme_unlocked`, `daily_reward_claimed`, `streak_changed`.
- Meta (D7, KPI-3): `nav` (`nav:shop`, `nav:themes`, `nav:daily`), `daily_share`, `daily_month_goal`.
- Kohorty A/B (Faza 6): `config_variant` — każdą metrykę 1–16 tnij po etykiecie wariantu.
- Reklamy, SDK: `ads_watchdog` (`ads:watchdog:unmute`, `ads:watchdog:late:*`) — częste wystąpienia = problem adaptera AdMob, nie balansu.
- Dopełnienie sesji: `session_end` (czas trwania sesji; wzór w wierszu 3).

## Zasady użycia
1. Najpierw `KPI.md` → Reguły decyzyjne (kolejność 1–7); ta tabela mówi, który event rozstrzyga i co skalibrować.
2. Kalibracja = zmiana klucza `GameConfig` (remote config, Faza 6) albo sim-only z `tools/balance_sim.py`, potem `make sim`/`make playtest` i wpis w GDD.
3. Zmiana listy eventów w GDD → tu, w RELEASE_CHECKLIST i w Data Safety / Privacy Labels (strażnicy w `tools/test_tools.py`).
