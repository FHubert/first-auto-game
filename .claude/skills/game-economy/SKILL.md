---
name: game-economy
description: Uzyj przy projektowaniu lub zmianie balansu casual F2P - waluty, nagrody, krzywa trudnosci, FTUE, daily reward, streak - oraz przy interpretacji wyniku make sim.
---

# game-economy — balans casual F2P

Wszystkie parametry żyją w `game/src/systems/config.gd` (`GameConfig.DEFAULTS`); `tools/balance_sim.py` czyta te same klucze. Skill daje zasady i wartości STARTOWE - finalne ustala się symulacją i metrykami z `KPI.md`.

## 1. Waluty
- MVP: **1 waluta** (`coins`, soft). Druga (hard, `gems`) dopiero gdy IAP ma co sprzedawać poza `remove_ads` - więcej walut = więcej sinków do zbalansowania i więcej zdarzeń w analityce.
- Opcja 2 walut: soft (zdobywana w grze, tania, wiele sinków) i hard (kupowana IAP albo rzadka nagroda, sinki premium: skip poziomu, kosmetyka). Hard NIE konwertuje się z powrotem na soft po lepszym kursie niż zakup.
- **Sinki >= źródła** w długim horyzoncie: sinki = kontynuacja po porażce, podpowiedź, kosmetyka, odblokowania. Mediana monet po 30 dniach nie może rosnąć bez końca (sim: "explodes" gdy mediana po ostatnim dniu > 100x mediany po dniu 1) ani być zerowa (sim: "starves" gdy mediana zakupów do dnia 7 < 1).
- Saldo nigdy ujemne (`GameState.from_dict` odrzuca ujemne `coins`; test tego pilnuje).
- Rewarded zawsze daje coś, co gracz widzi PRZED reklamą (np. "x2 monety" - `rewarded_multiplier`).

## 2. Krzywa trudności
- W repo: logistyczna `ContentGenerator.difficulty_curve(level)` między `difficulty_min` (0,1) a `difficulty_max` (1,0), środek `difficulty_midpoint_level` (20), stromość `difficulty_steepness` (0,15).
- Alternatywa "sawtooth" (piła): trudność rośnie przez 4 poziomy i co 5. poziom jest **breather** (łatwy, -30..40 % trudności względem poprzedniego), dający poczucie sukcesu i miejsce na reklamę rewarded/nagrodę. Implementacja: `d = base_curve(level) * (0.65 if level % breather_every == 0 else 1.0)` z `breather_every = 5` w `GameConfig`.
- **Pierwsze 5 rund = ~90 % win rate** (FTUE). Cel: gracz wygrywa, rozumie pętlę, zanim cokolwiek go zatrzyma. Ustaw `difficulty` poziomów 1–5 tak, by `win_prob` >= 0,85–0,90.
- Docelowy win rate po FTUE: 50–65 % (średnio), poniżej 35 % w kolejnych poziomach tylko na "boss"/co 10.
- "Near miss": porażka powinna być o włos (np. brakło 1–2 ruchów) - pokazuj, o ile zabrakło, i oferuj rewarded-continue. Projektuj generator tak, by ~30–40 % porażek było "near miss".

## 3. FTUE (pierwsza sesja)
- Do pierwszej nagrody < 30 s; pierwsza wygrana < 60 s; brak interstitiali w pierwszej sesji (propozycja w `docs/MONETIZATION.md`, do A/B).
- Pierwsza oferta rewarded po pierwszej WYGRANEJ (gracz czuje wartość), nie po porażce.
- Brak ściany tekstu: max 3 kroki tutorialu, każdy to akcja gracza.
- Sesja docelowa: `session_target_seconds` = 180 (KPI: długość sesji >= 2 min kill-line, cel 4 min).

## 4. Daily reward (7 dni, rosnąca wartość) i streak
- Dni 1..7: mnożniki względem `daily_reward_base` (50): `[1, 1, 2, 2, 3, 3, 6]`; dzień 7 = nagroda "wow" (np. kosmetyka + 6x). Po dniu 7 cykl od początku, ale mnożniki rosną o poziom (opcjonalnie).
- Streak (`GameState.streak_days`, `last_play_utc_day`): dzień pod rząd +1; przerwa >1 dnia → reset do 1 (albo "ochrona streaka" za rewarded = miękka kara, lepsza dla D7). Czas liczony w **UTC dniach** (testowalne bez zegara systemowego).
- Rewarded "podwój daily reward" - najlepszy placement pod ARPDAU.

## 5. Tabela wartości startowych (propozycje -> `GameConfig`)
| Klucz | Start | Uwagi |
|---|---|---|
| `starting_coins` | 0 | albo 100 jeśli pierwszy sink jest w pierwszej sesji |
| `win_reward_coins` | 10 | 1 wygrana ≈ 10 monet |
| `daily_reward_base` | 50 | = ~5 wygranych |
| `rewarded_multiplier` | 2.0 | testuj 1.5 / 2.0 / 3.0 (H1 w MONETIZATION) |
| `interstitial_every_n_rounds` | 3 | testuj 3 vs 5 (H2) |
| `interstitial_min_seconds` | 90 | twardy odstęp niezależny od rund |
| `difficulty_min / max` | 0.1 / 1.0 | |
| `difficulty_midpoint_level` | 20 | poziom, na którym trudność = środek |
| `difficulty_steepness` | 0.15 | większa = ostrzejszy próg |
| `session_target_seconds` | 180 | |
| `breather_every` (nowy) | 5 | co ile poziomów łatwy |
| `continue_cost_coins` (nowy) | 30 | kontynuacja po porażce (sink) |
| `hint_cost_coins` (nowy) | 20 | podpowiedź (sink) |
| `remove_ads` IAP | 3,99–4,99 USD | non-consumable, ukrywa interstitiale, NIE rewarded |
Nowy klucz = wpis w `DEFAULTS` + test + opis w GDD (Ekonomia).

## 6. `make sim` - jak używać i czytać
`make sim` = `python3 tools/balance_sim.py` (domyślnie `--players 1000 --days 30 --seed 1`; `--json` dla maszyn; `--config PATH`). Symuluje retencję (D1/D7/D30), sesje/dzień, win rate zależny od poziomu, zdobywanie/wydawanie monet i rewarded.
- Wynik liczony dla graczy "zaangażowanych" (aktywni >= 2 z 7 pierwszych dni).
- **Exit 0** = ekonomia OK. **Exit 1** gdy: "explodes" (inflacja monet), "starves" (mediana zakupów do dnia 7 < 1) albo ujemne saldo.
- Procedura strojenia: zmień JEDEN klucz w `config.gd` → `make sim` → porównaj mediany (monety d1/d7/d30, zakupy, win rate) → zapisz przed/po w PR. Nie stroj 3 rzeczy naraz.
- Inflacja → dodaj/podnieś sinki (`continue_cost_coins`, nowe kosmetyki) lub obniż `win_reward_coins`. Głód → obniż ceny lub podnieś `daily_reward_base`/`win_reward_coins`.
- Sim nie zastępuje danych: parametry modelu (`win_prob_easy/hard`, `sessions_per_day`) to założenia; po soft launchu kalibruj je pod GA.

## 7. Checklist balansu
- [ ] Wszystkie liczby w `GameConfig`, brak magicznych w kodzie.
- [ ] Win rate rund 1–5 >= 85 % (test na `ContentGenerator`/`GameRound` z ustalonym seedem).
- [ ] `make sim` exit 0 + tabela przed/po.
- [ ] `make playtest` bez softlocka na 3 seedach.
- [ ] Zdarzenia zasobów w GA: `track_resource("Source"|"Sink", currency, amount, item_type, item_id)` raz na rundę, nie na każdy pickup.
- [ ] GDD → Ekonomia zaktualizowane (waluty, źródła, sinki, wartości).
