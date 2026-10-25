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
| H4 | Pomoc na plateau od 3. próby (zamiast 2.) jest mniej natrętna (mniej `level:assist:*`/DAU, wolniejszy sink monet) bez utraty D7 kohorty 56+ (T-187: 46,0 % od 2. próby vs 34,4 % od 3. w ≤ 3 próbach - bot z ofertą zawsze brany, górna granica) | D7 kohorty; `level:assist:*`/DAU; rewarded/DAU; D1 | D7 ≥ 12 % przy D1 ≥ 35 % | `plateau_assist_from_attempt` = 2 | `plateau_assist_from_attempt` = 3 |

**Paczki remote configu:** [`default.json`](remote_config/default.json), [`h1_b.json`](remote_config/h1_b.json), [`h2_b.json`](remote_config/h2_b.json), [`h3_b.json`](remote_config/h3_b.json), [`h4_assist_3.json`](remote_config/h4_assist_3.json). Nowy eksperyment = nowy plik w `docs/remote_config/` (`remote_config_variant` = nazwa pliku) + zielony `test_remote_config_packages.gd` PRZED wpisaniem wartości do Firebase Remote Config; wartości wariantu B w tabeli i w pliku muszą być identyczne.

### Przewidywanie `make sim` (seed 1, 1000 graczy, 30 dni)

Szum (T-209): `--json` podaje `impressions_per_player_day` {mean, sd, n} i `ads_per_dau_ci95` (rewarded / interstitial / total; mean ± 1,96 × sd / √n, gracz-dni traktowane jako niezależne, więc przedział jest optymistyczny). Seed 1, DEFAULTS, połowa CI total: 0,095 przy 1000 graczy, 0,041 przy 5000, 0,029 przy 10 000. Domyślne `--players` = 5000 (T-209; poniższa tabela nadal z 1000 graczy do T-216): przy porównaniach wariantów różnica mniejsza niż nakładające się CI to szum.

`python3 tools/balance_sim.py --players 1000 --days 30 --seed 1 --overlay docs/remote_config/<wariant>.json` (default = bez `--overlay`; klucze nieznane symulacji, np. `starter_offer_min_level`, są ignorowane z ostrzeżeniem na stderr, a `remote_config_variant` jako klucz meta jest pomijany po cichu). Stan po T-178/T-185/T-189/T-199 (pomoc na plateau jako mnożnik porażki `plateau_assist_fail_mult_*`, metryki motywów z n i progiem `MIN_N` = 30; wiersze `default` i H4 przeliczone w T-199, h1–h3 nadal z T-190 — stara baza 26/3).

| wariant | impresje/DAU (rewarded + interstitial = total) | rewarded `extra_tube`/DAU | 1. motyw (dzień kalendarzowy, mediana) | 3. motyw (dzień, n) | mediana monet d30 / d1 | exit code |
|---|---|---|---|---|---|---|
| default (od T-198: `plateau_assist_from_attempt` 2) | 3.15 + 1.39 = 4.54 | 0.423 | 3 | n/a (n=1) | 570 / 335 | 0 |
| h1_b (`rewarded_multiplier` 3.0)* | 2.87 + 1.34 = 4.21 | 0.222 | 3 | n/a (n=10) | 600 / 350 | 0 |
| h2_b (interstitial co 4 rundy, od lvl 5)* | 2.85 + 1.77 = 4.62 | 0.206 | 4 | n/a (n=0) | 575 / 335 | 0 |
| h3_b (`starter_offer_min_level` 6)* | 2.85 + 1.34 = 4.19 | 0.206 | 4 | n/a (n=0) | 575 / 335 | 0 |
| h4_assist_3 (`plateau_assist_from_attempt` 3 = dawny default T-190) | 2.85 + 1.34 = 4.19 | 0.206 | 4 | n/a (n=0) | 575 / 335 | 0 |

\* Wiersze h1–h3 zmierzone w T-190 przy `plateau_assist_from_attempt` = 3 (ówczesny default = dzisiejszy `h4_assist_3`); od T-198 `DEFAULTS` = 2 i wiersz `default` odpowiada dawnemu `h4_assist_2`. Porównania h1–h3 w akapicie niżej odnoszą się do bazy 26/3 (4.19) — po T-198 przeliczyć przy następnej zmianie paczek.

H2 podnosi interstitiale z 1.34 do 1.77/DAU (total 4.19 -> 4.62), bez wpływu na ekonomię monet (d30 575 jak w default). H1 podnosi monety d30 z 575 do 600 (d1 335 -> 350), rewarded 2.85 -> 2.87/DAU; 3. motyw kupiło 10 z 847 graczy (1,2 %), poniżej `MIN_N` = 30, więc dzień jest raportowany jako n/a - brak sygnału inflacji w modelu. H3 nie jest modelowany przez symulację (wynik identyczny z default). Poprzednia wersja tabeli (przed T-178) podawała 3. motyw w 24.-25. dniu i total 4.07; po T-178/T-185 pomoc na plateau zużywa monety (sink ok. 7,8 monet/DAU), więc nikt w default nie dochodzi do 3. motywu w 30 dni.

### H4 - przewidywanie `make sim --overlay docs/remote_config/h4_assist_3.json` (seed 1, 1000 graczy, 30 dni)

| metryka | baza (od 2. próby, `DEFAULTS` od T-198) | H4 (od 3. próby) |
|---|---|---|
| 3. motyw | n/a (0,0 %) | n/a (0,0 %) |
| `plateau_assist_coins_per_dau` | 18.530 | 7.149 |
| `rewarded_extra_tube_per_dau` | 0.423 | 0.220 |
| `plateau_assist_buys` / próby | 2930 / 25004 | 1220 / 25180 |
| ads/DAU interstitial | 1.39 | 1.34 |
| ads/DAU rewarded | 3.15 | 2.84 |
| ads/DAU total | 4.54 | 4.18 |
| mediana monet po 7. dniu aktywnym | 525 | 400 |

Hipoteza: oferta od 3. próby daje ok. 2,6x mniej monet wydanych na pomoc i mniejszą natrętność, kosztem ARPDAU ok. -8 % (rewarded -0,3/DAU, total 4.54 → 4.18); od T-199 pomoc realnie skraca plateau, więc baza 26/2 zarabia więcej monet na wygranych (mediana po 7. dniu aktywnym 525 vs 400; przed T-199 odwrotnie: 522 vs 650, bo pomoc była martwa) i ryzyka D7 56+ poniżej bramki (34,4 % vs 46,0 % wg T-187). Metryka decyzji: D7 kohorty, `level:assist:*`/DAU, rewarded/DAU; minimalny czas testu jak H1-H3 (>= 14 dni na wariant, D7 wymaga pełnych kohort). Decyzja 26/2 (T-198, pytanie 12 w GDD) jest domyślna; w A/B w Fazie 6 wariant 3 wygrywa tylko gdy D7 kohorty nie spada istotnie, a D1 i natrętność (`level:assist:*`/DAU) poprawiają się.
