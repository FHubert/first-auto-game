# ASO

Status: APPROVED (v1.0, 2026-10-23) · Skill: `aso` · Zadanie: R-002

Reguła: tytuł i keywordy wchodzą do wyboru tylko po sprawdzeniu wolności w Google Play i App Store Connect. Zajęta nazwa eliminuje wariant.

Limity: Play — tytuł 30 znaków, short description 80, full description 4000. ASC — name 30, subtitle 30, keywords 100 znaków.

Metoda sprawdzenia (2026-10-23): WebSearch z frazą w cudzysłowie, osobno `site:apps.apple.com` i `site:play.google.com` oraz bez ograniczenia domeny. WebFetch na wyszukiwarkę Play i iTunes Search API był niedostępny w sesji (brak zgody na URL, jak w R-001). „Brak trafień" w wyszukiwarce ≠ gwarancja wolności — ostateczne sprawdzenie przy zakładaniu aplikacji (ASC → New App wymaga unikalnej nazwy) oraz w EUIPO / UPRP: **ZWERYFIKUJ** przed rejestracją (Faza 4).

## Tytuł (3 warianty)

| Tytuł | Wolny w Play? | Wolny w ASC? | Keyword fit |
|---|---|---|---|
| **Vialo: Water Sort Puzzle** (24 zn.) — WYBRANY | tak wg WebSearch: brak aplikacji „Vialo" (`site:play.google.com` zwraca tylko inne nazwy deweloperów) — ZWERYFIKUJ w Play Console | tak wg WebSearch: brak „Vialo" (najbliższe: „Vially", inna kategoria) — ZWERYFIKUJ w ASC → New App | wysoki: „water sort" + „puzzle" — główna fraza podgatunku; „vial" = fiolka/probówka (czytelne w EN/PL/DE) |
| **Flaskly: Color Sort Puzzle** (26 zn.) | tak wg WebSearch: brak „Flaskly" — ZWERYFIKUJ | tak wg WebSearch: brak „Flaskly"; istnieje podobne „Flasky: Liquor Recommendations" (ryzyko pomyłki, inna kategoria) — ZWERYFIKUJ | średni-wysoki: „color sort" + „puzzle" |
| **Pourio: Daily Water Sort** (24 zn.) | tak wg WebSearch: brak „Pourio" — ZWERYFIKUJ | tak wg WebSearch: brak „Pourio" — ZWERYFIKUJ | średni: „water sort" + wyróżnik „daily" (bez „puzzle") |

Odrzucone w trakcie: „Pourly" (iOS: istnieje „Pourly - Bar Cost Calculator"), „Daily Pour" (iOS: istnieje „The Daily Pour"), „Hue …" (ryzyko pomylenia z marką gry „Hue" — cudza marka). Żaden wariant nie zawiera cudzej marki.

## Subtitle / short description

- iOS subtitle (≤ 30 znaków): `Daily Color Pour Challenge` (26 zn.; bez słów z tytułu).
- Android short description (≤ 80 znaków): `Water sort puzzle with a fresh daily level. Pour, relax, play offline.` (70 zn.)
- PL short description: `Gra logiczna w sortowanie kolorów. Nowy poziom dnia, relaks, offline.` (69 zn.)
- DE short description: `Wasser sortieren mit täglichem Level. Farben gießen, entspannen, offline.` (73 zn.)

Pole keywords ASC (en-US, 89 B, bez słów z tytułu/subtitle): `liquid,tube,bottle,ball,match,logic,brain,relax,asmr,offline,casual,mind,teaser,hue,flask`

## Keywordy (20)

Wolumen: brak dostępu do autocomplete sklepów i płatnych narzędzi w sesji → wartości jakościowe z uzasadnieniem, każda `ZWERYFIKUJ` autocomplete (skill `aso` §3). Konkurencja: liczba tytułów z frazą w top wynikach WebSearch `apps.apple.com` (2026-10-23).

| # | keyword | wolumen szac. | konkurencja |
|---|---|---|---|
| 1 | water sort | wysoki (fraza główna podgatunku; Water Sort: Color Puzzle Game 100 mln+ pobrań [RESEARCH 6]) — ZWERYFIKUJ | bardzo wysoka (wszystkie top wyniki WebSearch mają „Water Sort" w tytule) |
| 2 | water sort puzzle | wysoki — ZWERYFIKUJ | bardzo wysoka |
| 3 | color sort | średni-wysoki — ZWERYFIKUJ | wysoka (wiele tytułów „Color Sort") |
| 4 | sort puzzle | średni-wysoki — ZWERYFIKUJ | wysoka |
| 5 | liquid sort | średni — ZWERYFIKUJ | średnia (pojedyncze tytuły „Liquid Sort/Color Sort") |
| 6 | ball sort | wysoki (osobny tryb, later) — ZWERYFIKUJ | bardzo wysoka (US 10/10 „Ball Sort" [RESEARCH 10]) |
| 7 | pour puzzle | niski-średni — ZWERYFIKUJ | średnia („pour puzzle" w kilku podtytułach) |
| 8 | color puzzle | średni — ZWERYFIKUJ | wysoka |
| 9 | tube sort | niski — ZWERYFIKUJ | niska-średnia |
| 10 | bottle sort | niski-średni — ZWERYFIKUJ | średnia |
| 11 | daily puzzle | średni (kategoria „daily" w grach słownych) — ZWERYFIKUJ | średnia (głównie gry słowne, nie sort) — szansa long-tail z wyróżnikiem |
| 12 | relaxing games | średni — ZWERYFIKUJ | wysoka |
| 13 | asmr game | średni — ZWERYFIKUJ | średnia (Water Match™ ASMR [RESEARCH 5]) |
| 14 | logic puzzle | średni — ZWERYFIKUJ | wysoka |
| 15 | brain teaser | średni — ZWERYFIKUJ | wysoka |
| 16 | offline puzzle | średni — ZWERYFIKUJ | średnia |
| 17 | sortowanie kolorów (PL) | niski (rynek PL) — ZWERYFIKUJ | niska (mało tytułów z polskim tytułem) — ZWERYFIKUJ |
| 18 | gra logiczna (PL) | niski-średni — ZWERYFIKUJ | średnia — ZWERYFIKUJ |
| 19 | Wasser sortieren (DE) | niski-średni — ZWERYFIKUJ | średnia (np. „Water Sort Puz - Farbspiel" ma DE podtytuł) |
| 20 | Farben sortieren (DE) | niski-średni — ZWERYFIKUJ | średnia (istnieje „Farben Sortieren - Color Flow") |

Pole keywords ASC: maks. 100 znaków, oddzielone przecinkami, bez powtórzeń słów z tytułu.

## Opis długi (szkic)

*Hak w 1–2 zdaniach, 3–5 punktów z funkcjami, CTA. Bez obietnic typu „wygrywaj bez wysiłku" i bez sugerowania przewagi za pieniądze.*

EN (bazowy; PL/DE tłumaczone natywnie w zadaniu metadata):

> Pour, sort, breathe. Vialo is a calm water sort puzzle: tap a vial, pour the top color into another, and finish when every vial holds a single color.
>
> - A new Daily Level every day — the same puzzle for everyone, with its own reward.
> - Hundreds of levels that grow from 2 to 12 colors — every level is checked by a solver, so every one can be solved.
> - Undo, an extra vial and hints when you get stuck — no timers, no pressure.
> - Unlock themes: new liquid palettes, backgrounds and vial shapes.
> - Soft pouring sounds and haptics. Plays offline.
>
> Why you'll love it: short levels for a coffee break, a streak that rewards coming back, and a water sort puzzle that never runs out.
>
> Vialo is free to play. It contains optional rewarded ads, ads between levels, and in-app purchases (including one that removes ads between levels).
> Privacy policy: <link — Faza 4>.

## Screenshoty (5)

Każdy screenshot pochodzi z `tools/gen_screenshots.sh` (`make screenshots`).

1. Ekran: `Level` (poziom ~20, 6 kolorów, w trakcie przelewu) · Caption: „Pour & sort colors"
2. Ekran: `LevelComplete` (wygrana, monety, „idealnie") · Caption: „Relax, level by level"
3. Ekran: `Home` z kartą Poziomu dnia i licznikiem · Caption: „A new Daily Level every day"
4. Ekran: `DailyRewardPopup` (dzień 5 streaka) · Caption: „Keep your streak, grab rewards"
5. Ekran: `Themes` (4 motywy, jeden aktywny) · Caption: „Unlock calming themes"

## Ikona

*Opis: kształt, 2–3 kolory z palety z `docs/GDD.md`, brak tekstu, czytelność w rozmiarze 48 px. Musi dać się wygenerować w `tools/gen_assets.py`.*

Jedna probówka (zaokrąglony prostokąt) przechylona o ~20°, z 3 poziomymi warstwami: `#E63946` (dół), `#FFD166` (środek), `#3A86FF` (góra), na pełnym tle `#14213D`; szkło jako obrys `#CAD2E0`, grubość ≥ 6 % szerokości ikony, żeby był czytelny w 48 px. Bez tekstu, bez gradientów (opcjonalnie 1 jasny refleks prostokątem z alfą). Generowana w `tools/gen_assets.py` w 1024×1024 (iOS, bez alfy) i 512×512 (Play, PNG 32-bit).

## Rynki soft launch

| Rynek | Język | Uzasadnienie | Status |
|---|---|---|---|
| PL | pl | rynek domowy; 40 % ruchu w modelu ARPDAU (przyjęte w R-001); test copy i FTUE taniej (eCPM i CPI niższe) | todo |
| US | en | główny rynek monetyzacji (eCPM rewarded US ~16–20 USD [RESEARCH 3]); 30 % ruchu w modelu | todo |
| DE | de | wysokie ARPDAU w EU (eCPM rewarded iOS ~10 USD [RESEARCH 4]); water sort w top-3 pobrań puzzle Android DE Q4 2025 [RESEARCH 5]; 30 % ruchu | todo |
