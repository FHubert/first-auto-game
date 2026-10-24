# Backlog

Statusy: `todo` · `in_progress` · `review` (PR otwarty) · `blocked` · `done`
Każde zadanie: ID, status, tytuł, **kryterium akceptacji (KA)**, skill.
Pętla bierze pierwsze `todo` z najwyższej sekcji. Zadania P0 muszą być `done` zanim pętla wejdzie w P1.

## P0 — fundamenty (Faza 1–2)





## P1 — core loop i retencja (z GDD v1.0, R-003)

<!-- Refill 2026-10-23 (continuous-dev #4): Faza 4 — pipeline wydań, tylko zadania wykonalne bez sekretów. Kolejność = zależności. -->

- [ ] T-004 `review` `Gemfile.lock` wygenerowany i zacommitowany (zależy od T-011) → PR #45
  KA: `bundle lock --add-platform x86_64-linux arm64-darwin` → `Gemfile.lock` w repo z obiema platformami; na Linuksie `bundle install` + `bundle exec fastlane lanes` kończą się exit 0 i listują lane'y z `fastlane/Fastfile` (Fastfile bez zmian); `ruby/setup-ruby` z `bundler-cache: true` w workflowach używa locka (log runu lub `actionlint`). ≤ ~20 linii poza lock-file.
  Skill: `store-release`

- [ ] T-002 `in_progress` CI: wspólne, monotoniczne źródło `version_code` dla `build-android.yml`, `build-ios.yml` i `release.yml` (zależy od T-011)
  KA: jeden skrypt (np. `tools/version_code.sh`, minuty od 2026-01-01 UTC) używany przez wszystkie 3 workflowy zamiast `github.run_number`; jawny input `version_code` nadal ma pierwszeństwo. Test w `tools/test_tools.py`: dwa wywołania z rosnącym czasem dają rosnące wartości, wynik < 2 100 000 000 (limit Play) dla dat do 2100 r., wynik jest liczbą całkowitą. `actionlint` 0 błędów, `make check` zielone. Trigger `push` w build-* zostaje wyłączony (T-008) do czasu sekretów. ≤ ~80 linii.
  Skill: `godot-build`

- [ ] T-005 `todo` CI: niepodpisany build Android (debug AAB/APK) bez sekretów + weryfikacja kluczy `export_presets.cfg` i editor settings dla Godot 4.7.2 (zależy od T-011; po merge T-047 workflow ma objąć Gradle build — T-047 dopisuje ten krok)
  KA: klucze presetu Android/iOS oraz nazwa pliku editor settings (`editor_settings-4.7.tres`) i klucze `export/android/android_sdk_path`/`java_sdk_path` porównane ze źródłem Godot 4.7.2 (linki do plików w opisie PR); różnice poprawione; `tools/validate_presets.py` sprawdza listę wymaganych kluczy (test w `tools/test_tools.py`). Nowy workflow (`workflow_dispatch` + `pull_request` z filtrem ścieżek `game/export_presets.cfg`, `tools/setup_env.sh`, `Makefile`) instaluje SDK jak `build-android.yml`, generuje debug keystore `keytool` w runnerze (bez sekretów) i robi `--export-debug Android`; job jest czerwony, gdy plik wynikowy nie istnieje lub ma 0 B; artefakt uploadowany. W `Makefile` `export-check` przestaje maskować błąd (`|| true`) przy dostępnym SDK. Rozmiar AAB w podsumowaniu joba. ≤ ~150 linii.
  Skill: `godot-build`

- [ ] T-053 `todo` CI: niepodpisany export iOS na macOS (Xcode project + `xcodebuild` bez podpisu) i privacy manifest w presecie iOS w `export_presets.cfg` (zależy od T-005; T-048 po merge uruchamia ten workflow ręcznie jako swoją weryfikację)
  KA: workflow tylko `workflow_dispatch` + `pull_request` z filtrem ścieżek (`game/export_presets.cfg`, `game/ios/**`) — minuty macOS są drogie; `--export-release iOS` tworzy projekt Xcode, `xcodebuild … -sdk iphoneos CODE_SIGNING_ALLOWED=NO build` kończy się exit 0. Preset iOS ma uzupełnione opcje privacy manifestu (tracking, tracking domains, collected data types zgodne z listą w `docs/RELEASE_CHECKLIST.md`, required-reason APIs) — nazwy kluczy zweryfikowane w źródle Godot 4.7.2 (link w PR); krok joba sprawdza, że wygenerowany `PrivacyInfo.xcprivacy` istnieje i zawiera `NSPrivacyTracking` i `NSPrivacyCollectedDataTypes`. ≤ ~150 linii.
  Skill: `godot-build`

- [ ] T-040 `todo` UI: font OFL z diakrytykami (ą ć ę ł ń ó ś ź ż ä ö ü ß) jako domyślny font UI + etykieta `set_language` nad wyborem języka w Settings
  KA: plik `.ttf` z Google Fonts (OFL 1.1) w `game/assets/fonts/` + `OFL.txt` + wiersz w `docs/LICENSES.md`; font ustawiony przez zasób `Theme` w scenach UI (bez zmian w `project.godot` poza dozwolonymi sekcjami). Test gdUnit4: każdy znak każdego tekstu z `strings.csv` (EN/PL/DE) przechodzi `font.has_char()`. Etykieta nad wyborem języka w `SettingsScreen` z kluczem w CSV (EN/PL/DE). `make check` zielone. ≤ ~120 linii.
  Skill: `asset-gen`

- [ ] T-003 `todo` Tryb `--screenshot=<scene> --out=<png> [--lang=xx] [--fixture=<name>]` w `main.gd`, żeby `tools/gen_screenshots.sh` produkował obrazy (zależy od T-040)
  KA: parser argumentów jako czysta funkcja z testem gdUnit4 (poprawne argumenty, brak `--out`, nieznana scena → kod wyjścia ≠ 0); scena ładuje się ze stanem z fixture (in-memory `GameState`, bez zapisu do save'a gracza), po 2 klatkach zapisuje PNG i kończy exit 0; zły argument → exit ≠ 0. `make screenshots` lokalnie pod `xvfb-run` daje 1 PNG na każdą linię `tools/screens.txt` (lista plików w opisie PR). `make check` zielone. ≤ ~150 linii.
  Skill: `godot-dev`

- [ ] T-050 `todo` Screenshoty sklepowe: 5 kadrów z `docs/ASO.md` × EN/PL/DE do `fastlane/metadata/android/<locale>/images/phoneScreenshots` (zależy od T-003)
  KA: fixtures dla 5 kadrów z ASO (Level ~20 / 6 kolorów w trakcie gry, LevelComplete z „idealnie”, Home z kartą Poziomu dnia, DailyRewardPopup dzień 5 streaka, Themes z 4 motywami); `gen_screenshots.sh` iteruje po `en-US`/`pl-PL`/`de-DE` z `--lang`, captiony z ASO przetłumaczone (PL/DE natywnie) w `frame_screenshots.py`. Test w `tools/test_tools.py`: 15 plików PNG, każdy 1080×1920 (proporcja ≤ 2:1, wymóg Play). Wersja iOS (rozmiar 6,9") — tylko jeśli wymagany rozmiar zweryfikowany w dokumentacji ASC, inaczej wpis do Inbox. Zadanie wprost dotyczy `fastlane/metadata`. ≤ ~200 linii (bez PNG).
  Skill: `aso`

- [ ] T-051 `todo` Metadata sklepowe EN/PL/DE w `fastlane/metadata` (Android + iOS) z `docs/ASO.md`
  KA: Android `en-US`/`pl-PL`/`de-DE`: `title.txt`, `short_description.txt`, `full_description.txt`, `changelogs/default.txt`; iOS `en-US`/`pl`/`de-DE`: `name.txt`, `subtitle.txt`, `keywords.txt`, `description.txt`, `privacy_url.txt` (URL z T-052 albo placeholder `__PRIVACY_URL__`). Opis zawiera informację o reklamach i IAP (jak w ASO). Test w `tools/test_tools.py`: limity (tytuł/name/subtitle ≤ 30 znaków, short ≤ 80, full/description ≤ 4000, keywords ≤ 100 bajtów, brak słów z tytułu w keywords), żaden plik nie zawiera „TBD”. Zadanie wprost dotyczy `fastlane/metadata` (bez `Fastfile`). ≤ ~200 linii tekstu.
  Skill: `aso`

- [ ] T-052 `todo` Polityka prywatności (EN/PL) + odpowiedzi do Play Data Safety i App Store Privacy Labels (zależy od T-025)
  KA: `docs/privacy/index.md` (EN) i `docs/privacy/pl.md` — administrator All In IT sp. z o.o., kontakt `__PRIVACY_CONTACT__` do uzupełnienia przez Huberta, sekcje: dane zbierane przez GameAnalytics i AdMob (linki do dokumentacji SDK), IAP, zgoda UMP/ATT, prawa RODO, brak kont i danych wpisywanych przez gracza, 13+. W `docs/RELEASE_CHECKLIST.md` tabela odpowiedzi Data Safety (typ danych → zbierane/udostępniane/cel/opcjonalne) i Privacy Labels (kategoria → linked/tracking). Test w `tools/test_tools.py`: każdy z 16 eventów z `docs/GDD.md` → Analityka jest zmapowany w tabeli. Fakty o SDK z linkiem i datą, inaczej `ZWERYFIKUJ`. Treść do przeglądu prawnego przez Huberta przed publikacją. ≤ ~200 linii.
  Skill: `store-release`











## P2 — monetyzacja i meta (z GDD v1.0, R-003)

- [ ] T-047 `todo` Build Android: instalacja GodotGooglePlayBilling 3.3.0 w `make setup` (tag + SHA-256) i `gradle/use_gradle_build=true` w `export_presets.cfg` (zależy od T-026, Faza 4)
  KA: `make setup` pobiera release zip pluginu do `game/addons/GodotGooglePlayBilling/` i weryfikuje SHA-256; preset Android ma Gradle build; `make check` (w tym dry-run exportu) zielone; wpis w `docs/LICENSES.md`. ~80 linii. Zadanie wprost dotyczy `export_presets.cfg`.
  Skill: `godot-build`

- [ ] T-048 `todo` Build iOS: instalacja godot_ios_plugin_iap v0.4.0 (tag + SHA-256) i włączenie w presecie iOS w `export_presets.cfg` (zależy od T-026, Faza 4)
  KA: pliki pluginu w `game/ios/plugins/`, preset iOS go włącza, `make check` zielone, wpis w `docs/LICENSES.md` (MIT); build iOS weryfikowany na runnerze macOS w Fazie 4. ~60 linii. Zadanie wprost dotyczy `export_presets.cfg`.
  Skill: `godot-build`

- [ ] T-054 `blocked` QA na urządzeniu: podpisany AAB z Play Internal na fizycznym Androidzie + build TestFlight na iPhonie + Firebase Test Lab (zależy od T-005, T-053, T-047, T-048) — powód: brak kont Play/Apple, keystore, service account i ASC API key (`docs/SETUP_HUBERT.md` kroki 1–6)
  KA: `build-android.yml` (track `internal`) i `build-ios.yml` (TestFlight) zielone; raport QA w `docs/LOG.md`: FTUE, 20 pierwszych poziomów, Poziom dnia, daily reward, Shop + restore w sandboxie (Play test card / StoreKit sandbox), audio/haptyka, rozmiar instalacji (cel < 50 MB); Firebase Test Lab robo test bez crasha na ≥ 3 urządzeniach (sekcja „Jakość” w `docs/RELEASE_CHECKLIST.md`). Spełnienie = kryterium wyjścia z Fazy 4. Bez kodu (bugi → Inbox).
  Skill: `godot-build` + `godot-test`

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)

- [ ] T-055 `todo` CI: dokończyć T-011 — zweryfikować na stronach releases i podbić: actions/download-artifact (v4→v7?, para z upload-artifact v7), setup-java, android-actions/setup-android, ruby/setup-ruby, maxim-lobanov/setup-xcode, google-github-actions/setup-gcloud, EnricoMi/publish-unit-test-result-action; `actionlint` (w sesji bez dostępu do github.com/releases i bez pobierania binarek — zrobić w sesji z dostępem). Skill: godot-build
- [ ] T-049 `todo` App.show_shop z Poziomu dnia: powrót woła `show_level()` (kampania) zamiast `show_daily_level()`; zapamiętać ekran źródłowy i wracać do właściwego trybu (albo Shop jako overlay nad Level, bez utraty rundy). Skill: godot-dev
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
- [ ] T-041 `todo` Audio: podpiąć `click` (przyciski UI), `tube_full` (probówka pełna jednego koloru po przelewie), `Ads` → `Audio.set_app_muted` na czas reklamy; `HAPTIC_MS` jako const. Skill: godot-dev
- [ ] T-042 `todo` App/Level: `show_daily_level` bez obejścia `round = GameRound.new()` (flaga `autoload_level` w Level); `test_app.gd` z wstrzykniętym zegarem (teraz realny czas otwiera popup). Skill: godot-dev
- [ ] T-043 `todo` Themes: usunąć martwą `BoardView.THEMES_PATH`; nazwy motywów przez klucze `theme_name_*` w CSV; App odświeża Level po `theme_selected` (dziś od następnej rundy); GDD Meta: dopisać zasadę kosztu wg pozycji w katalogu. Skill: godot-dev
- [ ] T-034 `todo` CI: `tools/test_tools.py` nie jest uruchamiane przez `make check` ani test.yml — dodać cel `make test-tools` do `check` (+ Pillow w `make setup`); dopieścić kształt `flask` w gen_assets. Skill: godot-test

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
