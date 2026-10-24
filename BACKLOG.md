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

<!-- Refill 2026-10-24 (continuous-dev #12, refill #8): Faza 5 prep VI — odporny remote config (crash-free ≥ 99,5 %: dziś `apply_remote` przyjmuje każdą wartość zgodnego typu — `solver_max_states` = 10⁹ zamraża start poziomu (ANR), `colors_max = 14` daje 17 probówek > `ACTION_BASE` 16, ujemny koszt boostera dodaje monety; lokalne `maxi(1, …)` chronią tylko 3 klucze; remote config/A-B to narzędzie Fazy 6), płynny start poziomu na słabszych telefonach (solver: NAJPIERW profil hot-spotów — lekcja T-124; potem prefetch N+1 w tle), cel miesiąca Poziomów dnia (D7/D30, reguła 3 KPI.md — awans z „later”, bez nowego contentu). Kolejność = wpływ na KPI i zależności: T-135 (`config.gd`) przed T-137 i T-142; T-134 przed T-136 (pomiar po przyspieszeniu); T-137 po T-135 (`config.gd`), T-138 po T-136 i T-137 (`level.gd`, `daily_challenge.gd`). Pary rozłączne do worktree: T-135 ‖ T-134, T-136 ‖ T-137. -->

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

<!-- Refill 2026-10-24 (continuous-dev #12, refill #8, P2): Faza 5 prep VI — wiarygodna bramka i dokumentacja testów (zegar w suitach `Level` — fałszywe czerwone o północy UTC blokują auto-merge; ścieżka `gave_up` bota bez dostępu do pól prywatnych), panel wygranej daily w najwyższym wariancie, kohorty remote configu rozróżnialne w GA przed Fazą 6 (H1–H3, ARPDAU), skille zgodne z kodem (Inbox T-131/T-089/T-092/T-031/T-044). Kolejność = zależności: T-141 po T-138 (`level_complete.gd`), T-142 po T-135 (`config.gd`), T-143 po T-139 i T-140 (opisuje ich API). Pary rozłączne do worktree: T-139 ‖ T-140, T-141 ‖ T-142. -->

- [ ] T-142 `review` Remote config: etykieta wariantu `remote_config_variant` w `GameConfig` + event `config:variant:<v>` na starcie sesji — kohorty H1–H3 z `docs/MONETIZATION.md` rozróżnialne w GA bez SDK (zależy od T-135 — `config.gd` `RANGES`) → PR #122
  KA: `DEFAULTS["remote_config_variant"] = "default"` (String; reguła w `RANGES`/walidatorze z T-135: `^[a-z0-9_]{1,24}$`, inna wartość odrzucona z `push_warning`); `App.track_session_start` wysyła dodatkowo `track_design("config:variant:<v>")` w tym samym momencie co `session:start` (start i powrót fokusu). GDD → Analityka: event `config_variant`. Testy gdUnit4 ≥ 3: domyślnie 1× `config:variant:default` w `FakeAnalyticsProvider` po `track_session_start`; `apply_remote({"remote_config_variant": "h1_b"})` → `config:variant:h1_b`; `"H1 B!"` i 25 znaków → odrzucone, nadal `default`. `test_config_keys.gd` (T-122) zielony. `make check` zielone. ≤ ~50 linii.
  Skill: `godot-dev`

- [ ] T-143 `blocked` Skill godot-test + game-economy (dotyczy `.claude/`) — powód: deny-lista `Edit(.claude/**)` w `.claude/settings.json` dla sesji scheduled (docs/AUTOMATION.md: zmiany `.claude/**` tylko z sesji interaktywnej Huberta; wpis w `docs/SETUP_HUBERT.md` §15 pkt 5): zegar w testach (`TestClock`), `.uid` po nowym `class_name`, testy parametryzowane, format `playtest.json` i flagi bota, wyjście `make sim` (obejmuje Inbox T-131, T-089, T-044 i części dokumentacyjne T-092, T-031; zależy od T-139, T-140 — opisywane API)
  KA: `.claude/skills/godot-test/SKILL.md`: (1) sekcja „Zegar w testach” — `TestClock.fixed()`/`ticking(t)`, `FIXED_UNIX` = `SCREENSHOT_NOW_UNIX` = 1792843200, reguła „każda instancja `App`/`Home`/`Level` w teście dostaje zegar”, dowód przebiegiem z `FIXED_UNIX + 86 399`; (2) „Nowy skrypt z `class_name`” — `make test` nie generuje `.uid`, potrzebny `godot --headless --import` ×2 (przy worktree także w katalogu głównym repo — hook `pre_push`); (3) testy parametryzowane — `test_parameters` + gdlint `unused-argument`, gdUnit opróżnia tablicę w trakcie → `assert_that(test_parameters).is_not_null()`; (4) §6: pełna lista kluczy `playtest.json` = `KEYS` w `test_playtest_bot.gd` (w tym `interstitial_calls`, `losses` = `gave_up`), `playtest_random.json`, flagi `--random`/`--max-restarts`, `AdService.reset_interstitial_cooldown()`. `.claude/skills/game-economy/SKILL.md` §6: opis wyjścia `make sim` (metryki motywów w dniach aktywnych, ads/DAU per placement, WARN zamiast błędu dla impresji, „starves” = mediana motywów do d7 < 1, premia celu miesiąca z T-137) — każda nazwa pola/flagi sprawdzona grepem w `tools/balance_sim.py`/`game/` (lista w PR). Bez zmian w `game/`, `tools/`. ≤ ~120 linii dokumentacji.
  Skill: `godot-test`

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)
- [ ] T-144 `todo` LevelPrefetch (po T-136): test, że `cancel_all()`/`Level._exit_tree` czeka na zadanie w toku (`_task_id == -1` po `request` + `cancel_all`), fallback na generację synchroniczną gdy wynik z wątku pusty, prefetch także w `_apply_skip`/`on_next_pressed`; test pomiarowy `test_measure_take_time` (~3 s `OS.delay_msec`) przenieść do `game/test/perf/` (odkryte w T-136, sugestie QA). Skill: godot-dev
- [ ] T-145 `todo` SortBoard: po T-134 największe udziały to `clone_poured` 29 % (duplikaty tablic), `fast_key` 17 %, `legal_moves` 18 % — reprezentacja probówki jako pakowany int (zmiana architektury SortBoard, osobny ADR) (odkryte w T-134). Skill: godot-dev
- [ ] T-146 `todo` GameConfig: helper testowy `set_for_test(key, value)` zamiast wpisów do `_values` w `test_economy.gd`/`test_daily_rewards.gd` + reset configu w `before_test` tych suit; w GDD tabela ekonomii — zdjąć etykietę PROPOZYCJA przy `daily_month_goal` (odkryte w T-135/T-137). Skill: godot-test
- [ ] T-147 `todo` Testy T-138: `WIN_COINS_WITH_BONUS = 350` i `contains("5/20")` wpisane na stałe w `test_level_complete_month.gd`/`test_home_daily_month.gd` — składać z `daily_challenge_coins`/`daily_month_goal_coins`/`daily_month_goal` (po T-146 — `set_for_test`); brak testu, że `lc_month_goal` zostaje po `_on_double_coins_granted`; `int(GameConfig.get_value("daily_month_goal"))` powtórzone w `home.gd` i `level.gd` → statyczny helper `DailyChallenge.month_goal()` (odkryte w T-138, QA). Skill: godot-test
- [ ] T-148 `todo` Skill godot-dev §5: `make test` NIE generuje `.uid` dla nowych `.gd` — potrzebny `godot --headless --path game --import` (wskazane jako równoważne; odkryte w T-138; włączyć do T-143). Skill: godot-test
- [ ] T-149 `todo` Bot losowy (T-140, seed 42, 200 rund, `max_restarts_per_round` = 50): 135/200 porażek, `stuck_count` 700 z 1152 restartów, straty rosną z poziomem (0/12 na starcie, 34/60 przy limicie 0) — sygnał o krzywej trudności dla losowego gracza, nie bug; ocena `game-designer` przy refillu (czy `make sim`/KPI D1 uwzględnia porażki gracza bez strategii). Skill: game-economy
- [ ] T-129 `todo` Po T-134 (SortSolver cz. 2; T-124 cz. 1 dało szum ±6 %): jeśli mediana czasu generacji poziomów 1..200 spadnie ≥ 30 % względem pomiaru po T-124 (60,5 ms/poziom) — rozważyć podniesienie `gen_exact_max_colors` 6 → 8 (dokładne `min_moves` i uczciwa premia „idealnie” do ~poziomu 38); zmiana zmienia poziomy graczy (golden hashe) — przed soft launchem dopuszczalne, decyzja w refillu po pomiarze z T-134 (najpierw profil czasu dokładnego A* dla 7–8 kolorów, nie obietnica procentu). Skill: game-economy

- [ ] T-068 `todo` ConsentFlow: brak limitu czasu po `show_consent_form`/`request_att` (gdy SDK zawiesi się po otwarciu formularza flow nie kończy się) — rozważyć osobny długi limit `consent_form_timeout_seconds` w Fazie 5 (SDK). Skill: ads-iap
- [ ] T-071 `todo` iOS manifest (T-053): sprawdzić, czy preset iOS Godota 4.7 generuje własny PrivacyInfo.xcprivacy z opcji `privacy/*` (nie dublować z `game/ios/PrivacyInfo.xcprivacy`) i czy engine wymaga dodatkowych kategorii required-reason API (np. DiskSpace/statfs); zweryfikować kody powodów CA92.1/C617.1/35F9.1 i linked/tracking 6 typów. Skill: store-release
- [ ] T-058 `todo` Screenshoty iOS 6,9" (1320×2868) w `fastlane/metadata/ios/<locale>/` — tylko po weryfikacji wymaganego rozmiaru w dokumentacji App Store Connect (link w zadaniu). Skill: aso
- [ ] T-059 `todo` `export/screenshots_raw/` jest ignorowane, ale `fastlane/metadata/android/*/images/` nie — ustalić politykę (commitowane tylko kadry sklepowe z T-050; smoke-screenshoty z `screens.txt` do `export/`). Skill: aso
- [ ] T-055 `blocked` CI: dokończyć T-011 — zweryfikować na stronach releases i podbić: actions/download-artifact (v4→v7?, para z upload-artifact v7), setup-java, android-actions/setup-android, ruby/setup-ruby, maxim-lobanov/setup-xcode, google-github-actions/setup-gcloud, EnricoMi/publish-unit-test-result-action; `actionlint` (w sesji bez dostępu do github.com/releases i bez pobierania binarek — zrobić w sesji z dostępem). Skill: godot-build — powód: edycja `.github/workflows/` niedostępna w sesji scheduled (jak T-002b)

- [ ] T-006 `todo` Postawić pierwszy tag v0.1.0 (git describe w prompcie biweekly-release wymaga istniejącego taga). Skill: store-release
- [ ] T-007 `todo` Sprawdzić czy deny Edit(fastlane/Fastfile) itd. w .claude/settings.json działa jak zamierzono (metadata edytowalne, lanes nie); patrz ZWERYFIKUJ w docs/AUTOMATION.md. Skill: godot-test
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
- Refill #8 (T-137/T-138): cel miesiąca Poziomów dnia awansowany z „later” w wersji minimalnej — przyjęto: 20 ukończonych Poziomów dnia w miesiącu kalendarzowym UTC = jednorazowo 300 monet (≈ 1 dzień dochodu zaangażowanego gracza, ~5 % miesięcznego), licznik „W tym miesiącu: N/20” na karcie Poziomu dnia od 1. ukończenia; bez motywu miesiąca i kalendarza odznak (wymagają nowego contentu) — do zmiany (alternatywa: próg 15, nagroda motywem).
- Refill #8 (T-135): wartość z remote configu spoza zakresu — przyjęto: odrzucana (zostaje poprzednia wartość, ostrzeżenie w logu), a paczka łamiąca niezmienniki (np. > 16 probówek) cofana w całości; bez przycinania do granic, bo przycięta wartość to inny eksperyment niż zamierzony; do zmiany.

## Done (ostatnie 30)
- [x] T-135 `done` Remote config: zakresy wartości w `GameConfig` — `apply_remote` odrzuca wartości spoza zakresu i paczki łamiące niezmienniki → PR #113 (zmergowany 2026-10-24)
- [x] T-134 `done` SortSolver cz. 2: NAJPIERW profil hot-spotów → PR #114 (zmergowany 2026-10-24)
- [x] T-136 `done` Prefetch następnego poziomu w tle: `LevelPrefetch` generuje poziom N+1 na `WorkerThreadPool` podczas ekranu wygranej → PR #116 (zmergowany 2026-10-24)
- [x] T-137 `done` Cel miesiąca Poziomów dnia cz. 1 → PR #115 (zmergowany 2026-10-24)
- [x] T-138 `done` Cel miesiąca Poziomów dnia cz. 2 → PR #118 (zmergowany 2026-10-24)
- [x] T-139 `done` Testy: stały zegar w suitach tworzących `Level` → PR #119 (zmergowany 2026-10-24)
- [x] T-140 `done` PlaytestBot: test ścieżki `gave_up` → PR #120 (zmergowany 2026-10-24)
- [x] T-141 `done` LevelComplete daily: test „panel nie przecina probówek” z widocznym `btn_copy_result` i komunikatem premii miesiąca + fixture symbols_neon → PR #121 (zmergowany 2026-10-24)
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
- [x] T-121 `done` LevelComplete: wysokość panelu z treści + jedna wysokość HUD (230) + `_reset_board_fit()` w `restart()` → PR #104 (zmergowany 2026-10-24)
- [x] T-122 `done` GameConfig: zero fallbacków `get_value` w `game/src` + test statyczny kluczy (`test_config_keys.gd`) → PR #105 (zmergowany 2026-10-24)
- [x] T-123 `done` FTUE: znacznik „Nowość!” na karcie Poziomu dnia + event `nav:daily` → PR #106 (zmergowany 2026-10-24)
- [x] T-124 `done` SortSolver cz. 1: ścieżka przez rodzica + test regresji wyników (cel ≥ 30 % nieosiągnięty → T-134) → PR #107 (zmergowany 2026-10-24)
- [x] T-125 `done` Testy: `TestClock` — stały zegar we wszystkich suitach `App`/`Home` → PR #108 (zmergowany 2026-10-24)
- [x] T-126 `done` Dostępność: kontrast symboli kolorów ≥ 3:1 na 48 płynach (WCAG) + fixture `symbols` → PR #109 (zmergowany 2026-10-24)
- [x] T-127 `done` GameRound porządki: `EXACT_WEIGHT`, `SortBoard.add_empty_tube()`, test limitu `ACTION_BASE` → PR #110 (zmergowany 2026-10-24)
- [x] T-128 `done` Poziom dnia: „Kopiuj wynik” (`DailyShare`, schowek, `daily:share`) → PR #111 (zmergowany 2026-10-24)
