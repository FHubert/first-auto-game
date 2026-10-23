# Backlog

Statusy: `todo` · `in_progress` · `review` (PR otwarty) · `blocked` · `done`
Każde zadanie: ID, status, tytuł, **kryterium akceptacji (KA)**, skill.
Pętla bierze pierwsze `todo` z najwyższej sekcji. Zadania P0 muszą być `done` zanim pętla wejdzie w P1.

## P0 — fundamenty (Faza 1–2)





## P1 — core loop i retencja (z GDD v1.0, R-003)




- [ ] G-003 `done` ContentGenerator: tasowanie z seeda + solver + regeneracja seed+attempt (zależy od T-014, G-002) → PR #17
  KA: `generate(seed, level)` zwraca payload wg ADR-009. Testy: (a) determinizm, czyli 2 wywołania dają identyczne `tubes`; (b) golden hash dla poziomów 1, 2, 10, 50; (c) poziomy 1..200: odtworzenie `solution` przez `SortBoard` kończy się `is_won()` w `min_moves` ruchach, `attempt < gen_max_attempts`; (d) ≥ 95 % poziomów spełnia `min_moves >= floor` (odsetek w logu); (e) czas ≤ 500 ms/poziom headless (zmierzony i wypisany). Placeholder `is_solvable` zastąpiony. `make test` zielone. ~260 linii.
  Skill: `godot-dev`

- [ ] T-015 `review` GameRound na SortBoard: ruchy, cofnij, +probówka, restart, utknięcie, podpowiedź, „idealnie" (zależy od G-003) → PR #19
  KA: kontrakt `start/step/result` zachowany; `step(action)` z `action = from*16 + to`. Dodane metody: `undo()` (ładunki `undo_free_per_level`, `add_undo_charges(n)`), `add_extra_tube()` (max `extra_tube_max_per_level`), `restart()`, `is_stuck()`, `hint() -> Vector2i` (1. ruch solvera), `moves_to_goal()`, `can_skip()` (po `skip_unlock_restarts`). `result()` zawiera `won, moves, min_moves, perfect, undos_used, boosters_used`. Testy dla każdej metody wg GDD → Mechaniki, w tym „po podpowiedzi moves_to_goal maleje o 1" dla 20 stanów. `make test` zielone. ~280 linii.
  Skill: `godot-dev`

- [ ] T-016 `review` PlaytestBot = solver + tryb losowy (zależy od T-015) → PR #20
  KA: `make playtest` gra 200 poziomów ścieżką `solution`. Raport JSON: `rounds=200`, `wins=200`, `softlocks=0`, `errors=[]`, `avg_moves`, `interstitials_shown`. Tryb `--random` (losowe legalne ruchy, restart po `is_stuck`) raportuje `stuck_count` i 0 softlocków. Czas < 120 s na CI. ~200 linii.
  Skill: `godot-test`

- [ ] T-017 `review` GameState schema v2 + migracja v1→v2 → PR #21
  KA: nowe pola: `daily_reward_last_claim_day`, `daily_last_completed_day`, `daily_completed_total`, `streak_best`, `streak_saves_used` (z dniem okna), `themes_owned` (Array[String], domyślnie `["classic"]`), `theme_active`, `levels_completed`, `level_restarts` (bieżący poziom), `starter_offer_start_day`, `purchases` (sku → bool); `settings` z `music_on/sfx_on/haptics_on/ads_removed/tutorial_done/locale`. Testy: round-trip, migracja v1 daje wartości domyślne, odrzucanie złych typów i wartości ujemnych. `make test` zielone. ~220 linii.
  Skill: `godot-dev`

- [ ] G-004 `review` Economy: earn/spend, nagroda za wygraną, premia „idealnie", koszty boosterów (zależy od T-017) → PR #22
  KA: `economy.gd` (czysta klasa): `earn(state, amount, source)`, `spend(state, amount, sink) -> bool` (przy braku środków false i saldo bez zmian), `win_reward(result) -> int` (`win_reward_coins` + `par_bonus_coins` przy perfect). Do `config.gd` dodane klucze ekonomii z GDD (`par_*`, `*_cost_coins`, `undo_refill_amount`, `theme_cost_*`, `daily_challenge_coins`, `starting_coins`=100). Testy: saldo nigdy < 0, wartości zgodne z GDD. `make test` zielone. ~200 linii.
  Skill: `game-economy`

- [ ] T-018 `todo` Assety wizualne: palety 4 motywów, sprite'y probówek (2 kształty), ikony UI, ikona aplikacji
  KA: `tools/gen_assets.py` generuje `themes.json` (classic/pastel/neon/ocean, każdy z 12 płynami, tłem i kształtem `tube|flask`; classic = hex z GDD), sprite'y probówek 9-slice, 6 ikon UI i ikonę 1024 (bez alfy) oraz 512. `tools/test_tools.py` sprawdza 12 unikalnych hex na motyw i minimalne ΔE ≥ 20 między kolorami. `make check` zielone. Brak obcych assetów. ~250 linii.
  Skill: `asset-gen`

- [ ] T-019 `todo` Scena Level: BoardView (rysowanie probówek, tap, przelew tween, shake) (zależy od T-015, T-018)
  KA: `level.tscn` + `board_view.gd` rysuje `payload` w aktywnym motywie. Pierwszy tap wybiera probówkę (podniesienie), drugi wykonuje `pour` z tweenem `pour_anim_seconds`, a nielegalny ruch daje shake. Widok emituje sygnał `pour_finished`. Test headless: instancja sceny z poziomem 2 i 2 symulowane tapy dają zmianę stanu `GameRound`. Wpis w `tools/screens.txt`, `make screenshots` daje PNG. `make check` zielone. ~280 linii.
  Skill: `godot-dev`

- [ ] T-020 `todo` HUD + LevelComplete + przepływ poziomów i zapis (zależy od T-019, G-004)
  KA: HUD pokazuje numer poziomu, ruchy, cofnij z licznikiem, restart i pauzę. Po wygranej ekran `LevelComplete` pokazuje monety i „idealnie", a „Dalej" przechodzi do kolejnego poziomu. `SaveSystem.save` po każdej wygranej. Test headless: wygrana ścieżką solvera podnosi `level` o 1 i coins o `win_reward`, a ponowne wczytanie zachowuje stan. Oba ekrany mają wpis w `screens.txt`. `make check` zielone. ~280 linii.
  Skill: `godot-dev`

- [ ] T-021 `todo` StuckPanel + przyciski boosterów (ścieżka monet) (zależy od T-020)
  KA: `StuckPanel` pojawia się przy `is_stuck()` i pokazuje „X ruchów od celu". Opcje: cofnij, +probówka (60 monet), +3 cofnięcia (20), podpowiedź w HUD (25), restart, pomiń (widoczne, gdy `can_skip`). Brak monet prowadzi do `Shop` (placeholder). Testy: zakup za monety zmniejsza saldo i przyznaje efekt; przy braku środków efekt nie jest przyznany. Wpis w `screens.txt`. `make check` zielone. ~240 linii.
  Skill: `godot-dev`

- [ ] G-005 `todo` FTUE: tutorial poziomu 1 (3 kroki) (zależy od T-020)
  KA: `tutorial_flow.gd` (czysta maszyna stanów): wskaż źródło, wskaż cel, ukończ. Krok przechodzi tylko po właściwym ruchu, a na koniec ustawia `settings.tutorial_done`. Overlay z dłonią w scenie Level. Pierwsze uruchomienie pomija `Home` i otwiera poziom 1. Testy maszyny stanów i test „poziom 1 ma 2 kolory, min_moves ≤ 4". `make check` zielone. ~200 linii.
  Skill: `game-economy`

- [ ] T-022 `todo` Ekrany Home + Settings + nawigacja (zależy od T-020)
  KA: `Home` pokazuje „Graj: poziom N", monety, streak, pasek do następnego motywu (placeholder) oraz przyciski Motywy, Sklep i Ustawienia. `Settings` ma przełączniki muzyki, SFX, haptyki i języka, zapisywane w `GameState.settings`, oraz wersję z `BUILD_INFO`. Test headless: zmiana przełącznika przetrwa save/load. Oba ekrany w `screens.txt`. `make check` zielone. ~280 linii.
  Skill: `godot-dev`

- [ ] T-023 `todo` Lokalizacja EN/PL/DE (CSV + TranslationServer) (zależy od T-022)
  KA: `game/locale/strings.csv` z kluczami wszystkich istniejących ekranów i import w projekcie. Test: każdy klucz ma 3 niepuste tłumaczenia, a teksty z prefiksem `btn_` mają ≤ 18 znaków. Język z ustawień albo systemowy. `make check` zielone. ~200 linii (bez CSV).
  Skill: `godot-dev`

- [ ] T-024 `todo` Audio: generowane SFX + muzyka ambient + AudioService
  KA: `tools/gen_assets.py` generuje 6 SFX (przelew ×3 warianty, pełna probówka, wygrana, klik, błąd, monety) i 1 pętlę ambient OGG. Autoload `Audio` respektuje `music_on/sfx_on` i wycisza się przy utracie fokusu. Haptyka przez `Input.vibrate_handheld` przy `haptics_on`. Test: przy `sfx_on=false` `Audio.play_sfx` nie odtwarza. `make check` zielone. `docs/LICENSES.md` bez zmian (brak obcych plików). ~250 linii.
  Skill: `asset-gen`

- [ ] G-006 `todo` DailyRewards: nagroda dzienna + streak + grace (zależy od T-017)
  KA: `daily_rewards.gd` (czysta klasa, dzień UTC wstrzykiwany). Testy: dni 1..7 dają 50/50/100/100/150/150/300 (`daily_reward_multipliers`); drugi odbiór tego samego dnia jest odrzucony; przerwa 1 dnia daje `can_save_streak` (max `streak_save_max_per_week`, okno liczone od `GameState.streak_save_window_day`); przerwa ≥ 2 dni resetuje do 1; `streak_best` jest aktualizowany. Klucze dopisane do `config.gd`. `make test` zielone. ~220 linii.
  Skill: `game-economy`

- [ ] G-007 `todo` DailyChallenge: Poziom dnia z seeda dnia UTC (zależy od G-003, T-017)
  KA: `daily_challenge.gd`: `level_for_day(utc_day)` (`daily_colors`, `daily_min_moves_factor`), `complete(state, utc_day, result)` przyznaje `daily_challenge_coins` raz na dzień. Testy: ten sam dzień daje identyczny poziom; dni 20750..20779 dają 30 różnych, rozwiązywalnych poziomów; drugie ukończenie tego samego dnia nie daje monet; `daily_unlock_level`=3 jest respektowany. `make test` zielone. ~160 linii.
  Skill: `game-economy`

## P2 — monetyzacja i meta (z GDD v1.0, R-003)

- [ ] G-008 `todo` UI dzienne: DailyRewardPopup + karta Poziomu dnia na Home + tryb daily w Level (zależy od G-006, G-007, T-022)
  KA: popup przy pierwszym wejściu dnia (7 kafelków, „Odbierz", wariant „Uratuj streak"); karta na Home ze stanem i licznikiem do północy UTC; Level w trybie `daily` (bez „pomiń"). Test headless: symulowany dzień X, odbiór, ponowne wejście tego samego dnia nie pokazuje popupu. Wpisy w `screens.txt`. `make check` zielone. ~280 linii.
  Skill: `godot-dev`

- [ ] G-009 `todo` ThemeCatalog + ekran Themes (zależy od G-004, T-018, T-022)
  KA: `theme_catalog.gd` wczytuje `themes.json`. Koszt n-tego płatnego motywu = round(600 × 1.8^(n-1)), czyli 600/1080/1944. Zakup przez `Economy.spend` (przy braku środków odrzucony), aktywny motyw zapisywany i stosowany w BoardView. Ekran Themes z podglądem i ceną; pasek „do następnego motywu" na Home. Testy kosztów, zakupu i persystencji. Wpis w `screens.txt`. `make check` zielone. ~280 linii.
  Skill: `game-economy`

- [ ] G-010 `todo` Rewarded: 6 placementów przez Ads.request_rewarded (zależy od T-021, G-008)
  KA: `double_coins` (LevelComplete, od poziomu 2), `extra_tube`, `undo_refill` (max 2 na poziom), `skip_level`, `daily_x2`, `streak_save` z id zgodnymi z `docs/MONETIZATION.md`. Kwota nagrody widoczna na przycisku przed reklamą, przycisk ukryty, gdy reklama nie jest gotowa. Testy z `FakeAdProvider`: granted przyznaje nagrodę dokładnie raz; skipped i unavailable nie przyznają nic; cap per poziom/dzień jest respektowany. `make check` zielone. ~260 linii.
  Skill: `ads-iap`

- [ ] G-011 `todo` balance_sim pod sort puzzle (zależy od G-004, G-006)
  KA: `tools/balance_sim.py` czyta nowe klucze (`theme_cost_base/growth`, koszty boosterów, `par_bonus_coins`, `daily_reward_multipliers`, `daily_challenge_coins`, `interstitial_min_seconds`, `interstitial_min_level`). `make sim` kończy się exit 0. W PR tabela: mediany monet d1/d7/d30, dzień zakupu 1. i 3. motywu (cel ~2 i ~12–14), impresje/DAU (interstitial ≤ 2,5, łącznie ≥ 3,0). `tools/test_tools.py` zielone. ~200 linii.
  Skill: `game-economy`

- [ ] G-001 `todo` Balans: cap interstitiali (zależy od G-011)
  KA: `interstitial_every_n_rounds`=5, `interstitial_min_seconds`=120, nowy klucz `interstitial_min_level`=8. `Ads.maybe_show_interstitial` nie pokazuje reklamy przy `ads_removed` ani po rewarded w tej samej przerwie. Testy w `test_ad_service.gd`; `make sim` pokazuje ≤ 2,5 interstitiala/DAU (poprzednio ~8,6 przy co 3 rundy). ~120 linii.
  Skill: `game-economy` + `ads-iap`

- [ ] T-025 `todo` Analityka: eventy z GDD → Analityka (zależy od G-010)
  KA: wszystkie 16 eventów z GDD wysyłane przez `Analytics` w opisanych momentach i z parametrami. `FakeAnalyticsProvider` zapisuje wywołania. Test: sekwencja start → complete (perfect) → ×2 → interstitial daje oczekiwaną listę wywołań z parametrami. Wpis do `docs/RELEASE_CHECKLIST.md`: lista do Data Safety/Privacy Labels. `make check` zielone. ~250 linii.
  Skill: `ads-iap`

- [ ] T-026 `todo` ADR-010 IAP + IapProvider/FakeIapProvider + logika przyznawania
  KA: ADR-010 w `docs/DECISIONS.md`: wybór GodotGooglePlayBilling (wersja z Billing Library 8+, zweryfikowana) oraz pluginu StoreKit dla iOS, wraz ze statusem zgodności z Godot 4.7.2. Interfejs `IapProvider` (connect/products/purchase/restore, sygnały) i `FakeIapProvider`. Logika `Purchases.grant(sku)`: `remove_ads` ustawia `settings.ads_removed`, `coins_*` daje +500/+1500, `starter_pack` daje +800 i motyw „neon" jednorazowo. Testy: PURCHASED przyznaje, PENDING nie przyznaje, restore przywraca `remove_ads`, starter pack przyznawany tylko raz. `make check` zielone. Bez dodawania pluginów. ~250 linii.
  Skill: `ads-iap`

- [ ] T-027 `todo` Ekran Shop + „Przywróć zakupy" + okno starter packa (zależy od T-026, G-009)
  KA: Shop pokazuje 4 sku z cenami z `IapProvider` (nigdy z kodu). „Przywróć zakupy" jest w Shop i Settings. `starter_pack` jest widoczny od `starter_offer_min_level`=12 przez `starter_offer_hours`=72 h. Wejście ze StuckPanel przy braku monet. Testy z `FakeIapProvider`: okno oferty (dzień startu, przed i po 72 h) oraz restore. Wpis w `screens.txt`. `make check` zielone. ~250 linii.
  Skill: `ads-iap`

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)

- [ ] T-002 `todo` Wspólne, monotoniczne źródło version_code dla build-android.yml i release.yml (np. epoch-minutes lub licznik w vars); run_number per workflow może cofać numer i Play odrzuci AAB. Skill: godot-build
- [ ] T-003 `todo` Implementacja --screenshot=<scene> --out=<dir> w main.gd (zapis PNG po 1 klatce), żeby tools/gen_screenshots.sh działał. Skill: godot-dev
- [ ] T-004 `todo` Gemfile.lock wygenerowany i zacommitowany (bundle lock --add-platform x86_64-linux arm64-darwin). Skill: store-release
- [ ] T-005 `todo` Zweryfikować w edytorze Godot 4.7 klucze export_presets.cfg (Android/iOS) i nazwę pliku editor settings + klucz android_sdk_path użyty w workflowach; poprawić jeśli się różnią. Skill: godot-build
- [ ] T-006 `todo` Postawić pierwszy tag v0.1.0 (git describe w prompcie biweekly-release wymaga istniejącego taga). Skill: store-release
- [ ] T-007 `todo` Sprawdzić czy deny Edit(fastlane/Fastfile) itd. w .claude/settings.json działa jak zamierzono (metadata edytowalne, lanes nie); patrz ZWERYFIKUJ w docs/AUTOMATION.md. Skill: godot-test
- [ ] T-011 `todo` CI: podbić wersje akcji w .github/workflows (checkout v7, setup-python v6, cache v6, upload-artifact v7, google-github-actions/auth v3) i Gemfile; `make check` + actionlint. Skill: godot-build
- [ ] T-028 `todo` SaveSystem.load: test pliku uszkodzonego wypisuje `ERROR: Parse JSON failed` do logu (JSON.parse_string); użyć `JSON.new().parse()` i sprawdzać kod błędu, żeby log CI był czysty. Skill: godot-dev
- [ ] T-029 `todo` SortSolver: optymalizacja (~0,4 ms/stan: clone planszy, canonical_key jako String, path.duplicate per węzeł → rodzic+indeks, klucz PackedByteArray/int); cel: dokładny A* dla ≥ 8 kolorów w ≤ 500 ms, wtedy min_moves_exact=true dla większości poziomów. Skill: godot-dev
- [ ] G-012 `todo` GDD/ADR-009: dopisać, że generator używa etapów (quick pass 250 stanów → dokładny A* ≤ 6 kolorów/1000 stanów → ważony A*), więc `min_moves_exact=false` jest normą od ~6 kolorów (premia „idealnie" liczona od wyniku ważonego + par_slack_moves); przenieść stałe EXACT_MAX_COLORS/EXACT_STATE_BUDGET/QUICK_STATE_BUDGET z content_generator.gd do GameConfig. Skill: game-economy
- [ ] T-030 `todo` GameRound: literały wag solvera (1.0 / fallback 3.0) jako const/klucz; komentarz o limicie ACTION_BASE=16 probówek; `add_extra_tube` przez metodę SortBoard zamiast mutacji `tubes`; `undo_refill_amount` bez konsumenta do G-010. Skill: godot-dev
- [ ] T-031 `todo` PlaytestBot: test ścieżki `gave_up` (`max_restarts_per_round=0` → przegrana bez softlocka); udokumentować `--random`/`--max-restarts` w `.claude/skills/godot-test/SKILL.md` (zadanie dotyczy wprost `.claude/`). Skill: godot-test
- [ ] T-032 `todo` GameState.from_dict: zły typ pojedynczego klucza `settings` odrzuca cały zapis (utrata postępu) — rozważyć reset klucza do domyślnej; `_as_int` bez górnego limitu (NaN/1e30). Skill: godot-dev
- [ ] T-033 `todo` Economy: `rewarded_bonus` → `maxi(0, …)` przy multiplier < 1; `buy_booster` bez `SINK_THEME` (zakup motywu w G-009); testy `can_afford` i dwu zdarzeń Analytics w `apply_win`. Skill: game-economy

## Pytania do Huberta
- R-001: mix rynków przy soft launchu do szacowania ARPDAU — przyjęto: 30 % US / 30 % DE / 40 % PL, do zmiany (bardziej US-owy mix podnosi ARPDAU, eCPM US ~5–10× PL).
- R-001: wyróżnik na tle klonów sort puzzle — przyjęto: daily seed + odblokowywane motywy wizualne (doprecyzuje R-002), do zmiany.
- R-002: nazwa i tytuł — przyjęto: „Vialo: Water Sort Puzzle” (zapasowe: „Flaskly: Color Sort Puzzle”, „Pourio: Daily Water Sort”), do zmiany; przed Fazą 4 sprawdzić EUIPO/UPRP i dostępność w ASC/Play.
- R-002: paleta płynów — przyjęto: 12 kolorów na motyw jako wyjątek od limitu 6 kolorów UI (gatunek wymaga 12 rozróżnialnych), do zmiany.
- R-002: granica dnia (Poziom dnia, streak, daily reward) — przyjęto: UTC (zmiana o 01:00/02:00 w PL/DE), do zmiany.
- R-002: starter pack — przyjęto: 1,99 USD = 800 monet + motyw, bez remove_ads, do zmiany.
- R-002: ranking Poziomu dnia — przyjęto: brak rankingu i backendu w MVP, do zmiany.
- R-002: KPI ARPDAU — szacunek ~0,036–0,040 USD przy mixie 30/30/40 jest poniżej celu 0,05; przyjęto: jedziemy dalej, dźwignia = większy udział US w ruchu, do zmiany.

## Done (ostatnie 30)
- [x] T-009 `done` CLAUDE.md/skille: gh pr → gh api REST (GraphQL 403 w CCR) → PR #7 (zmergowany)
- [x] T-010 `done` CI: dependabot nie otwiera PR-ów (open-pull-requests-limit: 0); aktualizacje zależności robi pętla → PR #8 (zmergowany)
- [x] T-008 `done` build-android/build-ios: trigger push usunięty do czasu konfiguracji sekretów (Faza 4); przywrócić w zadaniu T-002. → PR #6 (zmergowany)
- [x] T-012 `done` Docs: tryb ciągły (continuous-dev co 2 h) w CLAUDE.md/AUTOMATION.md/game-designer → PR #9 (zmergowany)
- [x] R-001 `done` Research rynku i wybór gatunku → PR #10 (zmergowany 2026-10-23)
- [x] R-002 `done` GDD v1 dla wybranego gatunku → PR #11 (zmergowany 2026-10-23)
- [x] R-003 `done` Backlog MVP z GDD → PR #12 (zmergowany 2026-10-23)
- [x] T-001 `done` Smoke: środowisko i pętla działają end-to-end → PR #13 (zmergowany 2026-10-23)
- [x] T-013 `done` SortBoard: model planszy water sort (czysta klasa) → PR #14 (zmergowany 2026-10-23)
- [x] T-014 `done` SortSolver: A* z heurystyką granic kolorów i limitem stanów (zależy od T-013) → PR #15 (zmergowany 2026-10-23)
- [x] G-002 `done` Parametry poziomu z GameConfig (kolory, d, breather, min_moves_floor) → PR #16 (zmergowany 2026-10-23)
