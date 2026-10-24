# Backlog

Statusy: `todo` · `in_progress` · `review` (PR otwarty) · `blocked` · `done`
Każde zadanie: ID, status, tytuł, **kryterium akceptacji (KA)**, skill.
Pętla bierze pierwsze `todo` z najwyższej sekcji. Zadania P0 muszą być `done` zanim pętla wejdzie w P1.

## P0 — fundamenty (Faza 1–2)

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

<!-- Refill 2026-10-24 (continuous-dev #5, refill #3): Faza 4 — prace bez kont, bez workflowów i bez pobierania binarek (ograniczenia sesji scheduled). Kolejność = zależności. -->

<!-- Refill 2026-10-24 (continuous-dev #6, refill #4): Faza 5 prep II — jakość zapisu, polish core loopu, FTUE, czysty log CI. Bez workflowów, binarek z Releases, kont i SDK. Kolejność = zależności / wpływ na D1. -->

- [ ] T-075 `review` Czysty log `make test`/`make test-tools`: SaveSystem bez `ERROR: Parse JSON failed`, FNV bez `Cannot represent ... 64-bit`, `Image.open` w `with` (przeniesione z Inbox T-028, T-036, T-067) → PR #66
  KA: `SaveSystem.load` używa `JSON.new().parse()` + kod błędu (uszkodzony plik → stan domyślny, bez `ERROR:` w stdout); `FNV_OFFSET` w `test_content_generator.gd` jako literał ze znakiem (-3750763034362895579) — golden hashe bez zmian (test zielony bez edycji oczekiwanych wartości); `tools/test_tools.py` otwiera obrazy przez `with Image.open(...) as im`. Weryfikacja: `make test 2>&1 | grep -cE "Parse JSON failed|Cannot represent"` = 0 i `python3 -W error::ResourceWarning tools/test_tools.py` exit 0. `make check` zielone. ≤ ~40 linii.
  Skill: `godot-test`

- [ ] T-076 `review` Lokalizacja: `home_streak` i inne nieprzetłumaczone klucze w PL/DE + test „PL/DE ≠ EN” (przeniesione z Inbox T-072) → PR #67
  KA: `strings.csv`: `home_streak` PL „Seria: %d” (DE „Serie: %d” już jest); test gdUnit4 w teście lokalizacji: dla każdego klucza wartość PL i DE ≠ EN, z jawną listą wyjątków `SAME_AS_EN` w teście (≤ 5 pozycji, np. nazwa gry, „OK”). Popup nagrody dziennej na Home (kadr 04): karta Poziomu dnia ukryta na czas popupu — test gdUnit4 (`visible == false` przy otwartym popupie, `true` po zamknięciu). `make screenshots` → kadry 03/04 PL/DE odświeżone. `make check` zielone. ≤ ~60 linii + PNG.
  Skill: `aso`

- [ ] T-077 `review` BoardView: sygnał `tube_deselected` zamiast pollingu w `Level._process` + test „zły ruch w tutorialu restartuje krok” (przeniesione z Inbox T-039) → PR #__N__
  KA: `BoardView` emituje `tube_deselected` (tap w tę samą probówkę / nielegalny cel); `Level._process` nie odpytuje zaznaczenia na potrzeby tutorialu; `TEXT_HEIGHT` w `tutorial_overlay.gd` jako `const`. Testy gdUnit4: (a) zaznaczenie + odznaczenie → 1 emisja; (b) w tutorialu krok 2 → nielegalny ruch → `TutorialFlow` wraca do kroku 1, overlay wskazuje źródło; (c) poprawna sekwencja → flaga ukończenia w `GameState.settings`. `make check` zielone. ≤ ~90 linii.
  Skill: `godot-dev`

- [ ] T-078 `todo` BoardView: animacja przelewu wg GDD cz. 1 — przechylenie probówki źródłowej, ubywanie/przybywanie warstw w czasie `pour_anim_seconds`, ochrona tweenów przed `queue_free` w `_rebuild`/`resized` (przeniesione z Inbox T-035)
  KA: przelew animowany w 3 fazach (uniesienie+przechył → transfer warstw → powrót) o łącznym czasie = `pour_anim_seconds` z `GameConfig` (proporcje faz jako nazwane `const`); `_rebuild`/`resized` w trakcie animacji zabija aktywne tweeny i rysuje stan końcowy (bez błędów „freed instance” w logu). Testy gdUnit4 przez `scene_runner` z `animate=true` i symulowanym czasem: `pour_finished` emitowane dokładnie raz po ≥ `pour_anim_seconds`; `resized` w połowie animacji → stan widoku = stan `SortBoard`; tap w trakcie animacji ignorowany (input zablokowany do `pour_finished`). Kadr Level (01) obejrzany. `make check` zielone. ≤ ~150 linii.
  Skill: `godot-dev`

- [ ] T-079 `todo` BoardView: animacja cz. 2 — pulsowanie probówki zamkniętej jednym kolorem + krótka haptyka przy zamknięciu, spójnie z `tube_full` z T-041 (zależy od T-078)
  KA: po przelewie zamykającym probówkę widok odtwarza puls (skala z nazwanej `const`, czas z klucza `tube_full_pulse_seconds` w `GameConfig`, propozycja 0,25) i wywołuje haptykę przez istniejący `AudioService` (respektuje ustawienia). Test gdUnit4 z fake serwisem: 1 zamknięcie → 1 puls + 1 haptyka; przelew niezamykający → 0; restart/undo w trakcie pulsu → skala wraca do 1.0. `make check` zielone. ≤ ~70 linii.
  Skill: `godot-dev`

- [ ] T-080 `todo` Themes: motyw zastosowany od razu po `theme_selected`, nazwy motywów z kluczy `theme_name_*`, usunięcie martwej `BoardView.THEMES_PATH` (przeniesione z Inbox T-043)
  KA: `App` po `theme_selected` odświeża aktywny Level (paleta + tło + kształt) bez resetu rundy — test gdUnit4: wybór motywu przy otwartym Level → kolory warstw w `BoardView` = paleta nowego motywu, liczba ruchów bez zmian; etykiety w Themes przez `tr("theme_name_<id>")` (klucze EN/PL/DE, objęte testem kompletności z T-023); grep `THEMES_PATH` w `board_view.gd` = 0. GDD → Meta: zdanie o koszcie wg pozycji w katalogu (zgodne z `ThemeCatalog`). `make check` zielone. ≤ ~100 linii.
  Skill: `godot-dev`

- [ ] T-081 `todo` Wznowienie rundy po zabiciu aplikacji cz. 1: serializacja `GameRound` (plansza, stos undo, ładunki, ruchy, tryb, seed) + GameState schema v3 z migracją v2→v3 (zależy od T-074; wiersz w GDD → Mechaniki)
  KA: `GameRound.to_dict()/from_dict()` (czysta klasa) — round-trip: plansza, `moves`, stos undo, pozostałe ładunki undo/extra tube, `mode` (`campaign`/`daily`), numer poziomu / dzień UTC; `from_dict` z niespójnych danych (zła pojemność probówki, kolor poza paletą) → `null` (start od nowa, bez crasha). `GameState.SCHEMA_VERSION = 3`, pole `round_in_progress` (Dictionary, domyślnie pusty), migracja v2→v3 w istniejącym wzorcu. Testy gdUnit4 ≥ 5: round-trip po 3 ruchach i 1 undo; daily vs campaign; uszkodzony dict → null; migracja v2→v3; wygrana czyści `round_in_progress`. `make check` zielone. ≤ ~150 linii.
  Skill: `godot-dev`

- [ ] T-082 `todo` Wznowienie rundy cz. 2: zapis `round_in_progress` przy `FOCUS_OUT`/`WM_CLOSE_REQUEST` i przed pokazem reklamy, odtworzenie przy starcie (zależy od T-081)
  KA: `App._notification` (istniejące `FOCUS_OUT`/`WM_CLOSE_REQUEST`) i `AdService` przed pokazem zapisują bieżącą rundę; przy starcie, jeśli `round_in_progress` niepusty i zgodny (Poziom dnia z innego dnia UTC → odrzucony), „Graj” na Home wznawia tę rundę. Testy gdUnit4 z wstrzykniętym zegarem: (a) 3 ruchy → symulowany `FOCUS_OUT` → nowy `App` → Level ma te same `moves` i planszę; (b) daily z wczoraj → nowa runda; (c) wygrana → `round_in_progress` pusty; (d) wznowienie nie emituje nowego `level_start` (`FakeAnalyticsProvider`). `make check` zielone. ≤ ~120 linii.
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

- [ ] T-083 `todo` Economy drobiazgi + testy: `rewarded_bonus` z `maxi(0, …)`, `can_afford`, dwa zdarzenia Analytics w `apply_win` (przeniesione z Inbox T-033)
  KA: `rewarded_bonus` przy `multiplier < 1` (np. 0,5 lub 0) nigdy nie daje wartości ujemnej (test gdUnit4); testy `can_afford` (równo saldo → true, saldo − 1 → false); `apply_win` z premią „idealnie” rejestruje w `FakeAnalyticsProvider` dokładnie 2 eventy zasobów (nazwa i parametry wg GDD → Analityka: nagroda za wygraną + premia „idealnie”). `make sim` exit 0 bez zmiany wyników (porównanie podsumowania przed/po w opisie PR). `make check` zielone. ≤ ~60 linii.
  Skill: `game-economy`

- [ ] T-084 `todo` PlaytestBot: interstitial liczony raz na rundę w trybie random + usunięcie przestarzałego fallbacku `win_reward_coins` (przeniesione z Inbox T-045, T-046)
  KA: `maybe_show_interstitial` wołane maks. 1× na zakończoną rundę (po przegranej bez awansu nie powtarza tego samego numeru) — test gdUnit4 na bocie: 3 przegrane tego samego poziomu → ≤ 1 wywołanie na rundę, licznik `interstitials_shown` w raporcie zgodny z `FakeAdProvider`; `get_value("win_reward_coins", 10)` → `get_value("win_reward_coins")` (grep fallbacku = 0). `make playtest` 200/200 bez softlocka, `interstitials_shown` w `playtest.json` podany przed/po w opisie PR. `make check` zielone. ≤ ~50 linii.
  Skill: `godot-test`

- [ ] T-085 `todo` ConsentFlow: błąd `request_consent_info_update` (`ok=false`) → event `consent:ump:error` i ścieżka niespersonalizowana; `FakeConsentProvider` umie zwrócić `ok=false` (przeniesione z Inbox T-069)
  KA: `FakeConsentProvider` ma skryptowane `info_update_ok: bool`; przy `false` flow kończy `finished` z `can_request_ads=true`, `personalized=false`, bez pokazania formularza, i rejestruje dokładnie jeden event błędu w `FakeAnalyticsProvider` (nazwa zgodna z konwencją z GDD → Analityka; jeśli brak — dopisać wiersz w GDD). Test gdUnit4 ≥ 2 przypadki (EEA + błąd, poza EEA + błąd). `make check` zielone. ≤ ~60 linii.
  Skill: `ads-iap`

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)
- [ ] T-088 `todo` Lokalizacja PL: `btn_save_streak` „Uratuj streak” → „Uratuj serię” (spójnie z `home_streak`/`daily_streak` „Seria”); sprawdzić `MAX_BTN_LEN` i inne wystąpienia anglicyzmu „streak” w PL (odkryte w T-076). Skill: aso
- [ ] T-087 `todo` `make test`: po zakończeniu runnera `WARNING: 4 ObjectDB instances were leaked at exit` i `ERROR: 2 resources still in use at exit` (także przy zielonym przebiegu) — znaleźć źródło (`--verbose`), posprzątać w `after()`/`auto_free` (odkryte w T-075). Skill: godot-test

- [ ] T-068 `todo` ConsentFlow: brak limitu czasu po `show_consent_form`/`request_att` (gdy SDK zawiesi się po otwarciu formularza flow nie kończy się) — rozważyć osobny długi limit `consent_form_timeout_seconds` w Fazie 5 (SDK). Skill: ads-iap
- [ ] T-070 `todo` Ads.show_privacy_options: po zamknięciu opcji prywatności (callback ze statusem) ponownie ustawić `provider.set_personalized` wg nowej zgody + odświeżyć `Settings.apply_from_state` przez `Ads.consent_finished`; `Ads` jako autoload może potrzebować `process_mode = PROCESS_MODE_ALWAYS` dla `poll()` przy pauzie drzewa. Skill: ads-iap
- [ ] T-071 `todo` iOS manifest (T-053): sprawdzić, czy preset iOS Godota 4.7 generuje własny PrivacyInfo.xcprivacy z opcji `privacy/*` (nie dublować z `game/ios/PrivacyInfo.xcprivacy`) i czy engine wymaga dodatkowych kategorii required-reason API (np. DiskSpace/statfs); zweryfikować kody powodów CA92.1/C617.1/35F9.1 i linked/tracking 6 typów. Skill: store-release
- [ ] T-073 `todo` Audio/Ads: watchdog odciszenia — gdy prawdziwy provider nie wyemituje `interstitial_closed` ani nie wywoła callbacku rewarded, dźwięk zostaje wyciszony (`muted_by_ads`); dodać timeout odciszenia (klucz w GameConfig) w Fazie 5; `FakeAdProvider` hook `on_show` do testu stanu w trakcie pokazu. Skill: ads-iap
- [ ] T-086 `todo` GameState.migrate: `int(out.get("schema_version"))` przy Dictionary/Array/String może rzucić błąd — odporność na zły typ `schema_version` (traktować jak brak → v1) + test. Skill: godot-dev
- [ ] T-058 `todo` Screenshoty iOS 6,9" (1320×2868) w `fastlane/metadata/ios/<locale>/` — tylko po weryfikacji wymaganego rozmiaru w dokumentacji App Store Connect (link w zadaniu). Skill: aso
- [ ] T-059 `todo` `export/screenshots_raw/` jest ignorowane, ale `fastlane/metadata/android/*/images/` nie — ustalić politykę (commitowane tylko kadry sklepowe z T-050; smoke-screenshoty z `screens.txt` do `export/`). Skill: aso
- [ ] T-055 `blocked` CI: dokończyć T-011 — zweryfikować na stronach releases i podbić: actions/download-artifact (v4→v7?, para z upload-artifact v7), setup-java, android-actions/setup-android, ruby/setup-ruby, maxim-lobanov/setup-xcode, google-github-actions/setup-gcloud, EnricoMi/publish-unit-test-result-action; `actionlint` (w sesji bez dostępu do github.com/releases i bez pobierania binarek — zrobić w sesji z dostępem). Skill: godot-build — powód: edycja `.github/workflows/` niedostępna w sesji scheduled (jak T-002b)
- [ ] T-044 `todo` Skill game-economy §6: opis wyjścia nowego `make sim` (metryki motywów w dniach aktywnych, ads/DAU per placement, WARN zamiast błędu dla impresji, „starves" = mediana motywów do d7 < 1) — zadanie dotyczy wprost `.claude/`. Skill: game-economy

- [ ] T-006 `todo` Postawić pierwszy tag v0.1.0 (git describe w prompcie biweekly-release wymaga istniejącego taga). Skill: store-release
- [ ] T-007 `todo` Sprawdzić czy deny Edit(fastlane/Fastfile) itd. w .claude/settings.json działa jak zamierzono (metadata edytowalne, lanes nie); patrz ZWERYFIKUJ w docs/AUTOMATION.md. Skill: godot-test
- [ ] T-029 `todo` SortSolver: optymalizacja (~0,4 ms/stan: clone planszy, canonical_key jako String, path.duplicate per węzeł → rodzic+indeks, klucz PackedByteArray/int); cel: dokładny A* dla ≥ 8 kolorów w ≤ 500 ms, wtedy min_moves_exact=true dla większości poziomów. Skill: godot-dev
- [ ] G-012 `todo` GDD/ADR-009: dopisać, że generator używa etapów (quick pass 250 stanów → dokładny A* ≤ 6 kolorów/1000 stanów → ważony A*), więc `min_moves_exact=false` jest normą od ~6 kolorów (premia „idealnie" liczona od wyniku ważonego + par_slack_moves); przenieść stałe EXACT_MAX_COLORS/EXACT_STATE_BUDGET/QUICK_STATE_BUDGET z content_generator.gd do GameConfig. Skill: game-economy
- [ ] T-030 `todo` GameRound: literały wag solvera (1.0 / fallback 3.0) jako const/klucz; komentarz o limicie ACTION_BASE=16 probówek; `add_extra_tube` przez metodę SortBoard zamiast mutacji `tubes`; `undo_refill_amount` bez konsumenta do G-010. Skill: godot-dev
- [ ] T-031 `todo` PlaytestBot: test ścieżki `gave_up` (`max_restarts_per_round=0` → przegrana bez softlocka); udokumentować `--random`/`--max-restarts` w `.claude/skills/godot-test/SKILL.md` (zadanie dotyczy wprost `.claude/`). Skill: godot-test
- [ ] T-037 `todo` Level: test wygranej bez „idealnie" (ukryty `perfect_label`, tylko `win_reward_coins`); usunąć nieużywane `@export var level` po T-022. Skill: godot-dev
- [ ] T-038 `todo` Level: testy `shop_requested` dla hint/undo_refill bez środków; `buy_undo_refill` z jawnym `can_afford` (spójnie z resztą); `GameConfig.get_value` bez duplikowanych fallbacków w board_view.gd. Skill: godot-dev
- [ ] T-042 `todo` App/Level: `show_daily_level` bez obejścia `round = GameRound.new()` (flaga `autoload_level` w Level); `test_app.gd` z wstrzykniętym zegarem (teraz realny czas otwiera popup). Skill: godot-dev
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

## Done (ostatnie 30)
- [x] T-001 `done` Smoke: środowisko i pętla działają end-to-end → PR #13 (zmergowany 2026-10-23)
- [x] T-013 `done` SortBoard: model planszy water sort (czysta klasa) → PR #14 (zmergowany 2026-10-23)
- [x] T-014 `done` SortSolver: A* z heurystyką granic kolorów i limitem stanów (zależy od T-013) → PR #15 (zmergowany 2026-10-23)
- [x] G-002 `done` Parametry poziomu z GameConfig (kolory, d, breather, min_moves_floor) → PR #16 (zmergowany 2026-10-23)
- [x] G-003 `done` ContentGenerator: tasowanie z seeda + solver + regeneracja seed+attempt (zależy od T-014, G-002) → PR #17 (zmergowany 2026-10-23)
- [x] T-015 `done` GameRound na SortBoard: ruchy, cofnij, +probówka, restart, utknięcie, podpowiedź, „idealnie" (zależy od G-003) → PR #19 (zmergowany 2026-10-23)
- [x] T-016 `done` PlaytestBot = solver + tryb losowy (zależy od T-015) → PR #20 (zmergowany 2026-10-23)
- [x] T-017 `done` GameState schema v2 + migracja v1→v2 → PR #21 (zmergowany 2026-10-23)
- [x] G-004 `done` Economy: earn/spend, nagroda za wygraną, premia „idealnie", koszty boosterów (zależy od T-017) → PR #22 (zmergowany 2026-10-23)
- [x] T-018 `done` Assety wizualne: palety 4 motywów, sprite'y probówek (2 kształty), ikony UI, ikona aplikacji → PR #23 (zmergowany 2026-10-23)
- [x] G-006 `done` DailyRewards: nagroda dzienna + streak + grace (zależy od T-017) → PR #24 (zmergowany 2026-10-23)
- [x] G-007 `done` DailyChallenge: Poziom dnia z seeda dnia UTC (zależy od G-003, T-017) → PR #25 (zmergowany 2026-10-23)
- [x] T-019 `done` Scena Level: BoardView (rysowanie probówek, tap, przelew tween, shake) (zależy od T-015, T-018) → PR #26 (zmergowany 2026-10-23)
- [x] T-020 `done` HUD + LevelComplete + przepływ poziomów i zapis (zależy od T-019, G-004) → PR #27 (zmergowany 2026-10-23)
- [x] T-021 `done` StuckPanel + przyciski boosterów (ścieżka monet) (zależy od T-020) → PR #28 (zmergowany 2026-10-23)
- [x] G-005 `done` FTUE: tutorial poziomu 1 (3 kroki) (zależy od T-020) → PR #29 (zmergowany 2026-10-23)
- [x] T-022 `done` Ekrany Home + Settings + nawigacja (zależy od T-020) → PR #30 (zmergowany 2026-10-23)
- [x] T-023 `done` Lokalizacja EN/PL/DE (CSV + TranslationServer) (zależy od T-022) → PR #31 (zmergowany 2026-10-23)
- [x] T-024 `done` Audio: generowane SFX + muzyka ambient + AudioService → PR #32 (zmergowany 2026-10-23)
- [x] G-008 `done` UI dzienne: DailyRewardPopup + karta Poziomu dnia na Home + tryb daily w Level (zależy od G-006, G-007, T-022) → PR #33 (zmergowany 2026-10-23)
- [x] G-009 `done` ThemeCatalog + ekran Themes (zależy od G-004, T-018, T-022) → PR #34 (zmergowany 2026-10-23)
- [x] G-010 `done` Rewarded: 6 placementów przez Ads.request_rewarded → PR #35 (zmergowany 2026-10-23)
- [x] G-010b `done` Rewarded: przyciski UI dla 6 placementów → PR #36 (zmergowany 2026-10-23)
- [x] G-011 `done` balance_sim pod sort puzzle → PR #37 (zmergowany 2026-10-23)
- [x] G-001 `done` Balans: cap interstitiali → PR #38 (zmergowany 2026-10-23)
- [x] G-013 `done` Kalibracja ekonomii wg make sim → PR #39 (zmergowany 2026-10-23)
- [x] T-025 `done` Analityka: eventy z GDD → Analityka → PR #40 (zmergowany 2026-10-23)
- [x] T-026 `done` ADR-010 IAP + IapProvider/FakeIapProvider + Purchases.grant → PR #41 (zmergowany 2026-10-23)
- [x] T-027 `done` Ekran Shop + Przywróć zakupy + okno starter packa → PR #42 (zmergowany 2026-10-23)
- [x] T-011 `done` CI: podbicie wersji akcji (częściowo 5/12; reszta → T-055) → PR #44 (zmergowany 2026-10-23)
- [x] T-004 `done` `Gemfile.lock` wygenerowany i zacommitowany → PR #45 (zmergowany 2026-10-24)
- [x] T-002 `done` CI: wspólne, monotoniczne źródło `version_code` — część 1: `tools/version_code.sh` + testy → PR #46 (zmergowany 2026-10-24)
- [x] T-040 `done` UI: font OFL z diakrytykami (ą ć ę ł ń ó ś ź ż ä ö ü ß) jako domyślny font UI + etykieta `set_language` nad wyborem języka w Settings → PR #47 (zmergowany 2026-10-24)
- [x] T-003 `done` Tryb `--screenshot=<scene> --out=<png> [--lang=xx] [--fixture=<name>]` w `main.gd`, żeby `tools/gen_screenshots.sh` produkował obrazy → PR #48 (zmergowany 2026-10-24)
- [x] T-050 `done` Screenshoty sklepowe: 5 kadrów z `docs/ASO.md` × EN/PL/DE do `fastlane/metadata/android/<locale>/images/phoneScreenshots` → PR #49 (zmergowany 2026-10-24)
- [x] T-060 `done` UI: nieprzezroczyste tło paneli nakładkowych (LevelComplete, DailyRewardPopup, StuckPanel, karta Poziomu dnia na Home) + regeneracja screenshotów sklepowych → PR #50 (zmergowany 2026-10-24)
- [x] T-051 `done` Metadata sklepowe EN/PL/DE w `fastlane/metadata` (Android + iOS) z `docs/ASO.md` → PR #51 (zmergowany 2026-10-24)
- [x] T-052 `done` Polityka prywatności (EN/PL) + odpowiedzi do Play Data Safety i App Store Privacy Labels → PR #52 (zmergowany 2026-10-24)
- [x] T-034 `done` Bramka: `make test-tools` (uruchamia `tools/test_tools.py`) dołączony do `make check` + Pillow w `make setup` (przeniesione z Inbox) → PR #54 (zmergowany 2026-10-24)
- [x] T-062 `done` Consent: `ConsentProvider` (interfejs) + `FakeConsentProvider` + `ConsentFlow` (czysta klasa, UMP → ATT) wg GDD → Mechaniki „Zgoda UMP/ATT” → PR #55 (zmergowany 2026-10-24)
- [x] T-063 `done` Consent w UI: `Boot` czeka na `ConsentFlow.finished` przed pierwszym `Ads` load + przycisk „Opcje prywatności” w Settings (zależy od T-062) → PR #56 (zmergowany 2026-10-24)
- [x] T-064 `done` iOS: `game/ios/PrivacyInfo.xcprivacy` jako plik źródłowy (plist) zgodny z tabelą Privacy Labels w `docs/RELEASE_CHECKLIST.md` + test (bez zmian w `export_presets.cfg` — podpięcie w T-053) → PR #57 (zmergowany 2026-10-24)
- [x] T-057 `done` Screenshoty: fixture „pre-win” dla LevelComplete — realne wartości zamiast „+0 coins” (przeniesione z Inbox) → PR #58 (zmergowany 2026-10-24)
- [x] T-056 `done` BoardView/TubeView: warstwy płynu przycięte do kształtu probówki (dolna warstwa nie wystaje poza zaokrąglenie) (przeniesione z Inbox) → PR #59 (zmergowany 2026-10-24)
- [x] T-061 `done` Home: odstęp nad przyciskiem „Graj” w karcie Poziomu dnia + regeneracja 15 screenshotów sklepowych (zależy od T-056, T-057, T-063) (przeniesione z Inbox) → PR #60 (zmergowany 2026-10-24)
- [x] T-049 `done` Shop jako overlay nad Level — powrót bez utraty rundy i do właściwego trybu (campaign/daily) (przeniesione z Inbox; zastępuje przyjęcie z T-027) → PR #62 (zmergowany 2026-10-24)
- [x] T-041 `done` Audio: `click` na przyciskach UI, `tube_full` po przelewie zamykającym probówkę, wyciszenie na czas reklamy (przeniesione z Inbox) → PR #63 (zmergowany 2026-10-24)
- [x] T-065 `done` Docs: `docs/SETUP_HUBERT.md` — lista kroków ręcznych Fazy 4 + `CLAUDE.md` (tabela komend i lekcja o workflowach) → PR #61 (zmergowany 2026-10-24)
- [x] T-074 `done` GameState.from_dict: zły typ/zakres pojedynczego klucza → reset tego klucza do domyślnej zamiast odrzucenia całego zapisu; górny limit dla `_as_int` (przeniesione z Inbox T-032) → PR #65 (zmergowany 2026-10-24)
