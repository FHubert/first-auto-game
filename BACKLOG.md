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

- [ ] T-108 `review` Screenshoty deterministyczne: stały zegar w trybie `--screenshot` + źródło zmian `05_themes.png` (przeniesione z Inbox T-106) → PR #94
  KA: `ScreenshotArgs.parse` przyjmuje opcjonalne `--now=<unix>` (domyślnie nowa `const SCREENSHOT_NOW_UNIX: int = 1792843200` = 2026-10-24 12:00 UTC, dzień UTC 20750); `main.gd._run_screenshot` liczy `today` z tej wartości zamiast `Time.get_unix_time_from_system()` i ustawia `app.clock` na stały `Callable` przed `add_child` (licznik „do północy” na kadrze 03 i Poziom dnia stałe). Źródło niedeterminizmu `05_themes.png` (PL/DE) ustalone i usunięte (opis przyczyny w PR). Testy gdUnit4 ≥ 2 (`--now` sparsowane; brak `--now` → `SCREENSHOT_NOW_UNIX`). Weryfikacja: `make screenshots` 2× z rzędu → `sha256sum` wszystkich PNG w `fastlane/metadata/android/*/images/phoneScreenshots/` identyczne (wynik w PR); PNG zregenerowane jednorazowo. `make check` zielone. ≤ ~60 linii + PNG.
  Skill: `aso`

- [ ] T-109 `todo` Powrót z tła (FOCUS_IN): `Level.elapsed_s` bez czasu w tle + popup nagrody dziennej po północy UTC na `Home` (przeniesione z Inbox T-104; GDD → Meta „Daily reward”, Analityka `level_complete`)
  KA: nowa `Level.resume_clock()` ustawia `_round_bound_at = int(clock.call())`; `App._notification(NOTIFICATION_APPLICATION_FOCUS_IN)` woła ją, gdy bieżący ekran to `Level`, a gdy `Home` — `home.refresh()` i `_maybe_show_daily_popup(home)` (guard `_popup_shown_day` bez zmian; w `Level` popup się nie pokazuje i runda nie jest ruszana). Testy gdUnit4 ≥ 4 ze wstrzykniętym zegarem: (1) runda 10 s → FOCUS_OUT → +3600 s → FOCUS_IN → +5 s → wygrana: `round.elapsed_s` w [15, 16], nie ≥ 3600; (2) `Home`, nagroda dnia D odebrana, FOCUS_IN w dniu D+1 → `popup_visible() == true`; (3) FOCUS_IN w tym samym dniu → `false`; (4) `Level` w dniu D+1 → brak popupu, ruchy rundy bez zmian. `make check` zielone. ≤ ~70 linii.
  Skill: `godot-dev`

- [ ] T-110 `todo` Home: widoczna meta — „Ukończone: N” na karcie Poziomu dnia (`daily_completed_total`) i rekord serii (`streak_best`) (GDD → Ekrany `Home`, Meta „Cele 30 dni”; zależy od T-108 — kadr 03)
  KA: `Home` dostaje `daily_total_label` (w karcie Poziomu dnia, `tr("home_daily_total") % state.daily_completed_total`, ukryty przy 0) i `streak_best_label` (`tr("home_streak_best") % state.streak_best`, widoczny gdy `streak_best >= 2`), odświeżane w `refresh()`. Klucze w `strings.csv` EN/PL/DE (PROPOZYCJA: „Completed: %d” / „Ukończone: %d” / „Geschafft: %d”; „Best: %d” / „Rekord: %d” / „Rekord: %d” — DE dopisać do `SAME_AS_EN`, jeśli test „≠ EN” tego wymaga, z komentarzem). Fixture `aso_home` w `ScreenshotFixtures`: `daily_completed_total = 23`, `streak_best = 12`, `streak_days = 5`. Testy gdUnit4 ≥ 3 (0 → etykieta ukryta; 23 → tekst zawiera „23”; `streak_best` 1 → ukryta, 12 → widoczna). `make screenshots` → kadr 03 ×3 locale odświeżony i obejrzany (PL), etykiety nie wychodzą poza kartę 720 px. `make check` zielone. ≤ ~60 linii + PNG.
  Skill: `godot-dev`

- [ ] T-111 `todo` Kadr sklepowy 02 (`aso_win`): plansza widoczna nad panelem LevelComplete — panel kompaktowy przy dolnej krawędzi (przeniesione z Inbox T-105; KPI store conversion ≥ 25 %; zależy od T-108 i T-101 — ten sam ekran wygranej)
  KA: panel `LevelComplete` zakotwiczony do dołu ekranu, wysokość ≤ 50 % viewportu (≤ 640 px przy 720×1280), treść bez zmian (monety, premia, ×2, „Dalej”, komunikat T-096); konfetti (T-097) nadal nad planszą i pod panelem. Test gdUnit4 ≥ 1 w scenie `Level` 720×1280 z fixture `aso_win`: `level_complete` panel `get_global_rect()` nie przecina prostokąta obejmującego probówki `BoardView` i ma `size.y <= 640`. `make screenshots` → kadr 02 ×3 locale odświeżony; na PL widać ≥ 80 % probówek (opis + ogląd w PR). `make playtest` 200/200 bez softlocka (ekran wygranej nadal działa). `make check` zielone. ≤ ~60 linii + PNG.
  Skill: `aso`

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

- [ ] T-112 `todo` `make test`: usunąć wycieki `ObjectDB instances were leaked` / `resources still in use at exit` po zakończeniu runnera (przeniesione z Inbox T-087)
  KA: źródło ustalone przez `--verbose` (lista klas/zasobów w PR); poprawki w testach (`after()`/`after_test()`, `auto_free`, `queue_free` + `await`) albo w kodzie (np. autoload trzymający referencję); log `make test` zawiera 0 wystąpień `ObjectDB instances were leaked` i 0 `resources still in use at exit`. Jeśli część wycieku pochodzi z samego addonu gdUnit4 (dowód: ta sama liczba przy uruchomieniu jednej pustej suity) — opis w PR, wpis do Inbox, a wycieki z naszego kodu = 0. Liczba testów gdUnit4 nie maleje, żadna asercja nie osłabiona. `make check` zielone. ≤ ~60 linii.
  Skill: `godot-test`

- [ ] T-113 `todo` Level: testy brzegowe wygranej bez „idealnie” i `shop_requested` przy braku monet, `buy_undo_refill` z jawnym `can_afford`, bez `@export var level` i duplikowanych fallbacków w `board_view.gd` (przeniesione z Inbox T-037 i T-038; zależy od T-101 — `LevelOffers`)
  KA: testy gdUnit4 ≥ 3: wygrana z `moves > min_moves + par_slack_moves` → `perfect_label.visible == false` i saldo + `win_reward_coins` dokładnie; podpowiedź i +3 cofnięcia przy saldzie poniżej kosztu → 1× `shop_requested` z właściwym powodem i saldo bez zmian. `LevelOffers.buy_undo_refill` sprawdza `Economy.can_afford` przed `spend` jak pozostałe `buy_*`; `@export var level` usunięte z `level.gd` (grep = 0); w `board_view.gd` `GameConfig.get_value("<klucz>")` bez literału fallbacku dla kluczy obecnych w `DEFAULTS` (grep `get_value("[a-z_]*", ` w tym pliku = 0). `make playtest` 200/200 bez softlocka. `make check` zielone. ≤ ~80 linii.
  Skill: `godot-dev`

- [ ] T-114 `todo` App: `show_level`/`show_daily_level` bez obejścia `level.round = GameRound.new()` (flaga `Level.autoload_level`) + `test_app.gd` ze wstrzykniętym zegarem (przeniesione z Inbox T-042; zależy od T-109 — `app.gd`)
  KA: `Level.autoload_level: bool = true`; `_ready` ładuje poziom tylko gdy flaga = true; `App` ustawia `false` przed `add_child` zamiast podstawiania pustej `GameRound` (grep `GameRound.new()` w `app.gd` = 0). Każda instancja `App` w `test_app.gd` dostaje stały `clock` (helper w suicie) — wynik testów nie zależy od daty systemowej; nowe testy gdUnit4 ≥ 2: z niepustym snapshotem kampanii „Graj” wznawia rundę bez wywołania `load_level` (licznik/flaga w teście); popup nagrody pokazuje się dla nieodebranego dnia zegara testu i nie pokazuje dla odebranego. Liczba testów nie maleje, `make playtest` 200/200. `make check` zielone. ≤ ~60 linii.
  Skill: `godot-dev`

- [ ] T-115 `todo` Dostępność: symbole kolorów na warstwach płynu, przełącznik w Settings (GDD → Mechaniki „Symbole kolorów”, awans z „later” w refill #6)
  KA: nowa czysta klasa `game/src/ui/color_symbols.gd` (`class_name ColorSymbols`, bez `Node`, `static func polygon(color_index: int, rect: Rect2) -> PackedVector2Array`): 12 różnych prostych kształtów (np. koło, kwadrat, trójkąt ▲/▼, romb, plus, X, gwiazda, sześciokąt, pięciokąt, półkole, pasek) wpisanych w ~45 % mniejszego boku warstwy. `TubeView.show_symbols: bool` rysuje symbol na środku każdej warstwy po `draw_colored_polygon` — kolor `#FFFFFF` (alfa 0,85), a na płynach o luminancji > 0,6 `#14213D` (stałe nazwane); `BoardView` przekazuje flagę z `state.settings.colorblind_symbols` (brak klucza / zły typ → `false`). Settings: `CheckButton` „Symbole kolorów” (klucze `set_symbols` EN/PL/DE, PROPOZYCJA „Color symbols” / „Symbole kolorów” / „Farbsymbole”, ≤ `MAX_BTN_LEN`). Testy gdUnit4 ≥ 4: 12 indeksów → 12 niepustych i parami różnych wielokątów, deterministycznie; `TubeView` z 3 warstwami i flagą → 3 narysowane symbole (licznik `symbols_drawn` po `_draw`), bez flagi → 0; brak klucza w zapisie → `false`; przełącznik w Settings zapisuje `colorblind_symbols`. Kadry sklepowe bez zmian (domyślnie wyłączone); smoke `make screenshots-smoke` dla Settings zielony. `make check` zielone. ≤ ~150 linii.
  Skill: `godot-dev`

- [ ] T-116 `todo` Generator: budżety etapów solvera jako klucze `GameConfig` zamiast stałych w `content_generator.gd` (przeniesione z Inbox G-012 — część kodowa; część GDD zrobiona w refill #6; zależy od T-107 — ten sam plik testu)
  KA: w `GameConfig.DEFAULTS` klucze `gen_quick_state_budget` = 250, `gen_exact_state_budget` = 1000, `gen_exact_max_colors` = 6 (GDD → tabela kluczy, PROPOZYCJA = obecne wartości); `ContentGenerator` czyta je przez `GameConfig.get_value`, stałe `QUICK_STATE_BUDGET`/`EXACT_STATE_BUDGET`/`EXACT_MAX_COLORS` usunięte (grep = 0). Golden hashe w `test_content_generator.gd` bez zmian i zielone (dowód, że poziomy graczy się nie zmieniły). Testy gdUnit4 ≥ 2 z nadpisaniem przez `GameConfig.apply_remote` i `GameConfig.reset()` w `after_test`: `gen_exact_max_colors = 0` → poziom 2 (3 kolory) ma `min_moves_exact == false`; po `reset()` → `min_moves_exact` poziomu 2 równe wartości sprzed zmiany (dziś oczekiwane `true` — potwierdzić przed asercją). `make sim` exit 0. `make check` zielone. ≤ ~40 linii.
  Skill: `game-economy`

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)
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
- [ ] T-029 `todo` SortSolver: optymalizacja (~0,4 ms/stan: clone planszy, canonical_key jako String, path.duplicate per węzeł → rodzic+indeks, klucz PackedByteArray/int); cel: dokładny A* dla ≥ 8 kolorów w ≤ 500 ms, wtedy min_moves_exact=true dla większości poziomów. Skill: godot-dev
- [ ] T-030 `todo` GameRound: literały wag solvera (1.0 / fallback 3.0) jako const/klucz; komentarz o limicie ACTION_BASE=16 probówek; `add_extra_tube` przez metodę SortBoard zamiast mutacji `tubes`; `undo_refill_amount` bez konsumenta do G-010. Skill: godot-dev
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

## Done (ostatnie 30)
- [x] T-057 `done` Screenshoty: fixture „pre-win” dla LevelComplete — realne wartości zamiast „+0 coins” (przeniesione z Inbox) → PR #58 (zmergowany 2026-10-24)
- [x] T-056 `done` BoardView/TubeView: warstwy płynu przycięte do kształtu probówki (dolna warstwa nie wystaje poza zaokrąglenie) (przeniesione z Inbox) → PR #59 (zmergowany 2026-10-24)
- [x] T-061 `done` Home: odstęp nad przyciskiem „Graj” w karcie Poziomu dnia + regeneracja 15 screenshotów sklepowych (zależy od T-056, T-057, T-063) (przeniesione z Inbox) → PR #60 (zmergowany 2026-10-24)
- [x] T-049 `done` Shop jako overlay nad Level — powrót bez utraty rundy i do właściwego trybu (campaign/daily) (przeniesione z Inbox; zastępuje przyjęcie z T-027) → PR #62 (zmergowany 2026-10-24)
- [x] T-041 `done` Audio: `click` na przyciskach UI, `tube_full` po przelewie zamykającym probówkę, wyciszenie na czas reklamy (przeniesione z Inbox) → PR #63 (zmergowany 2026-10-24)
- [x] T-065 `done` Docs: `docs/SETUP_HUBERT.md` — lista kroków ręcznych Fazy 4 + `CLAUDE.md` (tabela komend i lekcja o workflowach) → PR #61 (zmergowany 2026-10-24)
- [x] T-074 `done` GameState.from_dict: zły typ/zakres pojedynczego klucza → reset tego klucza do domyślnej zamiast odrzucenia całego zapisu; górny limit dla `_as_int` (przeniesione z Inbox T-032) → PR #65 (zmergowany 2026-10-24)
- [x] T-075 `done` Czysty log `make test`/`make test-tools` (SaveSystem JSON, FNV, `Image.open` w `with`) → PR #66 (zmergowany 2026-10-24)
- [x] T-076 `done` Lokalizacja PL/DE + test „PL/DE ≠ EN” + karta Poziomu dnia ukryta pod popupem → PR #67 (zmergowany 2026-10-24)
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
