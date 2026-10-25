# Odbiór UI v2 (T-236) — 2026-10-25

Metoda: `tools/gen_screenshots.sh --store` (15 kadrów 1080x1920 EN/PL/DE) + smoke (12 kadrów raw 1080x1920). Wejście: kadry oglądane wzrokowo vs `docs/ui/mockups/*.png` (1170x2532). Obejrzano kadry DE (store) i smoke EN; kadry EN/PL store nie były oglądane osobno. Rozdzielczość 720x1280 i 720x1560: skrypt generuje tylko 1080x1920 -> NIE SPRAWDZONO.
Werdykt ogólny: FAIL (2 ekrany z błędami układu, 5 z odstępstwami od makiet).

| Ekran | Makieta | Kadr | Wynik | Odstępstwa |
|---|---|---|---|---|
| Level (HUD+plansza) | 01_level | smoke 02_level, DE 01_pour | PASS (drobne) | Przyciski akcji to zaokrąglone kwadraty, w makiecie okręgi; 4. przycisk pokazuje "Ad" (DE "Werbung", ~10 px od krawędzi przycisku), makieta: moneta 60; przycisk pauzy/HUD zgodny; brak ucięć w DE; plansza w smoke 1 wystaje (4 probówki w środku), akceptowalne. |
| StuckPanel | 02_stuck | smoke 04_stuck_panel | FAIL | (1) Przycisk zamknięcia X: tło-krążek ucięte (widoczny tylko dolny łuk, ~120 px) - nakładanie/clip. (2) Wiersze: 2x "Extra tube" (Ad + 60) i brak wiersza "Hint 25" (makieta: Cofnij, Dodatkowa probówka (Reklama), +3 cofnięcia 20, Podpowiedź 25). (3) Tło pod panelem: probówki ucięte przez panel, makieta pokazuje pełne probówki ściemnione. |
| LevelComplete | 03_level_complete | DE 02_relax | FAIL | (1) Szare tło (#37383c) u góry i dołu zamiast granatowego. (2) Tytuł "Super!" nakłada się na probówki; etykieta "LEVEL 20" ucięta pasem tła. (3) Probówki w 2 rzędach 4+4 zamiast jednego rzędu 8 małych (makieta). (4) Brak paska postępu do motywu i podtytułu "15 za wygraną + 10..."; zamiast niego tekst "Nächstes Thema: 350 / 600". (5) Przycisk x2: ikona reklamy przy lewej krawędzi, etykieta nie wyśrodkowana (makieta: ikona+tekst razem); strzałka "Weiter ->" przy prawej krawędzi, w makiecie obok tekstu. |
| Home | 04_home | DE 03_daily | FAIL | (1) Szare tło (#4d4d4d) zamiast granatowego #14213D - ewidentny brak tła. (2) Logo-probówki to płaskie prostokąty z grubą ramką, bez zaokrąglonego dna, mniejsze niż w makiecie (~130 px vs ~260 px wys.). (3) Przycisk "Spielen: Level 20" bez dwuliniowego układu (Graj / Poziom 20). (4) Karta Tagesrätsel: brak plakietki NEW, brak kolumn Nagroda/Nowy za; timer 12:00:00 sklejony z "Geschafft: 23" w jednej linii (prawie ucięty przy 1024 px). (5) Pigułka Serie/Rekord: dwa rozmiary tekstu, ok. (6) Dolny rząd nawigacji zgodny. |
| DailyRewardPopup | 05_daily_reward | DE 04_streak | PASS (drobne) | X zamknięcia: tło-krążek ucięty jak w StuckPanel (~100 px). Ekran pod spodem prześwituje (tekst "Themen/Shop" widoczny pod kartą - przycina się o dolną krawędź karty, makieta ma jednolite tło). Siatka dni, check-y, przyciski zgodne; DE bez ucięć. Tag 7 nagłówek niżej (1 px różnicy), ok. |
| Themes | 06_themes | DE 05_themes | FAIL | (1) Miniatury to płaskie prostokąty (brak zaokrąglonych probówek/dna). (2) Brak ceny w pigułkach (makieta: moneta + 600/1080/1944, przycisk z obwódką złotą) - fixture ma wszystkie odblokowane, ale brak wariantu zablokowanego do weryfikacji. (3) Brak karty postępu "Do motywu..." na dole. (4) Aktywny motyw: znacznik check jest, ale na karcie Pastell, nie Klasycznego - zgodne z fixture. (5) Przycisk wstecz: strzałka niewyśrodkowana w krążku (przesunięta w lewo). |
| Shop | 07_shop | smoke 09_shop_screen (EN) | FAIL | (1) Brak karty "Pakiet startowy" (obwódka, timer, 800 monet + motyw). (2) Brak podtytułów skalowanych ("Około 8 dodatkowych...", "+20 % gratis"); opisy "+500 coins" zamiast. (3) Brak linii "Przywróć zakupy" w stylu linku (jest, ale jako szary Button, bez podkreślenia). (4) Strzałka wstecz niewyśrodkowana. Ceny w $ zamiast lokalnych - zgodne z fixture. |
| Settings | 08_settings | smoke 06_settings_screen (EN) | FAIL | (1) Brak kafelków-ikon (makieta: ikona w zaokrąglonym kwadracie CARD_ICON), ikony gołe. (2) Brak separatorów między wierszami. (3) Wiersz "Notifications" używa ikony głośnika (ta sama co "Sound effects") - zła ikona; makieta nie ma wiersza (nowa funkcja, brak makiety). (4) Language: przycisk OptionButton "System" z cieniem i małą strzałką (~14 px) zamiast wiersza "Polski >". (5) Brak wiersza "Opcje prywatności". (6) Przełączniki mniejsze niż w makiecie (~72x40 vs ~125x70 px po przeskalowaniu), (7) "Restore purchases" ma strzałkę -> zamiast ikony cofania i chevrona. (8) Stopka "v0.1.0 (dev)" zamiast "Vialo · wersja [NUMER BUILDU]". |

Ekrany w makietach bez kadru: 09_tokens (referencja komponentów, nie ekran). Kadry smoke `01_main`, `10_symbols`, `11_symbols_neon`, `12_plateau_assist` poza zakresem.
Kadry store 1 (level) i 4 (daily) oraz PL/EN: nie oglądane indywidualnie poza DE; teksty PL w store nie zweryfikowane wzrokowo.

## Szare domyślne kontrolki / tekst < 24 px
- Szare tło ekranów: `Home` i `LevelComplete` renderują się na szarym tle (#4d4d4d / #37383c) - domyślny kolor tła okna zamiast `UiTokens.BG`. Pliki: `game/src/ui/home.gd` (tło ustawione tylko jako `BG_DEEP` stylebox w l.174 - sprawdzić, czy root ma ColorRect/panel tła), `game/src/ui/level_complete.tscn` / `level_complete.gd`.
- `Button.new()` / `Label.new()` bez `theme_type_variation` w pobliżu (do weryfikacji, czy dziedziczą styl z theme): 
  - `game/src/ui/shop_screen.gd:145` (restore_button, tylko override koloru), 
  - `game/src/ui/settings_screen.gd:160` (wiersz Restore) i `:172` (CheckButton, tylko icon_max_width/h_separation - przełączniki rysowane ikonami, bez wariantu), 
  - `game/src/ui/assist_bar.gd:24` i `:48` (tylko font_size override, bez wariantu - nie widoczne w kadrach), 
  - `game/src/ui/stuck_panel.gd:116` (Label tylko override size/color), 
  - `game/src/ui/home.gd:132` (logo Label), `home.gd:200`, 
  - `game/src/ui/hud.gd:180/184/229/270/299/317` (Label HUD: sprawdzić warianty), 
  - `game/src/ui/tutorial_overlay.gd:27`, `game/src/ui/level_complete.gd:60` ma wariant. 
  Wzrokowo na kadrach brak "szarych domyślnych" przycisków ani labeli w kolorze systemowym; wyjątek: szare tła ekranów (powyżej) i OptionButton w Settings (styl ButtonSecondary - OK).
- Tekst < 24 px: najmniejszy token `UiTokens.FONT_XS = 24` (ui_theme.tres: ButtonNav/LabelSection 24). Brak literału font_size < 24 w `game/src/` (grep). Wzrokowo w kadrach 1080x1920 najmniejszy tekst ~ "Rekord: 12" na pigułce Home (~28 px) i strzałka dropdownu (ikona ~14 px - nie tekst). Pomiar pikselowy nie wykonywany.

## Playtest seed 42
`make playtest`: exit 0, softlocks 0, errors [], wins/rounds 200/200, avg_steps 35.24, coins_end 3100, interstitials_shown 39.
Log skryptu screenshotów: 0 wystąpień `ERROR`/`SCRIPT ERROR`, 0 `WARNING` (store i smoke).

## Zadania naprawcze (propozycje, ≤ 300 linii każde, z plikami)
- T-272 Tła ekranów: Home i LevelComplete na `UiTokens.BG` (ColorRect/panel pełnoekranowy lub default clear color); usunąć szare tło. Pliki: `game/src/ui/home.gd`, `game/src/ui/level_complete.gd`/`.tscn`, test układu w `game/test/unit/`.
- T-273 LevelComplete: układ jak 03_level_complete (jeden rząd 8 mini-probówek nad kartą, tytuł bez nakładania, etykieta poziomu bez ucięcia, pasek postępu motywu + linia rozbicia nagrody, wyśrodkowane ikony w przyciskach). Plik: `game/src/ui/level_complete.gd`, `level_complete.tscn`.
- T-274 Close X w StuckPanel/DailyRewardPopup: krążek tła nie ucięty (rozmiar/min_size przycisku, nie wystaje poza kartę). Pliki: `game/src/ui/stuck_panel.gd`, `game/src/ui/daily_reward_popup.gd:150`.
- T-275 StuckPanel: wiersze zgodne z makietą (Undo free / Extra tube Ad / +3 undo 20 / Hint 25), usunąć zdublowany wiersz Extra tube za monety lub uzasadnić ADR/GDD. Plik: `game/src/ui/stuck_panel.gd`.
- T-276 Home: logo-probówki rysowane jak `TubeView` (zaokrąglone dno, 2x większe), przycisk Graj dwuliniowy, plakietka NEW, kolumny Nagroda/Nowy za w karcie dziennej, timer w osobnej linii. Plik: `game/src/ui/home.gd`.
- T-277 Themes: miniatury z zaokrąglonymi probówkami, ceny (moneta + cena) dla zablokowanych, karta postępu "Do motywu..." na dole, wyśrodkowana strzałka wstecz (`screen_header.gd`). Pliki: `game/src/ui/themes_screen.gd`, `game/src/ui/screen_header.gd`.
- T-278 Shop: karta "Pakiet startowy" (obwódka, timer, CTA), podtytuły ("około N prób", "+20 % gratis"), link "Przywróć zakupy" z podkreśleniem. Plik: `game/src/ui/shop_screen.gd`, teksty w `game/assets/i18n`.
- T-279 Settings: kafelki ikon `CARD_ICON`, separatory wierszy, większe przełączniki, wiersz Language jako "wartość >", wiersz "Opcje prywatności", poprawna ikona Notifications, stopka "Vialo · wersja X". Plik: `game/src/ui/settings_screen.gd`.
- T-280 Narzędzie screenshotów: dodać tryb 720x1280 i 720x1560 (DE) do `tools/gen_screenshots.sh`/`tools/screens.txt` oraz kadry stanów: Themes z zablokowanymi motywami, Shop z pakietem startowym - aby KA T-236 było weryfikowalne.
