# Ponowny odbiór UI v2 (T-236b / T-283) — 2026-10-25
Metoda: worktree gałęzi task/T-283 (zawiera T-272…T-282). Uruchomiono:
- `bash tools/gen_screenshots.sh --store --size 720x1560` — 15 PNG EN/PL/DE (po 5 na locale: 01_pour, 02_relax, 03_daily, 04_streak, 05_themes) do przeglądu w proporcji makiety.
- `bash tools/gen_screenshots.sh --size 720x1280` — smoke 15 kadrów EN (`export/screenshots_framed/720x1280/`), nowe względem T-236: 13_shop_starter, 14_daily_streak3, 15_themes_locked.
- Na koniec `bash tools/gen_screenshots.sh --store` (1080×1920) — właściwe kadry sklepowe; `make screenshots-smoke` exit 0 (~28 s).

Obejrzano wzrokowo vs makiety `docs/ui/mockups/01…08`: store 1560 DE (01_pour, 02_relax, 03_daily, 04_streak, 05_themes; DE ma najdłuższe napisy — PL/EN store nie oglądane osobno) oraz smoke 1280 EN (02_level, 03_level_complete, 04_stuck_panel, 05_home, 06_settings_screen, 13_shop_starter, 14_daily_streak3, 15_themes_locked). Żaden ekran nie ma szarego tła ani szarych domyślnych kontrolek. Pomiaru pikselowego tekstu < 24 px nie wykonano; najmniejsze napisy to podpisy 24–28 px.

Werdykt ogólny: **PASS (8/8 PASS; 5 z nich „PASS (drobne)”)**

| Ekran | Makieta | Kadr | Wynik | Odstępstwa |
|---|---|---|---|---|
| Level | 01_level | store DE 01_pour; smoke 02_level | PASS (drobne) | Tło OK, HUD (pauza/tytuł/pill monet) zgodny, plansza bez ucięć. (a) Przyciski akcji to nadal zaokrąglone kwadraty (makieta: okręgi) — T-269. (b) Podpis 4. przycisku to „Werbung/Ad” z ikoną video, a w makiecie moneta + 60. (c) Plansza w smoke (4 probówki) ścieśniona do góry. Brak ucięć w DE. |
| StuckPanel | 02_stuck | smoke 04_stuck_panel | PASS (drobne) | Przycisk X to pełny krążek. Cztery wiersze zgodne z makietą: Cofnij (Free), Extra tube (Ad), +3 undos (20), Hint (25); dół: Restart i Skip; tło pod panelem to pełne ściemnione probówki. (a) Wiersz „+3 undos” używa tej samej ikony co Cofnij (makieta: cofnij z zegarem). (b) Pod panelem sztuczny stan `show_sample()` — T-281. |
| LevelComplete | 03_level_complete | store DE 02_relax; smoke 03 | PASS (drobne) | Granatowe tło, brak nakładania; „Super!”, „LEVEL 20” bez ucięcia; pill „Perfekt!”, +25, linia rozbicia, pasek „Nächstes Thema”, przyciski ×2 i Weiter z wyśrodkowaną ikoną. (a) W smoke 1280 4 probówki stykają się z górną krawędzią karty (panel wyższy przy niskim ekranie). (b) Miniatury małe i ściemnione (makieta: pełne kolory, rząd 8). (c) Smoke ma dodatkową linię „Next level: +1 color”, której nie ma w makiecie. |
| Home | 04_home | store DE 03_daily; smoke 05_home | PASS (drobne) | Tło OK; logo z probówkami o zaokrąglonym dnie, Graj dwuliniowy, pill monet i serii „5 Tage · Rekord 12”; karta dzienna z kolumnami Belohnung/Neu in, timer w osobnej linii, bez ucięć w DE; pasek „Bis Pastell 350/600”; nawigacja zgodna. (a) Brak plakietki NOWOŚĆ/NEW w kadrze store (fixture `aso_home` — badge zależy od stanu). (b) W smoke przycisk „Play” w karcie szary, bo stan zablokowany („From level 3”). |
| DailyRewardPopup | 05_daily_reward | store DE 04_streak; smoke 14_daily_streak3 | PASS (drobne) | X to pełny krążek; pill „Serie”, tytuł, siatka dni 1–7 (check-i, „dziś” z obwódką ACCENT, Dzień 7 szerszy), przyciski Abholen i ×2; tło jednolicie przyciemnione; brak ucięć w DE. (a) Karta niższa niż w makiecie. (b) Ikona video w ×2 przy lewej krawędzi, nie obok tekstu (DE i EN). |
| Themes | 06_themes | store DE 05_themes; smoke 15_themes_locked | PASS | Miniatury z zaokrąglonymi probówkami, aktywny motyw z check-iem i obwódką, ceny (moneta + 600/1944) w pigułkach ze złotą obwódką; karta postępu „Do motywu…” z podpisem; strzałka wstecz wyśrodkowana; brak ucięć. |
| Shop | 07_shop | smoke 13_shop_starter | PASS (drobne) | Karta „Pakiet startowy” z obwódką, plakietką, timerem, miniaturą, „800 coins + Neon theme” i CTA; podtytuły „About 8 extra tubes”, „+20 % free”; „Restore purchases” jako link z podkreśleniem; strzałka wstecz wyśrodkowana. (a) Lista w ScrollContainer — przy 1280 wiersz „No ads” przycięty, pod nim pusty pas ~100 px przed linkiem. (b) Timer bez ikony zegara. (c) 1500 monet z jedną monetą. (d) „Bez reklam” bez przekreślonego video — T-287. |
| Settings | 08_settings | smoke 06_settings_screen | PASS (drobne) | Kafelki ikon `CARD_ICON`, separatory, przełączniki ~112×64, Language jako „System ›”, Restore z ikoną cofania i chevronem, nagłówki sekcji, dzwonek przy Notifications (wiersz bez makiety), stopka „Vialo · version 0.1.0”. (a) Brak wiersza „Opcje prywatności” w kadrze — widoczny tylko gdy `Ads.is_privacy_options_required()` (fixture bez consentu) — poprawne. |

## Resztki P3
- T-266: restore ma strzałkę kołową i chevron w Settings, dzwonek jest — zgodne; przekreślone `video` dla „Bez reklam” nadal brakuje (`shop_screen.gd` mapuje `remove_ads` na `video`) — pokrywa T-287 → T-266 zamknięte jako scalone w T-287.
- T-269: przyciski HUD (pauza i 4 akcje) to nadal zaokrąglone kwadraty, makieta ma okręgi — zostaje otwarte (wariant `ButtonHud` w `ui_theme.tres`, promień `HUD_BTN/2`, użyty w `hud.gd`/`assist_bar.gd`; KA: kadr `02_level` z okręgami + test; ≤ 40 linii).
- T-281: kadr `stuck_panel` to nadal `show_sample()` (Level 1, 3 ruchy do celu), nie prawdziwe utknięcie — zostaje otwarte bez zmian.

## Drobne do Inbox
- Level: 4. przycisk akcji pokazuje „Ad/Werbung” z ikoną video, makieta: moneta + 60 (zweryfikować z GDD — reklama ma pierwszeństwo wg T-230).
- StuckPanel: ikona „+3 cofnięcia” różni się od ikony w makiecie (cofnij z zegarem).
- LevelComplete: miniatury probówek ściemnione i małe; przy 1280 karta dochodzi do dołu probówek; dodatkowa linia „Next level: +1 color” spoza makiety.
- Home: plakietka NOWOŚĆ/NEW niewidoczna w kadrze store `aso_home`.
- DailyRewardPopup: ikona video w ×2 przy lewej krawędzi (powinna stać obok tekstu jak w LevelComplete).
- Shop: ikony zegara / `coins_stack` / przekreślone `video` (T-287); przy 1280 pusty pas pod ScrollContainerem i ucięty wiersz „No ads”.

## Kadry sklepowe
- `--store` 1080×1920: 15 PNG zmienionych w `fastlane/metadata`; `make screenshots-smoke`: exit 0.

## Decyzja
PASS → kadry sklepowe `fastlane/metadata/android/{en-US,pl-PL,de-DE}/images/phoneScreenshots/*.png` (15 PNG 1080×1920) podmienione w tym PR. Drobne odstępstwa → Inbox T-289…T-294 (BACKLOG.md). Resztki P3: T-266 scalone w T-287 (zamknięte), T-269 i T-281 zostają otwarte w P3.

## Refill #18 (T-299, 2026-10-26)
Metoda: worktree task/T-299 (zawiera T-300…T-303). Uruchomiono `bash tools/gen_screenshots.sh --store` (exit 0, 15 PNG EN/PL/DE przegenerowane), `make screenshots-smoke` (exit 0, 1280), `bash tools/gen_screenshots.sh --size 720x1560` (exit 0). Obejrzano: store DE 01…05, smoke 1280 (02, 03, 04, 05, 13, 14, 15, 16) oraz 1560 (13_shop_starter) vs makiety `docs/ui/mockups/01…07`. PL/EN store nie oglądane osobno. Odstępstwa „(drobne)” z T-283 zniknęły: okrągłe HUD (T-301), 4. przycisk z monetą + 60 w `01_pour`, ikona undo_clock w „+3 undos”, probówki LevelComplete w pełnych kolorach z odstępem od karty, badge „Neu!” w Home store, ikona video przy „×2”, Shop: zegar/coins_stack/video_off, pigułki Themes bez artefaktu. Brak ucięć tekstu w DE.

Werdykt ogólny: **PASS (7/7 PASS (drobne))**

| Ekran | Makieta | Kadr | Wynik | Odstępstwa |
|---|---|---|---|---|
| Level | 01_level | store DE 01_pour; smoke 02_level, 16_stuck_deadlock | PASS (drobne) | Okrągłe przyciski HUD, 4. przycisk z monetą + 60, plansza bez ucięć. (a) W smoke 02_level (Level 1) 4. przycisk to „Ad” z ikoną video — zamierzone (reklama ma pierwszeństwo, T-230). (b) Plansza w smoke (4 probówki) mała, dużo pustego miejsca. (c) 16_stuck_deadlock: ściemnione probówki pod panelem, brak ucięć. |
| StuckPanel | 02_stuck | smoke 04_stuck_panel | PASS (drobne) | Cztery wiersze, X krążek, ikona undo z zegarem w „+3 undos”, Restart + Skip. Pod panelem nadal `show_sample()` (T-281, otwarte w P3). |
| LevelComplete | 03_level_complete | store DE 02_relax; smoke 03 | PASS (drobne) | Probówki w pełnych kolorach, wyraźny odstęp od karty także w smoke, brak ucięć w DE. (a) Pill „Perfekt!” bez gwiazdki (makieta ma ★). (b) Smoke ma dodatkową linię „Next level: +1 color”. (c) Rząd 6 pełnych + 2 puste w makiecie vs 6 mieszanych + 2 puste w fixture store (zawartość, nie UI). |
| Home | 04_home | store DE 03_daily; smoke 05_home | PASS (drobne) | Badge „Neu!” widoczny w store, Spielen/Belohnung/Neu in, bez ucięć w DE. (a) Opis „Dasselbe Level für alle · geschafft 23” w jednej linii (makieta: dwie) — OK. (b) Smoke: Play zablokowany (stan „From level 3”) — poprawne. |
| DailyRewardPopup | 05_daily_reward | store DE 04_streak; smoke 14_daily_streak3 | PASS (drobne) | Ikona video obok tekstu ×2, X krążek, siatka dni z check-ami i obwódką „dziś”, brak ucięć. (a) Karta niższa niż w makiecie, widoczne tło Home. (b) Aktywny kafel podpisany „Tag 5” zamiast „Dziś” (makieta). |
| Themes | 06_themes | store DE 05_themes; smoke 15_themes_locked | PASS | Pigułki cen bez artefaktu, aktywny motyw z check-iem i obwódką, karta postępu, brak ucięć. Różnica kolejności motywów (Neon aktywny) wynika ze stanu fixture. |
| Shop | 07_shop | smoke 13_shop_starter (1280 i 1560) | PASS (drobne) | Ikony zegara, coins_stack i video_off obecne; brak pustego pasa pod listą na 1280. (a) Na 1280 wiersz „No ads” nadal przycięty na dole ScrollContainera (lista przewijana, widoczny scrollbar). (b) Na 1560 ~270 px wolnego miejsca między listą a „Restore purchases” (makieta: link tuż pod listą). |

## Decyzja
Wszystkie ekrany PASS lub PASS (drobne), brak FAIL → kadry sklepowe `fastlane/metadata/android/{en-US,pl-PL,de-DE}/images/phoneScreenshots/*.png` (15 PNG) podmienione w tym PR. Drobne odstępstwa (Shop 1280 przycięty wiersz „No ads”, Shop 1560 wolny pas, brak ★ w pillu LevelComplete, „Tag 5” zamiast „Dziś”) do Inbox; nie blokują.
