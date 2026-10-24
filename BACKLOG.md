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

- [ ] T-062 `review` Consent: `ConsentProvider` (interfejs) + `FakeConsentProvider` + `ConsentFlow` (czysta klasa, UMP → ATT) wg GDD → Mechaniki „Zgoda UMP/ATT” → PR #55
  KA: `game/src/systems/consent_provider.gd`, `fake_consent_provider.gd` (skryptowane odpowiedzi: `region_eea`, `form_required`, `ump_status`, `att_status`, `privacy_options_required`, opóźnienie), `consent_flow.gd` bez `Node` (zegar wstrzykiwany). Klucz `consent_timeout_seconds` = 8 w `GameConfig`. Test gdUnit4 ≥ 6 przypadków: EEA+zgoda → `personalized=true`; EEA+odmowa → `can_request_ads=true`, `personalized=false`; poza EEA → bez formularza; timeout → `finished` z `personalized=false`; iOS ATT denied → `personalized=false`; ATT nie pytany po odmowie UMP. Każdy przypadek: dokładnie jedno `report_consent("ump", …)` (i `"att"` na iOS) zarejestrowane w `FakeAnalyticsProvider` przez `Ads.report_consent`. Bez SDK i bez zależności. `make check` zielone. ≤ ~220 linii.
  Skill: `ads-iap`

- [ ] T-063 `review` Consent w UI: `Boot` czeka na `ConsentFlow.finished` przed pierwszym `Ads` load + przycisk „Opcje prywatności” w Settings (zależy od T-062) → PR #56
  KA: `App`/Boot uruchamia `ConsentFlow` z `FakeConsentProvider` (domyślnie „poza EEA”, natychmiast), `AdService` odrzuca `request_rewarded`/interstitial, dopóki flow nie skończył (test gdUnit4: wywołanie przed `finished` → `false`, po → zgodnie z fake); `personalized` przekazywane do `AdProvider` (pole/metoda w interfejsie, fake je zapisuje — test). Settings: przycisk `set_privacy_options` (klucz w `strings.csv` EN/PL/DE, ≤ 18 znaków, przechodzi test fontu z T-040) widoczny tylko gdy `privacy_options_required`; tap woła `ConsentProvider.show_privacy_options()` (test na fake: licznik wywołań = 1; ukrycie przy `false`). Polityka prywatności (`docs/privacy/*.md`) — usunąć `ZWERYFIKUJ` przy „Settings → privacy options”, jeśli ścieżka w UI zgodna. Screenshot Settings odświeżony w `tools/screens.txt`. `make check` zielone. ≤ ~200 linii.
  Skill: `ads-iap`

- [ ] T-064 `review` iOS: `game/ios/PrivacyInfo.xcprivacy` jako plik źródłowy (plist) zgodny z tabelą Privacy Labels w `docs/RELEASE_CHECKLIST.md` + test (bez zmian w `export_presets.cfg` — podpięcie w T-053) → PR #57
  KA: plist z `NSPrivacyTracking` (true — AdMob z ATT), `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes` (typy z tabeli T-052), `NSPrivacyAccessedAPITypes` (UserDefaults / FileTimestamp / SystemBootTime z kodami powodów — każdy kod z linkiem do dokumentacji Apple w komentarzu PR albo `ZWERYFIKUJ`). Test w `tools/test_tools.py`: `plistlib.load` parsuje plik, 4 klucze główne istnieją, każdy typ danych z tabeli Privacy Labels występuje w `NSPrivacyCollectedDataTypes` (i odwrotnie). Domeny trackingu SDK: tylko potwierdzone w dokumentacji Google, inaczej pusta lista + `ZWERYFIKUJ` w `docs/RELEASE_CHECKLIST.md`. `make check` zielone (po T-034 test wchodzi w bramkę). ≤ ~120 linii.
  Skill: `store-release`

- [ ] T-057 `review` Screenshoty: fixture „pre-win” dla LevelComplete — realne wartości zamiast „+0 coins” (przeniesione z Inbox) → PR #58
  KA: fixture kadru LevelComplete w `ScreenshotFixtures` ustawia `show_result` z wartościami z ekonomii (`win_reward_coins` + premia „idealnie” z `GameConfig`, nie literały) — test gdUnit4: etykieta monet po fixture ≠ „+0” i równa `Economy`-wyliczonej kwocie; `perfect_label` widoczny. `make screenshots` → kadr 02 ×3 języki odświeżony. `make check` zielone. ≤ ~60 linii + PNG.
  Skill: `godot-dev`

- [ ] T-056 `review` BoardView/TubeView: warstwy płynu przycięte do kształtu probówki (dolna warstwa nie wystaje poza zaokrąglenie) (przeniesione z Inbox) → PR #59
  KA: rysowanie warstw w `tube_view.gd` ograniczone do wnętrza probówki (np. dolna warstwa jako prostokąt + zaokrąglony spód o promieniu z sprite'a, albo `clip_children` z maską) dla obu kształtów z T-018; stałe proporcji jako nazwane `const`/klucze. Test gdUnit4: dla probówki pełnej i z 1 warstwą prostokąt/obrys dolnej warstwy mieści się w `Rect2` wnętrza probówki (z tolerancją 1 px) w obu kształtach. Kadr Level (01) obejrzany po `make screenshots`. `make check` zielone. ≤ ~100 linii.
  Skill: `godot-dev`

- [ ] T-061 `review` Home: odstęp nad przyciskiem „Graj” w karcie Poziomu dnia + regeneracja 15 screenshotów sklepowych (zależy od T-056, T-057, T-063) (przeniesione z Inbox) → PR #60
  KA: `separation` VBox karty z nazwanej stałej/stylu (≥ 12 px przy 1080×1920); test gdUnit4: odstęp między etykietą stanu a przyciskiem „Graj” ≥ stała. `make screenshots` → 15 PNG (5 kadrów × EN/PL/DE) odświeżonych i zacommitowanych, test rozmiarów z T-050 zielony; kadry 01–05 obejrzane, lista uwag w opisie PR. `make check` zielone. ≤ ~40 linii + PNG.
  Skill: `aso`

- [ ] T-049 `todo` Shop jako overlay nad Level — powrót bez utraty rundy i do właściwego trybu (campaign/daily) (przeniesione z Inbox; zastępuje przyjęcie z T-027)
  KA: `App.show_shop` ze StuckPanel/HUD w trybie `daily` i `campaign` otwiera Shop nad Level (Level nie jest zwalniany, runda zachowuje ruchy); zamknięcie Shop wraca do tej samej rundy; wejście z Home → powrót do Home. Testy gdUnit4: (a) daily → shop → zamknij → `level.mode == "daily"` i liczba ruchów bez zmian; (b) campaign jw.; (c) Home → shop → zamknij → Home. Pytanie T-027 w „Pytania do Huberta” zaktualizowane. `make check` zielone. ≤ ~120 linii.
  Skill: `godot-dev`

- [ ] T-041 `todo` Audio: `click` na przyciskach UI, `tube_full` po przelewie zamykającym probówkę, wyciszenie na czas reklamy (przeniesione z Inbox)
  KA: `click` przez jeden punkt (np. sygnał z Theme/helper w `App`, nie per-scena kopiuj-wklej); `tube_full` gdy po `pour` probówka docelowa pełna jednego koloru (test gdUnit4 na `GameRound`/`Level` z fake `AudioService`: dokładnie 1 odtworzenie na zamknięcie); `AdService` woła `Audio.set_app_muted(true)` przed pokazem i `false` po zamknięciu/błędzie (test z `FakeAdProvider`: granted, skipped, unavailable → zawsze odciszone na końcu). `HAPTIC_MS` jako `const`. `make check` zielone. ≤ ~100 linii.
  Skill: `godot-dev`

- [ ] T-065 `todo` Docs: `docs/SETUP_HUBERT.md` — lista kroków ręcznych Fazy 4 + `CLAUDE.md` (tabela komend i lekcja o workflowach)
  KA: `SETUP_HUBERT.md` ma nową sekcję „Faza 4 — do zrobienia w sesji interaktywnej” z checklistą: (1) workflowy T-002b, T-005, T-053, T-055 (link do KA w BACKLOG), (2) pluginy IAP T-047/T-048 — pobranie release zip + SHA-256, (3) publikacja polityki prywatności (`docs/privacy/`, hosting, `__PRIVACY_CONTACT__`, przegląd prawny), (4) przegląd wszystkich `ZWERYFIKUJ` w `docs/` (liczba podana z `grep -c`, dziś ~36), (5) sprawdzenie nazwy „Vialo” w EUIPO/UPRP i dostępności w Play/ASC; każdy punkt z numerem zadania i kryterium „zrobione”. `CLAUDE.md`: wiersz `make screenshots-smoke` w tabeli „Komendy” (opis z `Makefile`) i `make test-tools` (po T-034), w „Tryb ciągły” 1–2 zdania: sesja scheduled nie edytuje `.github/workflows/**` ani nie pobiera z GitHub Releases → takie zadania od razu `blocked` z powodem. Bez zmian w `.claude/*`. ≤ ~80 linii tekstu.
  Skill: `store-release`








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

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)

- [ ] T-068 `todo` ConsentFlow: brak limitu czasu po `show_consent_form`/`request_att` (gdy SDK zawiesi się po otwarciu formularza flow nie kończy się) — rozważyć osobny długi limit `consent_form_timeout_seconds` w Fazie 5 (SDK). Skill: ads-iap
- [ ] T-069 `todo` ConsentFlow: `ok=false` z `request_consent_info_update` idzie dalej ze statusem providera (`unknown`) — rozważyć osobny event `consent:ump:error` + test; `FakeConsentProvider` nie umie zwrócić `ok=false`. Skill: ads-iap
- [ ] T-070 `todo` Ads.show_privacy_options: po zamknięciu opcji prywatności (callback ze statusem) ponownie ustawić `provider.set_personalized` wg nowej zgody + odświeżyć `Settings.apply_from_state` przez `Ads.consent_finished`; `Ads` jako autoload może potrzebować `process_mode = PROCESS_MODE_ALWAYS` dla `poll()` przy pauzie drzewa. Skill: ads-iap
- [ ] T-071 `todo` iOS manifest (T-053): sprawdzić, czy preset iOS Godota 4.7 generuje własny PrivacyInfo.xcprivacy z opcji `privacy/*` (nie dublować z `game/ios/PrivacyInfo.xcprivacy`) i czy engine wymaga dodatkowych kategorii required-reason API (np. DiskSpace/statfs); zweryfikować kody powodów CA92.1/C617.1/35F9.1 i linked/tracking 6 typów. Skill: store-release
- [ ] T-072 `todo` Home/ASO: etykieta `home_streak` w PL/DE pokazuje „Streak: %d” (nieprzetłumaczone — kadr 03/04 PL/DE); przetłumaczyć („Seria: %d” / „Serie: %d”), sprawdzić inne klucze z angielskim w PL/DE; popup 04 nachodzi na kartę Poziomu dnia (ucięty napis w tle) — rozważyć ukrycie karty pod popupem. Skill: aso
- [ ] T-067 `todo` tools/test_tools.py: `Image.open` bez `with` → ResourceWarning: unclosed file w logu testów; użyć `with Image.open(...) as im`. Skill: godot-test
- [ ] T-058 `todo` Screenshoty iOS 6,9" (1320×2868) w `fastlane/metadata/ios/<locale>/` — tylko po weryfikacji wymaganego rozmiaru w dokumentacji App Store Connect (link w zadaniu). Skill: aso
- [ ] T-059 `todo` `export/screenshots_raw/` jest ignorowane, ale `fastlane/metadata/android/*/images/` nie — ustalić politykę (commitowane tylko kadry sklepowe z T-050; smoke-screenshoty z `screens.txt` do `export/`). Skill: aso
- [ ] T-055 `blocked` CI: dokończyć T-011 — zweryfikować na stronach releases i podbić: actions/download-artifact (v4→v7?, para z upload-artifact v7), setup-java, android-actions/setup-android, ruby/setup-ruby, maxim-lobanov/setup-xcode, google-github-actions/setup-gcloud, EnricoMi/publish-unit-test-result-action; `actionlint` (w sesji bez dostępu do github.com/releases i bez pobierania binarek — zrobić w sesji z dostępem). Skill: godot-build — powód: edycja `.github/workflows/` niedostępna w sesji scheduled (jak T-002b)
- [ ] T-046 `todo` playtest_bot.gd: fallback `win_reward_coins` = 10 w `GameConfig.get_value(..., 10)` nieaktualny po G-013 — usunąć fallback (klucz zawsze istnieje). Skill: godot-test
- [ ] T-045 `todo` PlaytestBot (random): po przegranej bez podniesienia poziomu `maybe_show_interstitial(state.level - 1)` wołane wielokrotnie z tym samym numerem — liczyć przerwę raz na rundę (albo tylko po wygranej), żeby raport nie zawyżał interstitiali. Skill: godot-test
- [ ] T-044 `todo` Skill game-economy §6: opis wyjścia nowego `make sim` (metryki motywów w dniach aktywnych, ads/DAU per placement, WARN zamiast błędu dla impresji, „starves" = mediana motywów do d7 < 1) — zadanie dotyczy wprost `.claude/`. Skill: game-economy

- [ ] T-006 `todo` Postawić pierwszy tag v0.1.0 (git describe w prompcie biweekly-release wymaga istniejącego taga). Skill: store-release
- [ ] T-007 `todo` Sprawdzić czy deny Edit(fastlane/Fastfile) itd. w .claude/settings.json działa jak zamierzono (metadata edytowalne, lanes nie); patrz ZWERYFIKUJ w docs/AUTOMATION.md. Skill: godot-test
- [ ] T-028 `todo` SaveSystem.load: test pliku uszkodzonego wypisuje `ERROR: Parse JSON failed` do logu (JSON.parse_string); użyć `JSON.new().parse()` i sprawdzać kod błędu, żeby log CI był czysty. Skill: godot-dev
- [ ] T-029 `todo` SortSolver: optymalizacja (~0,4 ms/stan: clone planszy, canonical_key jako String, path.duplicate per węzeł → rodzic+indeks, klucz PackedByteArray/int); cel: dokładny A* dla ≥ 8 kolorów w ≤ 500 ms, wtedy min_moves_exact=true dla większości poziomów. Skill: godot-dev
- [ ] G-012 `todo` GDD/ADR-009: dopisać, że generator używa etapów (quick pass 250 stanów → dokładny A* ≤ 6 kolorów/1000 stanów → ważony A*), więc `min_moves_exact=false` jest normą od ~6 kolorów (premia „idealnie" liczona od wyniku ważonego + par_slack_moves); przenieść stałe EXACT_MAX_COLORS/EXACT_STATE_BUDGET/QUICK_STATE_BUDGET z content_generator.gd do GameConfig. Skill: game-economy
- [ ] T-030 `todo` GameRound: literały wag solvera (1.0 / fallback 3.0) jako const/klucz; komentarz o limicie ACTION_BASE=16 probówek; `add_extra_tube` przez metodę SortBoard zamiast mutacji `tubes`; `undo_refill_amount` bez konsumenta do G-010. Skill: godot-dev
- [ ] T-031 `todo` PlaytestBot: test ścieżki `gave_up` (`max_restarts_per_round=0` → przegrana bez softlocka); udokumentować `--random`/`--max-restarts` w `.claude/skills/godot-test/SKILL.md` (zadanie dotyczy wprost `.claude/`). Skill: godot-test
- [ ] T-032 `todo` GameState.from_dict: zły typ pojedynczego klucza `settings` odrzuca cały zapis (utrata postępu) — rozważyć reset klucza do domyślnej; `_as_int` bez górnego limitu (NaN/1e30). Skill: godot-dev
- [ ] T-033 `todo` Economy: `rewarded_bonus` → `maxi(0, …)` przy multiplier < 1; `buy_booster` bez `SINK_THEME` (zakup motywu w G-009); testy `can_afford` i dwu zdarzeń Analytics w `apply_win`. Skill: game-economy
- [ ] T-035 `todo` BoardView: pełna animacja przelewu wg GDD (przechylenie, ubywanie/przybywanie warstw, pulsowanie pełnej probówki) + ochrona tweenów przed `queue_free` w `_rebuild`/`resized`; nazwane stałe proporcji shake/pour; test z `animate=true` przez `scene_runner` i symulowany czas. Skill: godot-dev
- [ ] T-036 `todo` test_content_generator: `const FNV_OFFSET = 0xCBF29CE484222325` daje `ERROR: Cannot represent ... as a 64-bit signed integer` w logu `make test` (3×) — użyć literału ze znakiem (-3750763034362895579) albo FNV-1a 32-bit; sprawdzić, czy golden hash się nie zmienia. Skill: godot-test
- [ ] T-037 `todo` Level: test wygranej bez „idealnie" (ukryty `perfect_label`, tylko `win_reward_coins`); usunąć nieużywane `@export var level` po T-022. Skill: godot-dev
- [ ] T-038 `todo` Level: testy `shop_requested` dla hint/undo_refill bez środków; `buy_undo_refill` z jawnym `can_afford` (spójnie z resztą); `GameConfig.get_value` bez duplikowanych fallbacków w board_view.gd. Skill: godot-dev
- [ ] T-039 `todo` BoardView: sygnał `tube_deselected` zamiast pollingu w `Level._process` (tutorial); test „zły ruch w tutorialu restartuje krok”; `TEXT_HEIGHT` const w tutorial_overlay.gd. Skill: godot-dev
- [ ] T-042 `todo` App/Level: `show_daily_level` bez obejścia `round = GameRound.new()` (flaga `autoload_level` w Level); `test_app.gd` z wstrzykniętym zegarem (teraz realny czas otwiera popup). Skill: godot-dev
- [ ] T-043 `todo` Themes: usunąć martwą `BoardView.THEMES_PATH`; nazwy motywów przez klucze `theme_name_*` w CSV; App odświeża Level po `theme_selected` (dziś od następnej rundy); GDD Meta: dopisać zasadę kosztu wg pozycji w katalogu. Skill: godot-dev
- [ ] T-066 `todo` gen_assets: dopieścić kształt probówki `flask` (wydzielone z T-034). Skill: asset-gen

## Pytania do Huberta
- T-027: wejście do Sklepu ze StuckPanel podmienia scenę — powrót startuje nową rundę tego samego poziomu (postęp ruchów przepada; gracz był utknięty) — przyjęto: tak w MVP, do zmiany (alternatywa: Shop jako overlay, T-049).
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
