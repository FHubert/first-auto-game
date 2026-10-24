# Backlog

Statusy: `todo` · `in_progress` · `review` (PR otwarty) · `blocked` · `done`
Każde zadanie: ID, status, tytuł, **kryterium akceptacji (KA)**, skill.
Pętla bierze pierwsze `todo` z najwyższej sekcji. Zadania P0 muszą być `done` zanim pętla wejdzie w P1.

## P0 — fundamenty (Faza 1–2)

- [ ] GH-83b `blocked` Nightly sanity (issue #90): export Android wymaga `rendering/textures/vram_compression/import_etc2_astc=true` w `game/project.godot` (sekcja `[rendering]`) — po GH-83 (PR #86) ręczny run nightly (40080077585) pada na „ETC2/ASTC texture compression is required for Android export” — powód: twarda zasada CLAUDE.md zabrania sesji scheduled zmian `project.godot` poza `[autoload]`/`[input]`/`[display]`; decyzja Huberta (jedna linia; po zmianie Godot reimportuje tekstury — bez nowych plików w repo)
  KA: `game/project.godot` ma `[rendering]` → `textures/vram_compression/import_etc2_astc=true`; `make check` zielone; `nightly-sanity` (`workflow_dispatch`) przechodzi krok „Export Android debug APK” (lub pokazuje następny, inny błąd → nowy wpis); `docs/SETUP_HUBERT.md` §15 uzupełnione. ≤ ~5 linii.
  Skill: `godot-build`

## P1 — core loop i retencja (z GDD v1.0, R-003)

<!-- Refill 2026-10-23 (continuous-dev #4): Faza 4 — pipeline wydań, tylko zadania wykonalne bez sekretów. Kolejność = zależności. -->

- [ ] T-002b `blocked` CI: podpięcie `tools/version_code.sh` w `build-android.yml`, `build-ios.yml` (krok „Resolve version”: `code="${INPUT_CODE:-$(bash tools/version_code.sh)}"` + `bash tools/version_code.sh --check "$code"`, opisy inputów w cudzysłowie) i `release.yml` (job `prepare`: dodać `actions/checkout@v7`, kod ze skryptu) (zależy od T-002) — powód: sesja scheduled (auto-mode) nie może edytować `.github/workflows/**`; wymaga sesji interaktywnej Huberta lub zmiany uprawnień
  KA: w 3 workflowach brak `GITHUB_RUN_NUMBER + 100`; jawny input `version_code` ma pierwszeństwo; YAML parsuje się (`python3 -c "import yaml,glob;[yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')]"`); `actionlint` 0 błędów; `make check` zielone. ≤ ~30 linii.
  Skill: `godot-build`

- [ ] T-005 `blocked` CI: niepodpisany build Android (debug AAB/APK) bez sekretów + weryfikacja kluczy `export_presets.cfg` i editor settings dla Godot 4.7.2 (zależy od T-011; po merge T-047 workflow ma objąć Gradle build — T-047 dopisuje ten krok) — powód: nowy workflow w `.github/workflows/` niedostępny w sesji scheduled (jak T-002b)
  KA: klucze presetu Android/iOS oraz nazwa pliku editor settings (`editor_settings-4.7.tres`) i klucze `export/android/android_sdk_path`/`java_sdk_path` porównane ze źródłem Godot 4.7.2 (linki do plików w opisie PR); różnice poprawione; `tools/validate_presets.py` sprawdza listę wymaganych kluczy (test w `tools/test_tools.py`). Nowy workflow (`workflow_dispatch` + `pull_request` z filtrem ścieżek `game/export_presets.cfg`, `tools/setup_env.sh`, `Makefile`) instaluje SDK jak `build-android.yml`, generuje debug keystore `keytool` w runnerze (bez sekretów) i robi `--export-debug Android`; job jest czerwony, gdy plik wynikowy nie istnieje lub ma 0 B; artefakt uploadowany. W `Makefile` `export-check` przestaje maskować błąd (`|| true`) przy dostępnym SDK. Rozmiar AAB w podsumowaniu joba. ≤ ~150 linii.
  Skill: `godot-build`

- [ ] T-053 `blocked` CI: niepodpisany export iOS na macOS (Xcode project + `xcodebuild` bez podpisu) i privacy manifest w presecie iOS w `export_presets.cfg` (zależy od T-005; T-048 po merge uruchamia ten workflow ręcznie jako swoją weryfikację) — powód: nowy workflow w `.github/workflows/` niedostępny w sesji scheduled (jak T-002b)
  KA: workflow tylko `workflow_dispatch` + `pull_request` z filtrem ścieżek (`game/export_presets.cfg`, `game/ios/**`) — minuty macOS są drogie; `--export-release iOS` tworzy projekt Xcode, `xcodebuild … -sdk iphoneos CODE_SIGNING_ALLOWED=NO build` kończy się exit 0. Preset iOS ma uzupełnione opcje privacy manifestu (tracking, tracking domains, collected data types zgodne z listą w `docs/RELEASE_CHECKLIST.md`, required-reason APIs) — nazwy kluczy zweryfikowane w źródle Godot 4.7.2 (link w PR); krok joba sprawdza, że wygenerowany `PrivacyInfo.xcprivacy` istnieje i zawiera `NSPrivacyTracking` i `NSPrivacyCollectedDataTypes`. ≤ ~150 linii.
  Skill: `godot-build`

<!-- Refill 2026-10-24 (continuous-dev #8, refill #5): Faza 5 prep III — wiarygodna analityka przed soft launchem (lejek poziomów i FTUE), brakujące elementy MVP z GDD (LevelComplete, konfetti), odporność zapisu. Bez workflowów, binarek z Releases, kont i SDK. Kolejność = zależności (T-093 → T-094 → T-095 dotykają `level.gd`). -->

<!-- Refill 2026-10-24 (continuous-dev #9, refill #6): Faza 5 prep IV — wiarygodne CI i kadry, powrót z tła, widoczna meta — przed soft launchem bramka `make check` nie może dawać fałszywych czerwonych (próg 500 ms), PR-y nie mogą nieść przypadkowych PNG, a powrót z tła (najczęstsza ścieżka wejścia na mobile) musi liczyć czas rundy i pokazywać nagrodę dzienną, bo to dźwignie D1/D7 z KPI.md. Kolejność = zależności (T-108 przed zadaniami regenerującymi kadry: T-110, T-111). -->

<!-- Refill 2026-10-24 (continuous-dev #10, refill #7): Faza 5 prep V — jeden źródłowy GameConfig (remote config bez cichych fallbacków), ekran wygranej odporny na długą treść, odkrywalność Poziomu dnia w pierwszej sesji (D1), wydajność solvera na słabszych telefonach. Kolejność = zależności i wpływ na KPI: T-121 i T-123 dotykają różnych plików (mogą iść równolegle; T-121 i T-122 dzielą tylko 1 linię `hud.gd`), T-122 przed T-124 (`content_generator.gd`) i przed T-127 (`game_round.gd`). -->

- [ ] T-121 `review` LevelComplete: wysokość panelu z treści zamiast stałej + jedna wysokość HUD (`level.tscn` 150 vs `hud.gd` `BAR_HEIGHT` 230) + `_reset_board_fit()` w `restart()` (obejmuje Inbox T-117; zależy od T-111 — zmergowane) → PR #104
  KA: `LevelComplete.panel_height()` = `maxf(-offset_top, get_combined_minimum_size().y)` (albo równoważne — panel nigdy nie rośnie w górę ponad zwracaną wartość); `Level.restart()` woła `_reset_board_fit()`; jedno źródło wysokości HUD: `Hud` w `level.tscn` ma `offset_bottom` równy `Hud.BAR_HEIGHT` (albo `hud.gd` ustawia go w `_ready`) — test asercją równości. Testy gdUnit4 ≥ 4 (720×1280): (1) komunikat T-096 wydłużony do 200 znaków (fixture w teście, nie w `strings.csv`) → `panel_rect()` nie przecina prostokąta probówek `BoardView` i `panel_rect().size.y == panel_height()`; (2) `BoardView.content_height()` dla planszy 1-rzędowej (5 probówek) i 2-rzędowej (14 probówek) — wartości > 0, 2 rzędy > 1 rząd; (3) wygrana → restart następnego poziomu → skala/pozycja planszy jak przed `fit_board_above_panel()`; (4) `Hud` offset = `BAR_HEIGHT`. `make screenshots` → `sha256sum` 15 PNG sklepowych bez zmian albo zmiana tylko kadru 02 z opisem w PR (ogląd PL). `make playtest` 200/200 bez softlocka. `make check` zielone. ≤ ~80 linii.
  Skill: `godot-dev`

- [ ] T-122 `review` GameConfig: zero zduplikowanych fallbacków `get_value("<klucz>", <literał>)` w `game/src` + test statyczny, że każdy klucz czytany w kodzie istnieje w `DEFAULTS` (obejmuje Inbox T-118) → PR #105
  KA: w `ad_service.gd`, `purchases.gd`, `content_generator.gd`, `game_round.gd`, `hud.gd`, `stuck_panel.gd`, `shop_screen.gd` wywołania bez literału fallbacku (dziś 41 wystąpień w 7 plikach); grep `get_value\("[a-z_]*", ` w `game/src` = 0. Nowy test gdUnit4 (np. `test_config_keys.gd`, ≥ 2 testy): (1) skan wszystkich `*.gd` w `res://src` (`DirAccess` + `RegEx` `get_value\("([a-z0-9_]+)"`) → każdy znaleziony klucz jest w `GameConfig.DEFAULTS` (lista brakujących w komunikacie asercji), liczba znalezionych kluczy ≥ 40 (ochrona przed pustym skanem); (2) brak literalnego fallbacku (ten sam skan, 0 dopasowań `get_value\("[a-z0-9_]+",`). Golden hashe generatora bez zmian, `make sim` exit 0, `make playtest` 200/200. Liczba testów nie maleje. `make check` zielone. ≤ ~90 linii.
  Skill: `godot-dev`

- [ ] T-123 `review` FTUE: odkrycie Poziomu dnia — znacznik „Nowość!” na karcie Poziomu dnia po odblokowaniu (do pierwszego wejścia) + event `nav:daily` (GDD → Ekrany `Home`, Analityka `nav`) → PR #106
  KA: `GameState.settings` dostaje klucz `daily_intro_seen` (domyślnie `false`; brak klucza / zły typ → `false`, zgodnie z T-074, bez zmiany `schema_version`). `Home` ma `daily_new_badge: Label` (`tr("home_daily_new")`, PROPOZYCJA EN „New!” / PL „Nowość!” / DE „Neu!”, kolor akcentu `#FFD166`) widoczny tylko gdy `DailyChallenge.is_unlocked(state)` i nie ukończono dziś i `daily_intro_seen == false`; `App` po `daily_pressed` ustawia `daily_intro_seen = true`, zapisuje stan i wysyła `track_design("nav:daily")` (każde wejście z karty). Fixture `aso_home` ma `daily_intro_seen = true` → `make screenshots` daje identyczne `sha256sum` 15 PNG. Testy gdUnit4 ≥ 4 (zegar wstrzyknięty): poziom 2 → znacznik ukryty; poziom 3, flaga `false` → widoczny; po `daily_pressed` → flaga `true` w zapisie i 1× `nav:daily` w `FakeAnalyticsProvider`; Poziom dnia ukończony dziś → ukryty. Klucz w `strings.csv` EN/PL/DE (test „PL/DE ≠ EN” zielony). `make check` zielone. ≤ ~70 linii.
  Skill: `godot-dev`

- [ ] T-124 `review` SortSolver cz. 1: szybsza pętla A* bez zmiany wyników — ścieżka przez rodzica zamiast `path.duplicate()` na każdy węzeł, mniej klonów planszy (obejmuje część Inbox T-029; zależy od T-122 — `content_generator.gd`) → PR #107 (cel ≥ 30 % nieosiągnięty: szum ±6 %, wąskie gardło = clone()+canonical_key — patrz T-129)
  KA: NAJPIERW (osobny commit) test regresji z zapisanymi wynikami obecnej implementacji: dla plansz startowych poziomów kampanii 2, 10, 26, 50 i Poziomu dnia 20750 — `SortSolver.solve` z budżetami 250 / 1000 / 50000 i wagami 1.0 / 3.0 (ile kombinacji ma sens, ≥ 8 przypadków) → zapisane `moves`, `exact`, `expanded` i hash `path`. Potem optymalizacja: węzeł trzyma indeks rodzica + ruch (ścieżka odtwarzana raz na końcu), bez `cur_path.duplicate()`; kolejność rozwijania (f, potem h) i klucz kanoniczny semantycznie bez zmian. Wyniki testu regresji identyczne, golden hashe generatora bez zmian, `EXPANDED_BUDGET` w `test_content_generator.gd` bez zmian. Pomiar w PR (ta sama maszyna, mediana z 3 przebiegów): czas `ContentGenerator.generate` poziomów 1..200 przed/po i p95 z logu testu generatora — cel ≥ 30 % szybciej (jeśli mniej: wynik w PR + wniosek do Inbox, bez osłabiania testów). `make playtest` 200/200, `make check` zielone. ≤ ~120 linii.
  Skill: `godot-dev`

## P2 — monetyzacja i meta (z GDD v1.0, R-003)

- [ ] T-047 `blocked` Build Android: instalacja GodotGooglePlayBilling 3.3.0 w `make setup` (tag + SHA-256) i `gradle/use_gradle_build=true` w `export_presets.cfg` (zależy od T-026, Faza 4) — powód: brak dostępu do GitHub Releases w sesji CCR — pobranie i SHA-256 w sesji Huberta (`docs/SETUP_HUBERT.md`, T-065)
  KA: `make setup` pobiera release zip pluginu do `game/addons/GodotGooglePlayBilling/` i weryfikuje SHA-256; preset Android ma Gradle build; `make check` (w tym dry-run exportu) zielone; wpis w `docs/LICENSES.md`. ~80 linii. Zadanie wprost dotyczy `export_presets.cfg`.
  Skill: `godot-build`

- [ ] T-048 `blocked` Build iOS: instalacja godot_ios_plugin_iap v0.4.0 (tag + SHA-256) i włączenie w presecie iOS w `export_presets.cfg` (zależy od T-026, Faza 4) — powód: brak dostępu do GitHub Releases w sesji CCR — pobranie i SHA-256 w sesji Huberta (`docs/SETUP_HUBERT.md`, T-065)
  KA: pliki pluginu w `game/ios/plugins/`, preset iOS go włącza, `make check` zielone, wpis w `docs/LICENSES.md` (MIT); build iOS weryfikowany na runnerze macOS w Fazie 4. ~60 linii. Zadanie wprost dotyczy `export_presets.cfg`.
  Skill: `godot-build`

- [ ] T-054 `blocked` QA na urządzeniu: podpisany AAB z Play Internal na fizycznym Androidzie + build TestFlight na iPhonie + Firebase Test Lab (zależy od T-005, T-053, T-047, T-048) — powód: brak kont Play/Apple, keystore, service account i ASC API key (`docs/SETUP_HUBERT.md` kroki 1–6)
  KA: `build-android.yml` (track `internal`) i `build-ios.yml` (TestFlight) zielone; raport QA w `docs/LOG.md`: FTUE, 20 pierwszych poziomów, Poziom dnia, daily reward, Shop + restore w sandboxie (Play test card / StoreKit sandbox), audio/haptyka, rozmiar instalacji (cel < 50 MB); Firebase Test Lab robo test bez crasha na ≥ 3 urządzeniach (sekcja „Jakość” w `docs/RELEASE_CHECKLIST.md`). Spełnienie = kryterium wyjścia z Fazy 4. Bez kodu (bugi → Inbox).
  Skill: `godot-build` + `godot-test`

<!-- Refill 2026-10-24 (continuous-dev #6, refill #4): poprawność ekonomii i raportów bota (wiarygodność make sim/playtest przed soft launchem), consent bez SDK. -->

<!-- Refill 2026-10-24 (continuous-dev #8, refill #5, P2): reklamy/consent bez SDK — odporność na zawieszony provider i zmianę zgody; refaktor Level po paczce analityki P1; spójność PL. Kolejność = zależności. -->

<!-- Refill 2026-10-24 (continuous-dev #9, refill #6, P2): Faza 5 prep IV — higiena testów i kodu Level/App po refaktorze, dostępność, generator w GameConfig — czysty log runnera i testy brzegowe ekonomii zmniejszają ryzyko crashy (crash-free ≥ 99,5 %) przed SDK, symbole kolorów zdejmują barierę 12 kolorów (D1/D7), a budżety generatora w GameConfig pozwalają stroić czas generacji remote configiem. Kolejność = zależności (T-113 po T-101, T-114 po T-109, T-116 po T-107). -->

<!-- Refill 2026-10-24 (continuous-dev #10, refill #7, P2): Faza 5 prep V — testy niezależne od daty systemowej (fałszywe czerwone o północy UTC blokują auto-merge), dostępność zweryfikowana liczbą (kontrast symboli), porządki GameRound, viralowa pętla Poziomu dnia bez SDK. Kolejność = zależności (T-125 po T-114, T-126 po T-115, T-127 po T-122). -->

- [ ] T-125 `in_progress` Testy: każda instancja `App`/`Home` w suitach dostaje stały zegar — wynik `make test` niezależny od daty i godziny systemowej (obejmuje Inbox T-119; zależy od T-114 — helper zegara w `test_app.gd`)
  KA: wspólny helper testowy (np. `game/test/helpers/test_clock.gd`, `const FIXED_UNIX` = 1792843200, dzień UTC 20750 — ten sam co `SCREENSHOT_NOW_UNIX`) użyty we wszystkich suitach tworzących `App` lub `Home` (dziś 3 suity bez zegara wg T-119 — lista w PR); grep w `game/test`: każde `App`/`home.tscn`/`Home.new` ma w tej samej funkcji/helperze przypisanie `clock` (lista miejsc w PR, 0 wyjątków). Dowód niezależności: `make test` zielone 2× — z `FIXED_UNIX` i lokalnie z `FIXED_UNIX + 86 399` (23:59:59 tego samego dnia UTC; zmiana tylko na czas pomiaru, nie commitowana) — wynik obu przebiegów w PR; dodatkowo lista pozostałych wystąpień `Time.get_unix_time_from_system` w `game/test` z uzasadnieniem w PR (cel: 0 poza helperem). Żadna asercja nie osłabiona, liczba testów nie maleje. `make check` zielone. ≤ ~80 linii.
  Skill: `godot-test`

- [ ] T-126 `review` Dostępność: kontrast symbolu kolorów ≥ 3:1 na każdym z 48 płynów (4 motywy × 12) + kadr kontrolny z symbolami (obejmuje Inbox T-120; zależy od T-115) → PR #109
  KA: `ColorSymbols.symbol_color(liquid: Color) -> Color` (czysta funkcja) wybiera `#FFFFFF` albo `#14213D` (stałe z T-115) wg wyższego współczynnika kontrastu WCAG (luminancja względna sRGB), zamiast progu luminancji 0,6; `TubeView` jej używa. Test gdUnit4 ≥ 2: dla wszystkich kolorów płynów wszystkich motywów z `ThemeCatalog` kontrast symbolu (po zmieszaniu z alfą 0,85 na kolorze płynu) ≥ 3,0 (WCAG 2.x SC 1.4.11 — non-text contrast); lista 48 wartości w logu testu; funkcja deterministyczna; jeśli alfa 0,85 nie daje 3:1 dla któregoś płynu — podnieść stałą alfy (do 1,0), nie obniżać progu. Nowy fixture `--fixture=symbols` (Level 8 kolorów, `colorblind_symbols = true`) + wpis w `tools/screens.txt` → `make screenshots-smoke` daje PNG w `export/` (nie w `fastlane/`); kadr obejrzany dla motywów Classic i Neon (opis czytelności w PR). Kadry sklepowe bez zmian (`sha256sum`). `make check` zielone. ≤ ~70 linii.
  Skill: `godot-dev`

- [ ] T-127 `review` GameRound porządki: wagi solvera z nazwanej stałej/klucza, `SortBoard.add_empty_tube()` zamiast mutacji `tubes`, test limitu `ACTION_BASE` (obejmuje Inbox T-030; zależy od T-122 — `game_round.gd`) → PR #110
  KA: w `game_round.gd` brak literału `1.0` jako wagi solvera (użyta `SortSolver.EXACT_WEIGHT`) i brak fallbacku wagi (T-122); `add_extra_tube` woła nową `SortBoard.add_empty_tube()` (test na `SortBoard`: liczba probówek +1, nowa pusta, `is_won()` bez zmian), grep `_board.tubes.append` w `game_round.gd` = 0; komentarz przy `ACTION_BASE` o limicie 16 probówek i test gdUnit4: `colors_max + empty_tubes + extra_tube_max_per_level <= GameRound.ACTION_BASE` z `GameConfig.DEFAULTS` (dziś 15 ≤ 16). Martwe ścieżki `undo_refill_amount` sprawdzone (konsument po G-010/T-101 istnieje — potwierdzić grepem w PR, inaczej usunąć). Testy gdUnit4 ≥ 2 nowe, liczba testów nie maleje, `make playtest` 200/200, golden hashe bez zmian. `make check` zielone. ≤ ~50 linii.
  Skill: `godot-dev`

- [ ] T-128 `review` Poziom dnia: „Kopiuj wynik” na ekranie wygranej trybu daily — tekst jak Wordle do schowka (awans z „later”: Mechaniki „Udostępnianie wyniku Poziomu dnia”; bez pluginu, `DisplayServer.clipboard_set`) → PR #111
  KA: czysta klasa `DailyShare` (bez `Node`) `static func text(utc_day: int, moves: int, min_moves: int, streak_days: int) -> String` — format (PROPOZYCJA, klucz `share_daily` EN/PL/DE): linia 1 `Vialo Daily #<utc_day - DailyShare.EPOCH_DAY>` (`EPOCH_DAY` = 20749, czyli #1 = 2026-10-24; stała, nie balans), linia 2 „<moves> ruchów (min <min_moves>)” + `★` gdy `moves <= min_moves + par_slack_moves`, linia 3 „Seria: <streak_days>”; bez URL do sklepu do czasu publikacji (TODO w GDD). `LevelComplete` w trybie `daily` pokazuje przycisk `btn_copy_result` (PROPOZYCJA „Copy result” / „Kopiuj wynik” / „Ergebnis kopieren”, ≤ `MAX_BTN_LEN`), w kampanii ukryty; klik → `DisplayServer.clipboard_set(text)` (przez wstrzykiwalny `Callable` dla testów), krótki komunikat „Skopiowano” i `track_design("daily:share")`. Testy gdUnit4 ≥ 4: dokładny string dla 2 zestawów danych (z ★ i bez), przycisk widoczny tylko w daily, klik → 1× callable z oczekiwanym tekstem i 1× `daily:share` w `FakeAnalyticsProvider`. Panel z T-111/T-121 nadal nie przecina probówek (test z T-111 zielony). `make check` zielone. ≤ ~100 linii.
  Skill: `godot-dev`

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)
- [ ] T-133 `todo` LevelComplete w trybie daily (po T-128): test „panel nie przecina probówek” także z widocznym `btn_copy_result` (panel wyższy o przycisk; testy T-111/T-121 pokrywają tylko kampanię) + fixture `symbols`/kadr kontrolny dla motywu Neon (T-126 oceniło Neon tylko liczbowo) (odkryte w T-128/T-126). Skill: godot-dev
- [ ] T-129 `todo` Po T-124 (SortSolver cz. 1): jeśli p95 generatora spadł ≥ 30 % — rozważyć podniesienie `gen_exact_max_colors` 6 → 8 (dokładne `min_moves` i uczciwa premia „idealnie” do ~poziomu 38) i/lub cz. 2 T-029 (klucz kanoniczny jako `PackedByteArray`/int zamiast `String`, mniej `clone()`); zmiana `gen_exact_max_colors` zmienia poziomy graczy (golden hashe) — przed soft launchem dopuszczalne, decyzja w refillu po pomiarze. Skill: game-economy
- [ ] T-092 `todo` Skill godot-test §6: format `playtest.json` o pole `interstitial_calls` (T-084) i `playtest_random.json`; `AdService`: publiczny reset `_last_interstitial_s` (test bota ustawia pole prywatne `-INF`, bo realny zegar z innych suit blokuje pokaz przy symulowanym zegarze) (odkryte w T-084). Skill: godot-test
- [ ] T-089 `todo` Skill godot-test (dotyczy `.claude/`): wzorzec testów parametryzowanych (gdlint `unused-argument` dla `test_parameters`, gdUnit opróżnia tablicę w trakcie — działa `assert_that(test_parameters).is_not_null()`) (odkryte w T-081; część kodowa `min_moves` → T-098). Skill: godot-test

- [ ] T-068 `todo` ConsentFlow: brak limitu czasu po `show_consent_form`/`request_att` (gdy SDK zawiesi się po otwarciu formularza flow nie kończy się) — rozważyć osobny długi limit `consent_form_timeout_seconds` w Fazie 5 (SDK). Skill: ads-iap
- [ ] T-071 `todo` iOS manifest (T-053): sprawdzić, czy preset iOS Godota 4.7 generuje własny PrivacyInfo.xcprivacy z opcji `privacy/*` (nie dublować z `game/ios/PrivacyInfo.xcprivacy`) i czy engine wymaga dodatkowych kategorii required-reason API (np. DiskSpace/statfs); zweryfikować kody powodów CA92.1/C617.1/35F9.1 i linked/tracking 6 typów. Skill: store-release
- [ ] T-058 `todo` Screenshoty iOS 6,9" (1320×2868) w `fastlane/metadata/ios/<locale>/` — tylko po weryfikacji wymaganego rozmiaru w dokumentacji App Store Connect (link w zadaniu). Skill: aso
- [ ] T-059 `todo` `export/screenshots_raw/` jest ignorowane, ale `fastlane/metadata/android/*/images/` nie — ustalić politykę (commitowane tylko kadry sklepowe z T-050; smoke-screenshoty z `screens.txt` do `export/`). Skill: aso
- [ ] T-055 `blocked` CI: dokończyć T-011 — zweryfikować na stronach releases i podbić: actions/download-artifact (v4→v7?, para z upload-artifact v7), setup-java, android-actions/setup-android, ruby/setup-ruby, maxim-lobanov/setup-xcode, google-github-actions/setup-gcloud, EnricoMi/publish-unit-test-result-action; `actionlint` (w sesji bez dostępu do github.com/releases i bez pobierania binarek — zrobić w sesji z dostępem). Skill: godot-build — powód: edycja `.github/workflows/` niedostępna w sesji scheduled (jak T-002b)
- [ ] T-044 `todo` Skill game-economy §6: opis wyjścia nowego `make sim` (metryki motywów w dniach aktywnych, ads/DAU per placement, WARN zamiast błędu dla impresji, „starves" = mediana motywów do d7 < 1) — zadanie dotyczy wprost `.claude/`. Skill: game-economy

- [ ] T-006 `todo` Postawić pierwszy tag v0.1.0 (git describe w prompcie biweekly-release wymaga istniejącego taga). Skill: store-release
- [ ] T-007 `todo` Sprawdzić czy deny Edit(fastlane/Fastfile) itd. w .claude/settings.json działa jak zamierzono (metadata edytowalne, lanes nie); patrz ZWERYFIKUJ w docs/AUTOMATION.md. Skill: godot-test
- [ ] T-031 `todo` PlaytestBot: test ścieżki `gave_up` (`max_restarts_per_round=0` → przegrana bez softlocka); udokumentować `--random`/`--max-restarts` w `.claude/skills/godot-test/SKILL.md` (zadanie dotyczy wprost `.claude/`). Skill: godot-test
- [ ] T-066 `todo` gen_assets: dopieścić kształt probówki `flask` (wydzielone z T-034). Skill: asset-gen

## Pytania do Huberta
- T-027: wejście do Sklepu ze StuckPanel podmieniało scenę (postęp ruchów przepadał) — rozwiązane w T-049: Shop jako overlay nad Level, powrót do tej samej rundy i trybu (campaign/daily).
- G-010: „Pomiń poziom" wyłącznie za rewarded (bez wariantu za monety); bez gotowej reklamy przycisk ukryty, zostaje restart i boostery za monety — przyjęto: tak, zgodnie z MONETIZATION, do zmiany.
- R-001: mix rynków przy soft launchu do szacowania ARPDAU — przyjęto: 30 % US / 30 % DE / 40 % PL, do zmiany (bardziej US-owy mix podnosi ARPDAU, eCPM US ~5–10× PL).
- R-001: wyróżnik na tle klonów sort puzzle — przyjęto: daily seed + odblokowywane motywy wizualne (doprecyzuje R-002), do zmiany.
- R-002: nazwa i tytuł — przyjęto: „Vialo: Water Sort Puzzle” (zapasowe: „Flaskly: Color Sort Puzzle”, „Pourio: Daily Water Sort”), do zmiany; przed Fazą 4 sprawdzić EUIPO/UPRP i dostępność w ASC/Play.
- R-002: paleta płynów — przyjęto: 12 kolorów na motyw jako wyjątek od limitu 6 kolorów UI (gatunek wymaga 12 rozróżnialnych), do zmiany.
- R-002: granica dnia (Poziom dnia, streak, daily reward) — przyjęto: UTC (zmiana o 01:00/02:00 w PL/DE), do zmiany.
- R-002: starter pack — przyjęto: 1,99 USD = 800 monet + motyw, bez remove_ads, do zmiany.
- R-002: ranking Poziomu dnia — przyjęto: brak rankingu i backendu w MVP, do zmiany.
- R-002: KPI ARPDAU — szacunek ~0,036–0,040 USD przy mixie 30/30/40 jest poniżej celu 0,05; przyjęto: jedziemy dalej, dźwignia = większy udział US w ruchu, do zmiany.
- G-006: czy odbiór nagrody dziennej podtrzymuje streak (jak ukończenie poziomu)? — przyjęto: tak, `DailyRewards.claim` woła `register_play`; w stanie grace UI najpierw oferuje `save_streak` (rewarded), do zmiany.
- Faza 4 (T-052, ankieta IARC/wiek w sklepach): grupa docelowa — przyjęto: 13+ (ogólna publiczność, bez programu Google Play „Designed for Families” i bez kategorii Kids w App Store; Families wymaga certyfikowanych SDK reklamowych i ogranicza interstitiale), do zmiany.
- Faza 4 (T-052): hosting polityki prywatności i adres kontaktowy — przyjęto: GitHub Pages z `docs/privacy/` (wymaga publicznego repo albo planu z Pages dla prywatnych; alternatywa: podstrona All In IT), kontakt `__PRIVACY_CONTACT__` do wpisania przez Huberta; tekst wymaga przeglądu prawnego przed publikacją, do zmiany.
- Faza 4 (T-053): koszt runnerów macOS w prywatnym repo — przyjęto: build iOS w CI tylko ręcznie (`workflow_dispatch`) i przy zmianach presetu iOS, nie na każdym PR, do zmiany.
- Faza 4 (T-051): kategoria sklepowa — przyjęto: Play „Puzzle”, App Store Games → Puzzle (drugorzędna: Casual), do zmiany.
- Faza 4 (T-062/T-063): brak zgody UMP/ATT — przyjęto: gra działa, reklamy niespersonalizowane (bez blokady i bez ponownego pytania w tej sesji), timeout UMP 8 s → start bez formularza; do zmiany.
- Faza 4 (STATUS): kryterium wyjścia z Fazy 4 wymaga kont (T-054) — przyjęto: faza zostaje „Faza 4”, prace bez kont prowadzone jako „Faza 5 prep” (consent flow, privacy manifest), bez formalnego przejścia; do zmiany.
- Faza 4 (T-002b, T-005, T-053, T-055): sesja scheduled w auto-mode odrzuca każdą edycję `.github/workflows/**` (Edit, python, sed — także w zadaniach „CI:”), choć `.claude/settings.json` deny `Edit(.github/workflows/**)` i CLAUDE.md pozwalają na nie w zadaniach „CI:”. Przyjęto: zadania dotykające workflowów oznaczone `blocked`, do zrobienia przez Huberta w sesji interaktywnej (albo po usunięciu deny i akceptacji w auto-mode), do zmiany.
- Refill #4 (T-081/T-082, G-014 w GDD): wznowienie przerwanej rundy po zabiciu aplikacji awansowane z „later” do MVP — przyjęto: tak, wznawiamy kampanię i Poziom dnia tylko z tego samego dnia UTC, wznowienie nie liczy się jako nowy `level_start` i nie odnawia ładunków undo, do zmiany.
- Refill #4 (T-078): tap w trakcie animacji przelewu — przyjęto: ignorowany (input zablokowany do `pour_finished`, ~`pour_anim_seconds`), nie kolejkowany, do zmiany.
- T-076: test „PL/DE ≠ EN” — KA zakładało ≤ 5 wyjątków, ale poprawne słowa identyczne z EN to 7 par (PL `btn_menu`; DE `hud_level` „Level”, `btn_pause`, `btn_shop`, `shop_title` „Shop”, `set_haptics` „Vibration”, `set_lang_system`) + endonimy `set_lang_*` i łańcuchy bez słów (format). Przyjęto: lista `SAME_AS_EN` per locale z 7 wpisami, bez wymyślania sztucznych tłumaczeń (np. „Stufe”, „Laden”); do zmiany.
- Refill #5 (T-093): definicja „porażki” w GA po wprowadzeniu wznawiania rundy — przyjęto: pauza/wyjście do Home z zapisaną rundą to `level:pause` (nie fail); fail = restart, skip albo porzucenie zapisanej rundy (`level:fail:abandon`: daily z poprzedniego dnia UTC, nadpisanie innym trybem, niespójny snapshot); fail-rate w GA = (restart + skip + abandon) / start; do zmiany.
- Refill #5 (T-096): ekran wygranej pokazuje jeden komunikat — „+1 kolor” ma pierwszeństwo przed paskiem postępu motywu (raz na 6 poziomów), w Poziomie dnia brak komunikatu; przyjęto: tak, do zmiany.
- GH-83b (nightly-sanity): export Android wymaga `import_etc2_astc=true` w `project.godot` `[rendering]` — przyjęto: wpis `blocked` do decyzji Huberta (sam włącz flagę albo dopisz wyjątek w CLAUDE.md dla zadań „CI:”/P0 z nightly), do zmiany.
- Refill #6 (T-115): symbole kolorów (dostępność) awansowane z „later” do MVP — przyjęto: tak, domyślnie wyłączone (przełącznik w Settings), symbol zależy od indeksu koloru, nie od motywu; do zmiany (alternatywa: domyślnie włączone albo pytanie w FTUE).
- Refill #6 (T-109): popup nagrody dziennej po powrocie z tła po północy UTC — przyjęto: tylko gdy aplikacja wraca na `Home`; w trakcie rundy (`Level`) nie przerywamy gry, popup pojawi się przy następnym wejściu na `Home`; do zmiany.
- Refill #6 (T-111): kadr sklepowy 02 — przyjęto: panel LevelComplete kompaktowy przy dolnej krawędzi także w grze (nie tylko w fixture kadru), żeby screenshot pokazywał prawdziwy ekran; do zmiany (alternatywa: specjalny układ tylko w trybie `--screenshot` — szybciej, ale kadr przestaje odpowiadać grze, ryzyko odrzucenia za mylące screenshoty).
- T-111: `Dim` ekranu wygranej przyciemniony do alfa 0,3 (było 0,6), żeby plansza była widoczna pod panelem także w grze — przyjęto: 0,3, do zmiany.
- Refill #7 (T-128): udostępnianie wyniku Poziomu dnia awansowane z „later” do MVP w wersji minimalnej — przyjęto: kopiowanie tekstu do schowka (bez natywnego arkusza udostępniania, który wymaga pluginu i ADR), bez linku do sklepu do czasu publikacji, numeracja „Vialo Daily #1” = 2026-10-24; do zmiany (alternatywa: odłożyć do Fazy 5 i zrobić od razu natywny share z linkiem).
- Refill #7 (T-123): znacznik „Nowość!” na karcie Poziomu dnia — przyjęto: znika po pierwszym wejściu w Poziom dnia (nie po pierwszym wyświetleniu), bez osobnego popupu/tutorialu; do zmiany (alternatywa: jednorazowy popup po ukończeniu poziomu `daily_unlock_level − 1`).
- Refill #7 (T-129, Inbox): dokładność `min_moves` w trudnych poziomach — przyjęto: po przyspieszeniu solvera (T-124) dopuszczamy podniesienie `gen_exact_max_colors` 6 → 8, co zmienia poziomy kampanii od ~26 (golden hashe) — przed soft launchem bez skutków dla graczy; do zmiany (alternatywa: zamrozić poziomy już teraz).

## Done (ostatnie 30)
- [x] T-077 `done` BoardView: sygnał `tube_deselected` + test cofnięcia kroku tutorialu → PR #68 (zmergowany 2026-10-24)
- [x] T-078 `done` BoardView: animacja przelewu w 3 fazach + ochrona tweenów → PR #69 (zmergowany 2026-10-24)
- [x] T-079 `done` BoardView: puls zamkniętej probówki + haptyka (zależy od T-078) → PR #70 (zmergowany 2026-10-24)
- [x] T-080 `done` Themes: motyw od razu po wyborze + nazwy `theme_name_*` → PR #71 (zmergowany 2026-10-24)
- [x] T-081 `done` Wznowienie rundy cz. 1: `GameRound.to_dict/from_dict` + GameState schema v3 → PR #72 (zmergowany 2026-10-24)
- [x] T-082 `done` Wznowienie rundy cz. 2: zapis przy FOCUS_OUT/WM_CLOSE/przed reklamą + wznowienie (G-014) → PR #73 (zmergowany 2026-10-24)
- [x] T-083 `done` Economy: `rewarded_bonus` ≥ 0, testy `can_afford`, 2 eventy w `apply_win` → PR #74 (zmergowany 2026-10-24)
- [x] T-084 `done` PlaytestBot: interstitial raz na rundę + bez fallbacku `win_reward_coins` → PR #75 (zmergowany 2026-10-24)
- [x] T-085 `done` ConsentFlow: błąd `request_consent_info_update` → PR #76 (zmergowany 2026-10-24)
- [x] T-093 `done` Analityka: pauza z wznawialną rundą jako `level:pause` zamiast `level:fail:quit`; porzucony snapshot jako `level:fail:abandon` → PR #78 (zmergowany 2026-10-24)
- [x] T-094 `done` Analityka: parametry `level_complete` z GDD → PR #79 (zmergowany 2026-10-24)
- [x] T-095 `done` Analityka: lejek FTUE → PR #80 (zmergowany 2026-10-24)
- [x] T-096 `done` LevelComplete: komunikat „Następny poziom: +1 kolor” albo postęp do następnego motywu → PR #81 (zmergowany 2026-10-24)
- [x] T-098 `done` Odporność zapisu: zły typ `schema_version` w `GameState.migrate` i nie-liczbowe `payload.min_moves` w `GameRound.from_dict` → PR #82 (zmergowany 2026-10-24)
- [x] GH-83 `done` Nightly sanity: `make setup` instaluje szablon Android build (gradle) — export Android w nightly-sanity (issue #83) → PR #86 (zmergowany 2026-10-24)
- [x] T-097 `done` Konfetti na wygranej w kolorach motywu, wyłączone w `--screenshot` → PR #84 (zmergowany 2026-10-24)
- [x] T-099 `done` Ads/Audio: watchdog odciszenia (`ad_unmute_timeout_seconds`, `ads:watchdog:unmute`) → PR #87 (zmergowany 2026-10-24)
- [x] T-100 `done` Consent: re-personalizacja po „Opcjach prywatności”, `consent_finished` dla Settings, `Ads` PROCESS_MODE_ALWAYS → PR #88 (zmergowany 2026-10-24)
- [x] T-102 `done` Lokalizacja PL: „Uratuj serię” zamiast „Uratuj streak” + test → PR #85 (zmergowany 2026-10-24)
- [x] T-101 `done` Refaktor: `LevelOffers` (RefCounted, sygnały) — oferty rewarded i boostery poza `Level` → PR #89 (zmergowany 2026-10-24)
- [x] T-107 `done` Test generatora: próg p95 ≤ 500 ms, sufit 2000 ms, deterministyczny budżet `expanded` → PR #92 (zmergowany 2026-10-24)
- [x] T-108 `done` Screenshoty deterministyczne: stały zegar `--now` w trybie `--screenshot` (`SCREENSHOT_NOW_UNIX`) + regeneracja `05_themes` → PR #94 (zmergowany 2026-10-24)
- [x] T-109 `done` Powrót z tła: `Level.resume_clock()` (czas w tle niewliczany) + popup nagrody dziennej po północy UTC na `Home` → PR #95 (zmergowany 2026-10-24)
- [x] T-110 `done` Home: „Ukończone: N” na karcie Poziomu dnia i rekord serii (`streak_best`) → PR #96 (zmergowany 2026-10-24)
- [x] T-111 `done` Kadr 02: panel LevelComplete przy dolnej krawędzi, plansza widoczna nad panelem → PR #97 (zmergowany 2026-10-24)
- [x] T-113 `done` Level: testy brzegowe wygranej/`shop_requested`, `buy_undo_refill` z `can_afford`, bez `@export var level` i fallbacków w `board_view.gd` → PR #98 (zmergowany 2026-10-24)
- [x] T-116 `done` Generator: budżety etapów solvera jako klucze `GameConfig` (`gen_*`) → PR #99 (zmergowany 2026-10-24)
- [x] T-114 `done` App: flaga `Level.autoload_level` zamiast `GameRound.new()` + `test_app.gd` ze stałym zegarem → PR #100 (zmergowany 2026-10-24)
- [x] T-115 `done` Dostępność: symbole kolorów na warstwach płynu (`ColorSymbols`) + przełącznik w Settings → PR #101 (zmergowany 2026-10-24)
- [x] T-112 `done` `make test` bez wycieków ObjectDB/zasobów — cykl `ConsentFlow` ↔ `FakeConsentProvider` w `test_consent_flow.gd` → PR #102 (zmergowany 2026-10-24)
