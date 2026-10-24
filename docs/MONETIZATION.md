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
| `extra_tube` (rewarded) | HUD `Level` (przycisk +probówka) i `StuckPanel` | +1 pusta probówka w bieżącym poziomie (alternatywa: `extra_tube_cost_coins` = 60) | `extra_tube_max_per_level` = 1 na poziom |
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

| id | hipoteza | metryka | próg (KPI.md) | wariant A | wariant B |
|---|---|---|---|---|---|
| H1 | Mnożnik ×3 na `double_coins` zwiększa odsetek wygranych z obejrzaną reklamą bez inflacji, która przyspiesza zakup motywów i obniża D7 | Ad impressions / DAU; kontrolnie D7 | ≥ 3,0 impr./DAU przy D7 ≥ 12 % | `rewarded_multiplier` = 2.0 | `rewarded_multiplier` = 3.0 |
| H2 | Gęstszy interstitial (co 4 poziomy, min 90 s, od poziomu 5) podnosi impresje bez spadku D1 | Ad impressions / DAU, D1 | ≥ 3,0 impr./DAU przy D1 ≥ 35 % | `interstitial_every_n_rounds` = 5, `interstitial_min_seconds` = 120, `interstitial_min_level` = 8 | 4 / 90 / 5 |
| H3 | Wcześniejsza oferta `starter_pack` (po poziomie 6 zamiast 12) podnosi konwersję IAP | IAP conversion | ≥ 1,5 % | `starter_offer_min_level` = 12 | `starter_offer_min_level` = 6 |

**Paczki remote configu:** [`default.json`](remote_config/default.json), [`h1_b.json`](remote_config/h1_b.json), [`h2_b.json`](remote_config/h2_b.json), [`h3_b.json`](remote_config/h3_b.json). Nowy eksperyment = nowy plik w `docs/remote_config/` (`remote_config_variant` = nazwa pliku) + zielony `test_remote_config_packages.gd` PRZED wpisaniem wartości do Firebase Remote Config; wartości wariantu B w tabeli i w pliku muszą być identyczne.

### Przewidywanie `make sim` (seed 1, 1000 graczy, 30 dni)

`python3 tools/balance_sim.py --players 1000 --days 30 --seed 1 --overlay docs/remote_config/<wariant>.json` (klucze nieznane symulacji, np. `starter_offer_min_level`, są ignorowane).

| wariant | impresje/DAU (rewarded + interstitial = total) | 1. motyw (dzień, mediana) | 3. motyw (dzień) | mediana monet d30 / d1 | exit code |
|---|---|---|---|---|---|
| default | 2.722 + 1.350 = 4.072 | 4 | 24 | 560 / 335 | 0 |
| h1_b (`rewarded_multiplier` 3.0) | 2.697 + 1.323 = 4.020 | 3 | 25 | 610 / 350 | 0 |
| h2_b (interstitial co 4 rundy, od lvl 5) | 2.722 + 1.780 = 4.502 | 4 | 24 | 560 / 335 | 0 |
| h3_b (`starter_offer_min_level` 6) | 2.722 + 1.350 = 4.072 | 4 | 24 | 560 / 335 | 0 |

H2 podnosi interstitiale z 1.35 do 1.78/DAU (total 4.50), bez wpływu na ekonomię monet. H1 podnosi monety tylko nieznacznie (d30 560 -> 610), 3. motyw nadal ok. 25. dnia - brak ryzyka inflacji w modelu; H3 nie jest modelowany przez symulację (wynik identyczny z default).
