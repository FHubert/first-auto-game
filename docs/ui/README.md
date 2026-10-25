# UI v2 — zatwierdzony projekt (źródło prawdy dla T-228…T-236)

Status: **APPROVED** (Hubert, 2026-10-25). Projekt powstał w Claude Design (płótno „Vialo — UI v2”, prywatne konto Huberta).
Implementacja ma **odwzorować makiety**, nie projektować od nowa. Odstępstwo od makiety → wpis w BACKLOG „Pytania do Huberta” (`przyjęto: X, do zmiany`) z uzasadnieniem technicznym.

## Pliki

| Plik | Ekran (scena) | Zadanie |
|---|---|---|
| `mockups/01_level.png` | `Level` — HUD + plansza | T-230, T-231 |
| `mockups/02_stuck.png` | `StuckPanel` | T-233 |
| `mockups/03_level_complete.png` | `LevelComplete` | T-233 |
| `mockups/04_home.png` | `Home` | T-232 |
| `mockups/05_daily_reward.png` | `DailyRewardPopup` | T-233 |
| `mockups/06_themes.png` | `Themes` | T-234 |
| `mockups/07_shop.png` | `Shop` | T-234 |
| `mockups/08_settings.png` | `Settings` | T-234 |
| `mockups/09_tokens.png` | tokeny i komponenty | T-228, T-229 |
| `source/*.dc.html` | źródła makiet (HTML + inline CSS) — **dokładne wartości** (px, hex, promienie) czytaj stąd, nie z PNG | wszystkie |

PNG mają 1170 × 2532 (makieta 390 × 844 pt × 3). Teksty w makietach są po polsku; w grze idą przez `strings.csv` (EN/PL/DE). Kwoty, liczniki i ceny w makietach są przykładowe — w grze z `GameConfig`/`GameState`/`IapProvider`.

## Skala: makieta → Godot

Viewport gry: **720 × 1280**, `stretch/mode=canvas_items`, `aspect=expand`.
**Mnożnik: 720 / 390 = 1,846.** Każdą wartość z makiety (pt) mnożysz przez 1,846 i zaokrąglasz do liczby całkowitej.

| Makieta (pt) | Godot (px) | Użycie |
|---|---|---|
| 13 | 24 | najmniejszy tekst (nagłówki sekcji, podpisy) |
| 15 | 28 | opisy |
| 17 | 31 | wiersze, pill waluty |
| 19 | 35 | tekst przycisku |
| 26 | 48 | tytuł ekranu, „Poziom N” |
| 30 | 55 | tytuł overlayu |
| 52–56 | 96–103 | logo, kwota nagrody |
| 44 | 81 | minimalny cel dotyku |
| 48 | 89 | przycisk-ikona (pauza, wstecz) |
| 56 | 103 | przycisk pełnej szerokości |
| 64 | 118 | przycisk HUD |
| 68 | 126 | przycisk nawigacji Home |
| 76 | 140 | „Graj” na Home |
| 20 (margines boczny) | 37 | padding ekranu |

## Tokeny

Kolory (bez zmian palety z GDD, doszły odcienie pochodne):

| Token | Hex | Rola |
|---|---|---|
| `BG` | `#14213D` | tło ekranów |
| `BG_DEEP` | `#0E1A33` | pill waluty, tor paska postępu, cień przycisków ciemnych |
| `CARD` | `#1F3A6B` | karty, panele, przyciski-ikony |
| `CARD_ROW` | `#16294F` | wiersz w karcie, przycisk secondary |
| `CARD_ICON` | `#2A4A82` | tło ikony w karcie |
| `PRIMARY` / `PRIMARY_SHADOW` | `#2EC4B6` / `#1C8F85` | akcja główna (Graj, Dalej, Odbierz) |
| `ON_PRIMARY` | `#0B2A3C` | tekst na PRIMARY |
| `ACCENT` / `ACCENT_SHADOW` | `#FFD166` / `#C99A2E` | monety, nagrody, rewarded, ceny |
| `ON_ACCENT` | `#3D2A00` | tekst na ACCENT |
| `STREAK` | `#FB8500` | płomień serii |
| `TEXT` | `#FFFFFF` | tekst |
| `TEXT_MUTED` | `#A9B8D6` | tekst pomocniczy (7,9 : 1 na BG) |
| `TEXT_SECTION` | `#8EA0C4` | nagłówki sekcji |
| `DIM` | `rgba(6,12,28,0.62–0.70)` | przyciemnienie pod overlayem |

Typografia: **Nunito** (już w repo, OFL), wagi 700/800/900. Nagłówki 900, przyciski 900, opisy 700.

Kształty: przyciski w pełni zaokrąglone (promień = wysokość/2), karty promień 22–32 pt, kafelki 18–20 pt. **Efekt „wypukły”:** cień pełny, bez rozmycia, przesunięty w dół o 4–7 pt, w kolorze `*_SHADOW` (w `StyleBoxFlat`: `shadow_size=0`, `shadow_offset=(0, N)`, `shadow_color`). Po wciśnięciu: cień 0, przycisk przesunięty o N w dół.

Warianty przycisków: `Primary`, `Accent` (z ikoną video, gdy rewarded), `Secondary` (`CARD_ROW`), `Icon` (koło, `CARD`, cień `BG_DEEP`), `Nav` (zaokrąglony kwadrat 68 pt, promień 24 + podpis pod spodem).

## Ikony (T-229)

Liniowe, obrys 2,2 pt na siatce 24, zaokrąglone końce, kolor tekstu. Komplet: pauza, cofnij, od nowa, podpowiedź (żarówka), +probówka, moneta (wypełniona, ACCENT z obrysem ACCENT_SHADOW), płomień (STREAK), kalendarz, paleta, torba (sklep), zębatka, play, video (rewarded), zamknij, wstecz, strzałka w prawo, ptaszek, pomiń, muzyka, głośnik, wibracje, symbole, globus, tarcza. Kształty: patrz `source/*.dc.html` (inline `<svg>`); generator ma je odtworzyć w `tools/gen_assets.py`.

## Plansza i probówki (T-231)

- Probówka: 46 × 180 pt, obrys 3 pt, szkło = kolor `glass` motywu z alfą 0,55 (wybrana 0,95), wnętrze alfa 0,08, dno zaokrąglone (promień 23), osobny „rant” u góry 56 × 8 pt.
- Warstwa płynu: 41 pt, 4 na probówkę; dolna warstwa zaokrąglona; refleks: pionowy pasek 5 pt, biel α 0,22, 6 pt od lewej krawędzi.
- Wybrana probówka: podniesiona o 30 pt.
- Układ: max 4 probówki w rzędzie dla ≤ 8 probówek; powyżej 8 probówki skalowane proporcjonalnie (rzędy po maks. 6–7), tak żeby plansza mieściła się między HUD górnym i dolnym (patrz `Level.fit_board_*`).
- Tło: kolor `background` motywu, płaskie (bez gradientu).

## Ekrany — najważniejsze zmiany względem obecnego UI

- **Level:** górny pasek = pauza (ikona) · „Poziom N” + „Ruchy: X · cel Y” · pill monet. Dolny pasek = 4 przyciski HUD z ikoną i podpisem pod spodem (Cofnij z badge licznika, Od nowa, Podpowiedź z ceną, +Probówka z ceną). Znika dwurzędowy pasek tekstowych przycisków.
- **StuckPanel:** dolny arkusz (bottom sheet) z wierszami „ikona · tytuł + opis · akcja” (Za darmo / Reklama / cena) + Od nowa i Pomiń na dole.
- **LevelComplete:** tytuł „Świetnie!” u góry nad ułożoną planszą, dolny arkusz: badge „Idealnie!”, kwota z monetą, rozbicie nagrody, pasek do motywu, Accent „Podwój”, Primary „Dalej”, link „Menu główne”.
- **Home:** pill monet + pill serii z rekordem, logo „Vialo”, miniatura probówek, duży Primary „Graj / Poziom N”, karta Poziomu dnia (ikona, NOWOŚĆ, nagroda, licznik, Accent „Zagraj”), pasek do motywu, 3 przyciski Nav (Motywy, Sklep, Ustawienia).
- **DailyRewardPopup:** karta, pill serii, siatka 4 kolumny (dzień 7 na 2 kolumny), dziś = obrys ACCENT, odebrane = ptaszek PRIMARY + przygaszona moneta.
- **Themes:** siatka 2 × 2 kart z podglądem w kolorach motywu, aktywny = obrys ACCENT + ptaszek, cena z monetą; pod spodem pasek „do motywu”.
- **Shop:** wyróżniona karta pakietu startowego (obrys ACCENT, licznik czasu), wiersze produktów z ceną w przycisku Accent (cena z `IapProvider`), „Przywróć zakupy” jako link na dole.
- **Settings:** grupy z nagłówkami sekcji, wiersze z ikoną, przełączniki w kolorze PRIMARY.
