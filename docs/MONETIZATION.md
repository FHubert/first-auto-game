# Monetyzacja

Status: APPROVED (v1.0, 2026-10-23, R-002)
Źródło: `docs/GDD.md` (Ekonomia, Meta) · Progi: `KPI.md` · Parametry: `game/src/systems/config.gd` (GameConfig)

## Model
*Rewarded ads jako główne źródło przychodu, IAP jako dodatek. Opisz, za co gracz płaci i dlaczego nie wpływa to na wygraną.*

- Model: rewarded ads (główny) + interstitial z capem + IAP (dodatkowy).
- Brak banneru w MVP.
- Gracz płaci (reklamą, monetami albo IAP) za **wygodę i wygląd**: podwojenie monet, dodatkową probówkę, dodatkowe cofnięcia, pominięcie poziomu, motywy, brak interstitiali. Każdy poziom jest rozwiązywalny bez boosterów (gwarancja solvera, `docs/GDD.md` → Generator), restart jest zawsze darmowy, a wszystko z IAP da się zdobyć monetami z gry (poza `remove_ads`). Brak rywalizacji między graczami → zakup nie daje przewagi nad innymi.

Szacunek (założenia, do weryfikacji `make sim` w G-011 i danymi soft launchu):

| Źródło impresji / DAU | Założenie | Impr./DAU |
|---|---|---|
| Interstitial `level_end` | ~10 poziomów/DAU, od poziomu 8, co 5 poziomów, min 120 s | ~1,5–2,0 |
| Rewarded `double_coins` | ~20 % wygranych | ~2,0 |
| Rewarded `daily_x2` | ~50 % odbiorów | ~0,5 |
| Rewarded `extra_tube` / `undo_refill` / `skip_level` / `streak_save` | sytuacyjne | ~0,5 |
| **Razem** | | **~4,5–5,0** (KPI cel 3,0, „świetnie" 5,0) |

ARPDAU (metoda z `docs/RESEARCH.md`): eCPM blended przy mixie 30/30/40 US/DE/PL ≈ 0,3 × 15 + 0,3 × 8 + 0,4 × 2,25 ≈ **~7,8 USD** (środki przedziałów z RESEARCH; PL = `ZWERYFIKUJ`) → ads ≈ 4,5 × 7,8 / 1000 ≈ **~0,035 USD**; IAP ≈ 0,5–1,5 % × 5–10 USD / 30 ≈ ~0,001–0,005 → razem **~0,036–0,040 USD** — powyżej kill-line 0,02, poniżej celu 0,05. Główna dźwignia: udział US w ruchu (eCPM US ~5–10× PL).

## Placementy
*Każdy placement: moment w sesji, nagroda, cap. Wartość `id` musi być zgodna z eventami w `docs/GDD.md` → Analityka.*

| id | moment | nagroda | cap |
|---|---|---|---|
| `double_coins` (rewarded) | ekran `LevelComplete`, przycisk „×2" obok „Dalej" | monety poziomu × `rewarded_multiplier` (2.0) — kwota widoczna na przycisku przed reklamą | 1 na poziom; nie w poziomie 1 (FTUE: pierwsza oferta po pierwszej wygranej, od poziomu 2) |
| `extra_tube` (rewarded) | HUD `Level` (przycisk +probówka), `StuckPanel` i pasek „Pomoc na plateau” (kampania ≥ `plateau_assist_min_level`, próba ≥ `plateau_assist_from_attempt`; `make sim`: 0,09 → 0,22/DAU przy take_rate 0,3) | +1 pusta probówka w bieżącym poziomie (alternatywa: `extra_tube_cost_coins` = 60) | `extra_tube_max_per_level` = 1 na poziom |
| `undo_refill` (rewarded) | po wyczerpaniu `undo_free_per_level` (przycisk cofnij → oferta) i w `StuckPanel` | +`undo_refill_amount` = 3 cofnięcia (alternatywa: 20 monet) | 2 na poziom |
| `skip_level` (rewarded) | `StuckPanel`, po `skip_unlock_restarts` = 2 restartach tego samego poziomu | poziom zaliczony bez monet (kampania; w Poziomie dnia niedostępne) | 1 na poziom |
| `daily_x2` (rewarded) | `DailyRewardPopup`, przycisk „Odbierz ×2" | nagroda dzienna × 2 | 1 na dzień UTC |
| `streak_save` (rewarded) | `DailyRewardPopup` po przerwie dokładnie 1 dnia | streak kontynuowany zamiast resetu | `streak_save_max_per_week` = 1 na 7 dni UTC |
| `level_end` (interstitial) | po stuknięciu „Dalej" na `LevelComplete` (naturalna przerwa) | — | co `interstitial_every_n_rounds` = 5 poziomów, min `interstitial_min_seconds` = 120 s, od poziomu `interstitial_min_level` = 8; nigdy w tej samej przerwie co rewarded; nigdy przy `ads_removed`; nigdy przy starcie/wyjściu z aplikacji |

Uwaga: skill `ads-iap` wymienia przykładowy placement `continue` — w tym gatunku nie ma „game over", jego rolę pełnią `extra_tube` i `undo_refill`.

## Produkty IAP
*Każdy produkt: sku, cena w USD (tier sklepu) i zawartość. Produkt wchodzi do tabeli dopiero po zatwierdzeniu w GDD.*

| sku | cena USD | zawartość |
|---|---|---|
| `remove_ads` | 3,99 (non-consumable) | brak interstitiali na zawsze; rewarded zostają dobrowolne; przywracany przez „Przywróć zakupy" |
| `coins_small` | 1,99 (consumable) | 500 monet (~8 dodatkowych probówek) |
| `coins_large` | 4,99 (consumable) | 1500 monet (+20 % wartości/USD vs `coins_small`) |
| `starter_pack` | 1,99 (non-consumable, jednorazowy) | 800 monet + motyw „Neon"; widoczny od poziomu `starter_offer_min_level` = 12 przez `starter_offer_hours` = 72 h, potem tylko w `Shop` do zakupu; bez `remove_ads` (nie kanibalizuje) |

Ceny lokalne (PLN, EUR) pobierane ze sklepu (`IapProvider`), nigdy z kodu. Integracja SDK (Google Play Billing, StoreKit) wymaga nowego ADR (ADR-007 nie obejmuje pluginów IAP) — zadanie w backlogu.

## Zasady
- Brak banneru w MVP.
- Interstitial: cap czytany z `GameConfig`, nigdy wpisany na sztywno w scenie.
- Rewarded: zawsze dobrowolny; gracz widzi nagrodę przed startem reklamy; przycisk ukryty, gdy `Ads.request_rewarded` nie ma gotowej reklamy (`is_rewarded_ready() == false`).
- Brak interstitiali w pierwszej sesji: `interstitial_min_level` = 8 (poziomy 1–7 ≈ pierwsza sesja), do weryfikacji w A/B (H2).
- Consent: UMP przed pierwszym żądaniem reklamy (EEA); ATT prompt na iOS przed śledzeniem.
- Każda reklama i zakup przechodzą przez `AdProvider` (ADR-003) / `IapProvider` (nowy ADR); w testach działa `FakeAdProvider` / `FakeIapProvider`.
- Wartości ekonomiczne (koszty, nagrody) tylko w `GameConfig`; opis gry w sklepie informuje o reklamach i zakupach (`docs/ASO.md`).

## Hipotezy do A/B
*Każda hipoteza: co zmieniamy, która metryka z `KPI.md` ma wzrosnąć i do jakiego progu. Testy A/B działają dopiero od Fazy 6 (Firebase Remote Config, ADR-004).*

Plan eksperymentów z próbkami: `docs/EXPERIMENTS.md` (T-208)

| id | hipoteza | metryka | próg (KPI.md) | wariant A | wariant B |
|---|---|---|---|---|---|
| H1 | Mnożnik ×3 na `double_coins` zwiększa odsetek wygranych z obejrzaną reklamą bez inflacji, która przyspiesza zakup motywów i obniża D7 | Ad impressions / DAU; kontrolnie D7 | ≥ 3,0 impr./DAU przy D7 ≥ 12 % | `rewarded_multiplier` = 2.0 | `rewarded_multiplier` = 3.0 |
| H2 | Gęstszy interstitial (co 4 poziomy, min 90 s, od poziomu 5) podnosi impresje bez spadku D1 | Ad impressions / DAU, D1 | ≥ 3,0 impr./DAU przy D1 ≥ 35 % | `interstitial_every_n_rounds` = 5, `interstitial_min_seconds` = 120, `interstitial_min_level` = 8 | 4 / 90 / 5 |
| H3 | Wcześniejsza oferta `starter_pack` (po poziomie 6 zamiast 12) podnosi konwersję IAP | IAP conversion | ≥ 1,5 % | `starter_offer_min_level` = 12 | `starter_offer_min_level` = 6 |
| H4 | Pomoc na plateau od 3. próby (zamiast 2.) jest mniej natrętna (mniej `level:assist:*`/DAU; sim: ~2,6x mniej monet na pomoc, ale baza 26/2 ma więcej rewarded - test dotyczy tylko natrętności vs D7, nie ekonomii) bez utraty D7 kohorty 56+ (T-187: 46,0 % od 2. próby vs 34,4 % od 3. w ≤ 3 próbach - bot z ofertą zawsze brany, górna granica) | D7 kohorty; `level:assist:*`/DAU; rewarded/DAU; D1 | D7 ≥ 12 % przy D1 ≥ 35 % | `plateau_assist_from_attempt` = 2 | `plateau_assist_from_attempt` = 3 |

**Paczki remote configu:** [`default.json`](remote_config/default.json), [`h1_b.json`](remote_config/h1_b.json), [`h2_b.json`](remote_config/h2_b.json), [`h3_b.json`](remote_config/h3_b.json), [`h4_assist_3.json`](remote_config/h4_assist_3.json). Nowy eksperyment = nowy plik w `docs/remote_config/` (`remote_config_variant` = nazwa pliku) + zielony `test_remote_config_packages.gd` PRZED wpisaniem wartości do Firebase Remote Config; wartości wariantu B w tabeli i w pliku muszą być identyczne.

### Przewidywanie `make sim` (seed 1, 5000 graczy, 30 dni, jeden przebieg na bazie `DEFAULTS` 26/2)

Szum (T-209): `--json` podaje `impressions_per_player_day` {mean, sd, n} i `ads_per_dau_ci95` (rewarded / interstitial / total; mean ± 1,96 × sd / √n, gracz-dni traktowane jako niezależne, więc przedział jest optymistyczny). Seed 1, DEFAULTS, połowa CI total: 0,095 przy 1000 graczy, 0,041 przy 5000, 0,029 przy 10 000. Domyślne `--players` = 5000; przy porównaniach wariantów różnica, której przedziały CI się nakładają, to szum ("w szumie").

Polecenia (T-216; default = bez `--overlay`; klucze nieznane symulacji, np. `starter_offer_min_level`, są ignorowane z ostrzeżeniem na stderr, a `remote_config_variant` jako klucz meta jest pomijany po cichu):

`python3 tools/balance_sim.py --players 5000 --days 30 --seed 1 [--overlay docs/remote_config/<wariant>.json] --json`

Stan po T-178/T-185/T-189/T-199/T-203 (pomoc na plateau jako mnożnik porażki `plateau_assist_fail_mult_*`, metryki motywów z n i progiem `MIN_N` = 30). Wszystkie 5 wierszy z jednego przebiegu na jednej bazie (`plateau_assist_from_attempt` = 2, z wyjątkiem h4).

| wariant | impresje/DAU (rewarded + interstitial = total) | CI 95 % total | rewarded `extra_tube`/DAU | 1. motyw (dzień kalendarzowy, mediana) | 3. motyw (dzień, n) | mediana monet d30 / d1 | exit code |
|---|---|---|---|---|---|---|---|
| default (`plateau_assist_from_attempt` 2) | 3.05 + 1.36 = 4.42 | 4.375–4.456 | 0.405 | 3 | n/a (n=3) | 565 / 340 | 0 |
| h1_b (`rewarded_multiplier` 3.0) | 3.01 + 1.34 = 4.35 | 4.309–4.389 | 0.386 | 3 | n/a (n=26) | 610 / 350 | 0 |
| h2_b (interstitial co 4 rundy, od lvl 5) | 3.05 + 1.80 = 4.86 | 4.813–4.899 | 0.405 | 3 | n/a (n=3) | 565 / 340 | 0 |
| h3_b (`starter_offer_min_level` 6) | 3.05 + 1.36 = 4.42 | 4.375–4.456 | 0.405 | 3 | n/a (n=3) | 565 / 340 | 0 |
| h4_assist_3 (`plateau_assist_from_attempt` 3) | 2.84 + 1.35 = 4.20 | 4.157–4.233 | 0.212 | 3 | n/a (n=6) | 555 / 330 | 0 |

H1 vs default: total 4.35 vs 4.42, CI się nakładają (4.309–4.389 vs 4.375–4.456) - różnica w szumie; rewarded 3.01 vs 3.05 też w szumie (2.976–3.035 vs 3.023–3.083). H1 podnosi monety d30 z 565 do 610 (d1 340 -> 350); 3. motyw kupiło 26 graczy (poniżej `MIN_N` = 30, dzień n/a, 0,6 % engaged) - brak sygnału inflacji w modelu. H2 vs default: interstitial 1.36 -> 1.80/DAU, total 4.42 -> 4.86 (CI 4.813–4.899 vs 4.375–4.456 nie nakładają się - różnica realna w modelu), bez wpływu na ekonomię monet (d30 565 jak w default). H3 nie jest modelowany przez symulację (wynik identyczny z default). H4 vs default: total 4.20 vs 4.42 (CI 4.157–4.233 vs 4.375–4.456 nie nakładają się; -5,0 %), rewarded 2.84 vs 3.05. Poprzednia wersja tabeli (przed T-178) podawała 3. motyw w 24.-25. dniu; po T-178/T-185 pomoc na plateau zużywa monety, więc nikt w default nie dochodzi do 3. motywu w 30 dni (3. motyw kupiło 3 z 4207 engaged).

### H4 - przewidywanie `make sim --overlay docs/remote_config/h4_assist_3.json` (seed 1, 5000 graczy, 30 dni)

| metryka | baza (od 2. próby, `DEFAULTS` od T-198) | H4 (od 3. próby) |
|---|---|---|
| 3. motyw | n/a (n=3) | n/a (n=6) |
| `plateau_assist_coins_per_dau` | 18.391 | 7.206 |
| `rewarded_extra_tube_per_dau` | 0.405 | 0.212 |
| `plateau_assist_buys` / próby | 14402 / 122828 | 5762 / 123564 |
| ads/DAU interstitial | 1.36 | 1.35 |
| ads/DAU rewarded | 3.05 | 2.84 |
| ads/DAU total (CI 95 %) | 4.42 (4.375–4.456) | 4.20 (4.157–4.233) |
| mediana monet po 7. dniu aktywnym | 450 | 480 |
| mediana monet d30 | 565 | 555 |

Hipoteza: oferta od 3. próby daje ok. 2,6x mniej monet wydanych na pomoc (18.391 / 7.206 = 2,55) i ok. 1,9x mniej rewarded `extra_tube` (0.405 / 0.212), kosztem ARPDAU ok. -5 % (total 4.42 → 4.20, przedziały CI rozłączne; rewarded -0,21/DAU). Baza 26/2 daje więcej rewarded (3.05 vs 2.84) i więcej impresji, a mediana monet jest porównywalna (d30 565 vs 555; po 7. dniu aktywnym 450 vs 480, więc H4 nie zostawia graczom mniej monet) - ekonomia monet NIE przemawia za H4 ani przeciw niemu. H4 testuje więc wyłącznie natrętność (`level:assist:*`/DAU) kontra D7 (kohorta 56+: 46,0 % od 2. próby vs 34,4 % od 3. wg T-187, górna granica z botem). Metryka decyzji: D7 kohorty, `level:assist:*`/DAU, rewarded/DAU; minimalny czas testu jak H1-H3 (>= 14 dni na wariant, D7 wymaga pełnych kohort). Decyzja 26/2 (T-198, pytanie 12 w GDD) jest domyślna; w A/B w Fazie 6 wariant 3 wygrywa tylko gdy D7 kohorty nie spada istotnie, a D1 i natrętność poprawiają się.
