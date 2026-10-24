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

<!-- Refill 2026-10-24 (continuous-dev #8, refill #5): Faza 5 prep III — wiarygodna analityka przed soft launchem (lejek poziomów i FTUE), brakujące elementy MVP z GDD (LevelComplete, konfetti), odporność zapisu. Bez workflowów, binarek z Releases, kont i SDK. Kolejność = zależności (T-093 → T-094 → T-095 dotykają `level.gd`). -->

- [ ] T-093 `todo` Analityka: pauza z wznawialną rundą jako `level:pause` zamiast `level:fail:quit`; porzucony snapshot jako `level:fail:abandon` (przeniesione z Inbox T-091)
  KA: `Level.quit_level()` dla nieukończonej rundy rejestruje tylko `track_design("level:pause", moves)` — bez `track_progression("Fail", …)`; `App` w jednym helperze (np. `_discard_snapshot()`) przy każdym odrzuceniu lub nadpisaniu niepustego `round_in_progress` (daily z innego dnia UTC, kampania z innym poziomem, `Level.resume` → false, start rundy innego trybu nadpisujący snapshot) rejestruje dokładnie raz `track_progression("Fail", <mode snapshotu>, <level_id snapshotu>)` + `track_design("level:fail:abandon")` i czyści pole. Testy gdUnit4 z `FakeAnalyticsProvider` ≥ 4: (a) pauza → 0 `Fail`, 1 `level:pause`; (b) pauza → „Graj” (wznowienie) → wygrana → w sekwencji progression dokładnie 1 `Start`, 0 `Fail`, 1 `Complete`; (c) daily z wczoraj + karta Poziomu dnia → 1 `level:fail:abandon`, `round_in_progress` pusty po zapisie; (d) restart nadal loguje `level:fail:restart`. grep `level:fail:quit` w `game/src` = 0; wpisy `level_fail`/`level_pause` zgodne z GDD → Analityka (refill #5). `make check` zielone. ≤ ~80 linii.
  Skill: `godot-dev` + `analytics-review`

- [ ] T-094 `todo` Analityka: parametry `level_complete` z GDD — czas rundy, cofnięcia, boostery, „idealnie” (zależy od T-093, ten sam `level.gd`)
  KA: `GameRound` ma pole `elapsed_s: float` (serializowane w `to_dict/from_dict`; brak pola w starym snapshocie → 0, bez zmiany schema GameState); `Level` dolicza czas z wstrzykniętego `clock` od `_bind_round` do snapshotu/wygranej (wznowienie nie zeruje); `GameRound.result()` zwraca `undos_used`, `boosters_used`, `elapsed_s`. Przy wygranej (kampania i daily) `Level` rejestruje oprócz `Complete`: `level:complete:perfect` albo `level:complete:normal` (value = sekundy rundy), `level:complete:undos` (value = `undos_used`), `level:complete:boosters` (value = `boosters_used`). Testy gdUnit4 ≥ 4: ścieżka solvera bez boosterów → `perfect`, undos 0, boosters 0; 2× undo + 1 hint → 2 / 1; zegar +37 s → value 37 (±1); snapshot po 20 s → `resume` → wygrana po kolejnych 10 s → 30 (±1). Nazwy zgodne z GDD → Analityka (refill #5). `make check` zielone. ≤ ~120 linii.
  Skill: `godot-dev` + `analytics-review`

- [ ] T-095 `todo` Analityka: lejek FTUE — `tutorial:step:<n>` przy pierwszym wejściu w krok `TutorialFlow` i `tutorial:reset` przy cofnięciu (zależy od T-094, ten sam `level.gd`)
  KA: `Level` rejestruje `tutorial:step:1` (start tutorialu), `tutorial:step:2` (wejście w `PICK_TARGET`), `tutorial:step:3` (wejście w `FINISH`) — każdy tylko przy pierwszym osiągnięciu w rundzie (pole `_tutorial_max_step`; powtórne `PICK_SOURCE` przy kolejnych przelewach poziomu 1 nie generuje eventów); `tutorial:reset` (value = krok, z którego cofnięto) w `_on_tutorial_deselected`; istniejące `tutorial:done` bez zmian. Testy gdUnit4 z `FakeAnalyticsProvider` ≥ 3: poprawne przejście poziomu 1 → `step:1`, `step:2`, `step:3`, `done` dokładnie po 1× w tej kolejności; odznaczenie w kroku 2 → 1× `tutorial:reset`, bez ponownego `step:1`; poziom 1 przy `tutorial_done == true` → 0 eventów `tutorial:*`. Zgodne z GDD → Analityka `tutorial_step` (refill #5). `make check` zielone. ≤ ~50 linii.
  Skill: `godot-dev` + `analytics-review`

- [ ] T-096 `todo` LevelComplete: komunikat „Następny poziom: +1 kolor” albo postęp do następnego motywu (GDD → Ekrany `LevelComplete`, Sesja hook 4)
  KA: czysta funkcja statyczna (np. `LevelComplete.progress_message(level_no: int, mode: String, state: GameState) -> Dictionary {key, args}`, bez `Node`): kampania i `ContentGenerator.new().level_params(level_no + 1)["colors"] > level_params(level_no)["colors"]` → klucz `lc_new_color` (EN „Next level: +1 color”, PL „Następny poziom: +1 kolor”, DE „Nächstes Level: +1 Farbe”); w przeciwnym razie `lc_theme_progress` z `[state.coins, ThemeCatalog.next_theme_cost(state)]` (format jak `home_theme_progress`); wszystkie motywy kupione albo tryb daily → `{}` i etykieta ukryta. `LevelComplete.show_result` pokazuje etykietę pod monetami (po ×2 odświeżona). Testy gdUnit4 ≥ 5: poziom 7 → `lc_new_color` (asercja wyliczona z `level_params`, nie z literału); poziom 8 → `lc_theme_progress`; wszystkie motywy kupione → `{}`; daily → `{}`; po `watch_double_coins` monety w etykiecie zaktualizowane. Nowe klucze objęte testem kompletności EN/PL/DE (T-023) i testem „PL/DE ≠ EN” (T-076). Kadr 02 (`make screenshots`, EN/PL/DE) odświeżony i obejrzany (tekst nie nachodzi na przyciski). `make check` zielone. ≤ ~100 linii + PNG.
  Skill: `godot-dev`

- [ ] T-097 `todo` Konfetti na wygranej: `CPUParticles2D` z prostokątów w kolorach aktywnego motywu (GDD → Styl graficzny; zależy od T-096 — wspólny kadr 02)
  KA: węzeł `CPUParticles2D` (`one_shot = true`) w scenie Level nad planszą, pod panelem `LevelComplete`, startowany w `Level._on_round_won` (kampania i daily); liczba cząstek z nazwanej `const CONFETTI_AMOUNT`, czas życia z klucza `confetti_seconds` w `GameConfig` (PROPOZYCJA 1.2, GDD → tabela kluczy), kolory = pierwsze 6 kolorów palety aktywnego motywu (Gradient w `color_initial_ramp`); restart/następny poziom/`resume` zatrzymują emisję; w trybie `--screenshot` konfetti nie startuje (deterministyczne kadry). Testy gdUnit4 ≥ 3: wygrana → `emitting == true` i `lifetime == confetti_seconds`; `load_level` po wygranej → `emitting == false`; tryb screenshot → `emitting == false`. `make screenshots` → kadr 02 bez cząstek (identyczny jak po T-096). `make check` zielone. ≤ ~70 linii.
  Skill: `godot-dev`

- [ ] T-098 `todo` Odporność zapisu: zły typ `schema_version` w `GameState.migrate` i nie-liczbowe `payload.min_moves` w `GameRound.from_dict` (przeniesione z Inbox T-086 i części T-089)
  KA: w `GameState.migrate` (`int(out.get("schema_version", 1))`) i `from_dict` `schema_version` jako Dictionary / Array / String / bool / brak → traktowany jak v1 i migrowany do bieżącej schemy bez błędu skryptu, pozostałe poprawne pola (`level`, `coins`) zachowane; liczba z JSON (`3.0` float) nadal = v3 bez migracji (regresja); `GameRound.from_dict` z `payload.min_moves` jako Array / Dictionary / String → `null` (runda od nowa) bez wywołania `int()` na złym typie. Testy gdUnit4 ≥ 8 przypadków (5 złych wariantów `schema_version` + float `3.0` + 2 typy `min_moves`; wzorzec parametryzowany z Inbox T-089 albo osobne funkcje). `make test 2>&1 | grep -c "SCRIPT ERROR"` = 0. `make check` zielone. ≤ ~50 linii.
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

- [ ] T-085 `review` ConsentFlow: błąd `request_consent_info_update` (`ok=false`) → event `consent:ump:error` i ścieżka niespersonalizowana; `FakeConsentProvider` umie zwrócić `ok=false` (przeniesione z Inbox T-069) → PR #76
  KA: `FakeConsentProvider` ma skryptowane `info_update_ok: bool`; przy `false` flow kończy `finished` z `can_request_ads=true`, `personalized=false`, bez pokazania formularza, i rejestruje dokładnie jeden event błędu w `FakeAnalyticsProvider` (nazwa zgodna z konwencją z GDD → Analityka; jeśli brak — dopisać wiersz w GDD). Test gdUnit4 ≥ 2 przypadki (EEA + błąd, poza EEA + błąd). `make check` zielone. ≤ ~60 linii.
  Skill: `ads-iap`

<!-- Refill 2026-10-24 (continuous-dev #8, refill #5, P2): reklamy/consent bez SDK — odporność na zawieszony provider i zmianę zgody; refaktor Level po paczce analityki P1; spójność PL. Kolejność = zależności. -->

- [ ] T-099 `todo` Ads/Audio: watchdog odciszenia — gdy provider nie zamknie interstitiala ani nie wywoła callbacku rewarded w `ad_unmute_timeout_seconds`, dźwięk wraca, a przerwa reklamowa się kończy (przeniesione z Inbox T-073)
  KA: klucz `ad_unmute_timeout_seconds` w `GameConfig` (PROPOZYCJA 90, GDD → tabela kluczy); `AdService` zapamiętuje moment wyciszenia (wstrzykiwany `clock`) i w `_process` po przekroczeniu limitu woła `Audio.set_app_muted(false)` i rejestruje dokładnie 1× `ads:watchdog:unmute`; późny callback/`interstitial_closed` po watchdogu nie wycisza ponownie, a nagroda rewarded jest przyznana maks. 1×. `FakeAdProvider` dostaje flagę `hold_show: bool` (pokaz bez callbacku i bez `*_closed`) i metodę `release(granted: bool)`. Testy gdUnit4 ≥ 3: `hold_show` + zegar +91 s → `Audio.is_app_muted() == false` i 1 event; zamknięcie przed limitem → 0 eventów watchdoga; `release(true)` po watchdogu → nagroda 1×, `muted_by_ads == false`. `make check` zielone. ≤ ~80 linii.
  Skill: `ads-iap`

- [ ] T-100 `todo` Consent: po zamknięciu „Opcji prywatności” ponowne `AdProvider.set_personalized` wg nowego statusu UMP, `consent_finished` dla Settings, `Ads` z `PROCESS_MODE_ALWAYS` (przeniesione z Inbox T-070)
  KA: `Ads.show_privacy_options()` przekazuje callback do `ConsentProvider.show_privacy_options`; po zamknięciu odczytuje `get_ump_status()`/`can_request_ads()`, woła `provider.set_personalized(...)` (zgoda → true, odmowa → false), aktualizuje `consent_result`, emituje `consent_finished` i rejestruje 1× `consent:ump:<status>` przez `report_consent`. `FakeConsentProvider` ma skryptowany status zwracany po `show_privacy_options`. Autoload `Ads` ma `process_mode = PROCESS_MODE_ALWAYS` (ustawione w `_ready`; test asercją). Testy gdUnit4 ≥ 4: zgoda → odmowa (`FakeAdProvider.personalized == false`, `set_personalized_calls` +1); odmowa → zgoda (`true`); 1 event `consent:ump:*` na zamknięcie; Settings po `consent_finished` pokazuje przycisk wg `is_privacy_options_required`. `make check` zielone. ≤ ~80 linii.
  Skill: `ads-iap`

- [ ] T-101 `todo` Refaktor: oferty rewarded i boostery z `Level` do klasy `LevelOffers` (`RefCounted`, bez `Node`), usunięcie `# gdlint: disable=max-public-methods` (przeniesione z Inbox T-090; zależy od T-093, T-094, T-095, T-096, T-097 — te same pliki)
  KA: `watch_*`, `buy_*`, `can_double_coins`, `double_coins_bonus` przeniesione do `game/src/levels/level_offers.gd` (`class_name LevelOffers`, zależności przez konstruktor/`bind`: `GameState`, `GameRound`, `RewardedPlacements`); `Level` wystawia `offers: LevelOffers`, HUD/StuckPanel/LevelComplete łączą się z `level.offers`; grep `max-public-methods` w `level.gd` = 0 i `make lint` zielone; liczba testów gdUnit4 nie maleje, asercje istniejących testów bez zmian (dozwolona tylko zmiana ścieżki wywołania `level.x()` → `level.offers.x()`); `make playtest` 200/200 bez softlocka. Zachowanie bez zmian (refaktor). ≤ ~200 linii zmienionych (głównie przeniesienie).
  Skill: `godot-dev`

- [ ] T-102 `todo` Lokalizacja PL: anglicyzm „streak” → „seria” we wszystkich tekstach PL (`btn_save_streak` „Uratuj serię”) + test (przeniesione z Inbox T-088)
  KA: w kolumnie PL `strings.csv` żadna wartość nie zawiera „streak” (case-insensitive; klucze nie liczone) — test gdUnit4 w suicie lokalizacji; `btn_save_streak` PL „Uratuj serię” mieści się w `MAX_BTN_LEN`; inne wystąpienia odmienione poprawnie („serii”, „serię”). Kadr 04 PL (`make screenshots`) odświeżony, jeśli zawiera zmieniony tekst. `make check` zielone. ≤ ~20 linii + PNG.
  Skill: `aso`

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)
- [ ] T-092 `todo` Skill godot-test §6: format `playtest.json` o pole `interstitial_calls` (T-084) i `playtest_random.json`; `AdService`: publiczny reset `_last_interstitial_s` (test bota ustawia pole prywatne `-INF`, bo realny zegar z innych suit blokuje pokaz przy symulowanym zegarze) (odkryte w T-084). Skill: godot-test
- [ ] T-089 `todo` Skill godot-test (dotyczy `.claude/`): wzorzec testów parametryzowanych (gdlint `unused-argument` dla `test_parameters`, gdUnit opróżnia tablicę w trakcie — działa `assert_that(test_parameters).is_not_null()`) (odkryte w T-081; część kodowa `min_moves` → T-098). Skill: godot-test
- [ ] T-087 `todo` `make test`: po zakończeniu runnera `WARNING: 4 ObjectDB instances were leaked at exit` i `ERROR: 2 resources still in use at exit` (także przy zielonym przebiegu) — znaleźć źródło (`--verbose`), posprzątać w `after()`/`auto_free` (odkryte w T-075). Skill: godot-test

- [ ] T-068 `todo` ConsentFlow: brak limitu czasu po `show_consent_form`/`request_att` (gdy SDK zawiesi się po otwarciu formularza flow nie kończy się) — rozważyć osobny długi limit `consent_form_timeout_seconds` w Fazie 5 (SDK). Skill: ads-iap
- [ ] T-071 `todo` iOS manifest (T-053): sprawdzić, czy preset iOS Godota 4.7 generuje własny PrivacyInfo.xcprivacy z opcji `privacy/*` (nie dublować z `game/ios/PrivacyInfo.xcprivacy`) i czy engine wymaga dodatkowych kategorii required-reason API (np. DiskSpace/statfs); zweryfikować kody powodów CA92.1/C617.1/35F9.1 i linked/tracking 6 typów. Skill: store-release
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
- Refill #5 (T-093): definicja „porażki” w GA po wprowadzeniu wznawiania rundy — przyjęto: pauza/wyjście do Home z zapisaną rundą to `level:pause` (nie fail); fail = restart, skip albo porzucenie zapisanej rundy (`level:fail:abandon`: daily z poprzedniego dnia UTC, nadpisanie innym trybem, niespójny snapshot); fail-rate w GA = (restart + skip + abandon) / start; do zmiany.
- Refill #5 (T-096): ekran wygranej pokazuje jeden komunikat — „+1 kolor” ma pierwszeństwo przed paskiem postępu motywu (raz na 6 poziomów), w Poziomie dnia brak komunikatu; przyjęto: tak, do zmiany.

## Done (ostatnie 30)
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
