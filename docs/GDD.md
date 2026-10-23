# GDD — <nazwa robocza>

Status: DRAFT
Wersja: 0.1 · Data: 2026-10-23 · Zmiana statusu na `APPROVED`: zadanie R-002

> Dopóki status to `DRAFT`, pętla bierze wyłącznie zadania z `BACKLOG.md` → `## P0 — fundamenty` (CLAUDE.md).

## Pitch
*Jedno zdanie: dla kogo, jaka pętla, dlaczego gracz wraca. Maks. 25 słów.*

## Gatunek i referencje
*Gatunek oraz 2–3 tytuły z top-10 z `docs/RESEARCH.md`. Przy każdym: co bierzemy, a czego nie.*

- Gatunek:
- Referencja 1:
- Referencja 2:

## Core loop
*Jeden akapit: co gracz robi co 10–30 s, jaką dostaje nagrodę i co ona odblokowuje. Diagram ASCII poniżej.*



```
<miejsce na diagram: akcja → wynik → nagroda → odblokowanie → akcja>
```

## Sesja
*Długość (cel 2–5 min), warunek zakończenia sesji i hook: co czeka na gracza po powrocie.*

- Długość:
- Zakończenie sesji:
- Hook do następnej sesji:

## Progresja
*Krzywa trudności, odblokowania (poziomy, światy, bohaterowie, ulepszenia) i tempo. Po ilu sesjach gracz ma pierwszy „ładny" moment.*



## Ekonomia
*Waluty, źródła i sinki. Wartości startowe trzymamy w `game/src/systems/config.gd`, nie w tym dokumencie.*

| Waluta | Typ (miękka / twarda) | Źródła | Sinki | Uwagi |
|---|---|---|---|---|
| | | | | |

## Meta
*Daily reward (wartości dni 1–7), streak (co go resetuje, czy jest grace period) i cele 7- oraz 30-dniowe.*

- Daily reward:
- Streak:
- Cele 7 dni:
- Cele 30 dni:

## Generator contentu
*Opisz algorytm generacji (seed, parametry z configu). Test rozwiązywalności: headless solver przechodzi każdy poziom dla zakresu seedów, uruchamiany w `make test`.*

- Algorytm:
- Seed i zakres testowy:
- Test rozwiązywalności (solver, limit ruchów):
- Co dzieje się z poziomem, który nie przechodzi testu:

## Ekrany
*Lista ekranów. Każdy ekran ma wpis w `tools/gen_screenshots.sh`.*

- `<Nazwa ekranu>` — cel; wejście z: …; wyjście do: …

## Mechaniki
*Każda mechanika ma priorytet MVP lub later oraz sposób testu headless (gdUnit4 albo bot z `make playtest`). Mechanika bez sposobu testu nie wchodzi do MVP.*

| Mechanika | Priorytet (MVP / later) | Jak testujemy headless |
|---|---|---|
| | | |

## Styl graficzny
*Paleta (max 6 kolorów, hex), kształty i animacje. Wszystko ma być generowalne w `tools/gen_assets.py`, bez ręcznie rysowanych assetów.*

- Paleta:
- Kształty:
- Animacje (tween / klatki):
- Kontrast tekstu na tle (minimum):

## Audio
*Liczba ścieżek muzycznych i SFX, ich źródło (własne generowane lub CC0) oraz wpis każdego obcego pliku w `docs/LICENSES.md`.*

- Muzyka:
- SFX:
- Ustawienia wyciszenia:

## Analityka
*Lista eventów GameAnalytics: nazwa, parametry, moment wysyłki. Zmiana listy wymaga aktualizacji Data Safety (Play) i Privacy Nutrition Labels (ASC).*

Propozycja startowa, do zatwierdzenia:

- `session_start` — start aplikacji; parametry: wersja, platforma.
- `session_end` — koniec sesji; parametr: czas trwania.
- `level_start` / `level_complete` / `level_fail` — parametry: numer poziomu, czas.
- `rewarded_offered` / `rewarded_completed` — parametr: placement id.
- `interstitial_shown` — parametr: placement id.
- `daily_reward_claimed` — parametr: dzień streaka.
- `iap_purchase` — parametry: sku, cena.
- `consent_result` — wynik UMP / ATT.

## Otwarte pytania
*Pytania wymagające decyzji produktowej. Każde trafia też do `BACKLOG.md` → `## Pytania do Huberta`.*

1.
