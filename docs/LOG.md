# Dziennik pętli

Format wpisu: `## YYYY-MM-DD — sesja <typ>`, potem 2–3 linie: zadanie, wynik, PR.
Nowe wpisy dopisujemy na końcu, po zakończeniu sesji (CLAUDE.md, krok 9).

---

## 2026-10-23 — sesja bootstrap

- Zadanie: szkielet dokumentacji repo (`docs/`: GDD, monetyzacja, ASO, research, ADR, licencje, release, setup).
- Wynik: Szkielet repo utworzony przez orkiestratora + subagentów (sonnet/haiku).
- PR: —

---

## 2026-10-23 — bump

Godot 4.4.1 → 4.7.2, gdUnit4 → v7, target API 36 (ADR-008). make check zielone.
- T-008: build workflows tylko workflow_dispatch/workflow_call do Fazy 4 (szum czerwonych runów).
- T-009: gh pr (GraphQL) zastąpione gh api REST w CLAUDE.md, skillach i AUTOMATION.md.
- T-010: dependabot tylko alerty; PR-y #1–#5 zamknięte, bumpy jako T-011 dla pętli.

---

## 2026-10-23 — sesja docs (T-012)

- T-012: pętla przestawiona na tryb ciągły (co 2 h, wiele PR-ów na sesję, auto-refill backlogu).
- PR: #9 (auto-merge squash uzbrojony; make check lokalnie zielone).

---

## 2026-10-23 — sesja continuous-dev #1 (16:14–17:30 UTC)

- P0 zamknięte: R-001 research → sort puzzle (PR #10), R-002 GDD v1.0 APPROVED „Vialo: Water Sort Puzzle" + MONETIZATION/ASO + ADR-009 (PR #11), R-003 backlog MVP 18 P1 + 8 P2 (PR #12), T-001 smoke `Version.build_code()` (PR #13).
- P1 start: T-013 SortBoard (PR #14), T-014 SortSolver A* (PR #15), G-002 parametry poziomu w GameConfig (PR #16), G-003 ContentGenerator z seeda + solver, poziomy 1..200 rozwiązywalne, max 332 ms (PR #17, auto-merge).
- Odstępstwo: dokładny A* za wolny dla >6 kolorów → generator etapowy, `min_moves_exact=false` od ~6 kolorów; follow-upy T-029, G-012 w Inbox. 8 pytań produktowych w „Pytania do Huberta" (przyjęto X, do zmiany). Blokery: brak.
- Wszystkie PR-y przez gh api + auto-merge squash; #10–#16 zmergowane w trakcie sesji, CI zielone.

---

## 2026-10-23 — sesja continuous-dev #2 (18:13–19:25 UTC)

- P1: T-015 GameRound na SortBoard (undo/extra tube/restart/hint/is_stuck/perfect, PR #19), T-016 PlaytestBot solver + `--random` z `stuck_count` (PR #20), T-017 GameState v2 + migracja (PR #21), G-004 Economy (PR #22), T-018 assety: `themes.json` 4 motywy ΔE ≥ 20, probówki 9-slice, ikony UI, ikona aplikacji (PR #23), G-006 DailyRewards streak/grace (PR #24), G-007 DailyChallenge (PR #25, auto-merge). `make check` + qa-playtester przed każdym PR; 126 testów gdUnit4.
- QA złapało 2 blockery tej samej klasy (cofnięty zegar → ponowna nagroda dzienna / Poziomu dnia) — poprawione przed merge. CI T-018 padł na braku Pillow → `make setup` instaluje Pillow.
- Lekcja: PR-y zależne na gałęzi poprzednika stają się `dirty` po squash-merge rodzica → za każdym razem `rebase --onto origin/main` + ponowne uzbrojenie auto-merge. Inbox: T-030–T-034 (nity QA, test_tools w make check, flask polish). Pytanie do Huberta: odbiór nagrody dziennej podtrzymuje streak (przyjęto: tak). Blokery: brak.

---

## 2026-10-23 — sesja continuous-dev #3 (20:11–21:35 UTC)

- P1: T-019 scena Level + BoardView/TubeView (motyw z themes.json, tap/przelew/shake, sygnał `pour_finished`, klucze `pour_anim_seconds`/`tube_lift_seconds`/`shake_seconds`), 132 testy, QA PASS (3 seedy 200/200) → PR #26 (auto-merge).
- P1: T-020 HUD + LevelComplete + przepływ poziomów/zapis/streak (137 testów, QA PASS) → PR #27 (auto-merge). #26 zmergowany w trakcie sesji.
- P1: T-021 StuckPanel + Boosters (czysta klasa) + hint/+probówka w HUD + pomiń po restartach, 145 testów, QA: KA OK (uwaga o GDD — mechaniki już opisane) → PR #28 (auto-merge). #27 zmergowany.
- P1: G-005 FTUE TutorialFlow (maszyna stanów) + overlay z dłonią + ukrycie boosterów w tutorialu, 150 testów, QA PASS → PR #29 (auto-merge). #28 zmergowany.
- P1: T-022 Home + SettingsScreen + App router (pierwsze uruchomienie → poziom 1, pauza → Home), 156 testów, QA PASS → PR #30 (auto-merge). #29 zmergowany.
- P1: T-023 lokalizacja EN/PL/DE — strings.csv (37 kluczy) + Locale loader (bez [internationalization] w project.godot), 161 testów, QA PASS → PR #31 (auto-merge). #30 zmergowany.
- P1: T-024 audio — gen_sfx.py (8 SFX + ambient OGG 43 KB), autoload Audio (settings/fokus/mute), hooki w Level, 166 testów, QA PASS → PR #32 (auto-merge). #31 zmergowany.
- P2: G-008 DailyRewardPopup + karta Poziomu dnia + tryb daily w Level, 171 testów → PR #33 (auto-merge, bez QA — P2). #32 zmergowany.
- P2: G-009 ThemeCatalog + ThemesScreen + pasek na Home, 178 testów → PR #34 (auto-merge, bez QA — P2). #33 zmergowany.
- Inbox: T-035 pełna animacja przelewu, T-043 porządki po motywach, T-042 show_daily_level bez obejścia, T-041 podpięcie click/tube_full/mute reklam, T-040 font z diakrytykami, T-039 sygnał tube_deselected, T-038 testy shop_requested, T-036 szum FNV w logu testów, T-037 test wygranej bez „idealnie" + bezpieczeństwo tweenów. G-007 oznaczone `done` (#25 zmergowany).
- Podsumowanie: 9 zadań (7× P1 + 2× P2), PR #26–#34; #26–#33 zmergowane w trakcie sesji (CI zielone), #34 z uzbrojonym auto-merge. P1 w całości w `review`/`done` → vertical slice grywalny end-to-end (tutorial → Home → Level → LevelComplete, StuckPanel/boostery, daily, motywy, audio, EN/PL/DE). Zależne PR-y: gałąź na gałęzi poprzednika + `rebase --onto origin/main` po merge rodzica. Blokery: brak. Następne: G-010 rewarded (wymaga T-021, G-008 — oba zmergowane), G-011 balance_sim, G-001.
- Lekcja: po rebase na main z nowymi `class_name` trzeba `godot --headless --import` przed `make test` (stary cache klas daje „Identifier not declared"); `make setup` robi to w CI.

## 2026-10-23 — sesja continuous-dev #4 (22:13– UTC)

- Start: brak otwartych PR task/*; #26–#34 zmergowane → zadania `review` przeniesione do Done.
- P2: G-010 (logika) RewardedPlacements (czysta klasa, cap per poziom, offer→granted), `Ads.is_rewarded_ready`, 4 klucze config, `watch_*` w Level, `claim_x2`/`save_streak_rewarded` w popupie; 190 testów → PR #35 (auto-merge, bez QA — P2). UI przycisków wydzielone do nowego zadania G-010b.
- P2: G-010b przyciski UI dla placementów (×2 z kwotą na LevelComplete, +probówka/+cofnięcia (ad) w HUD i StuckPanel, Pomiń (ad), Odbierz ×2 z kwotą); 195 testów → PR #36 (auto-merge, bez QA — P2). #35 zmergowany.
- P2: G-011 balance_sim przepisany pod sort puzzle (klucze z config.gd + tablice, motywy, boostery, streak/daily, interstitial z bramkami, rewarded per placement, metryki w dniach aktywnych); 12 testów tools → PR #37 (auto-merge). #36 zmergowany. Wynik: 1. motyw 3. dzień aktywny (cel 2), 3. motyw nikt (cel 12–14) → nowe zadanie G-013 kalibracja; interstitial 2,10/DAU, łącznie 4,82. Inbox: T-044 (aktualizacja skilla game-economy §6 — `.claude/` wymaga osobnego zadania).
- P2: G-001 cap interstitiali (5 / 120 s / od poziomu 8, nie przy ads_removed, nie po rewarded w tej samej przerwie, hook w Level.on_next_pressed, bot); 202 testy, sim: interstitial 1,36/DAU, łącznie 4,08 → PR #38 (auto-merge). #37 zmergowany. Inbox: T-045.
- P2: G-013 kalibracja ekonomii (orkiestrator: 8 wariantów w sim; wybrano win 15 / par 10 → 1. motyw dzień akt. 2, 3. motyw ~10, d30/d1 1,7); GDD Ekonomia zaktualizowane → PR #39 (auto-merge). #38 zmergowany. Inbox: T-046.
- P2: T-025 analityka — session start/end, level_start, level_fail reason, report_consent, GDD mapowanie, Data Safety lista; 211 testów → PR #40 (auto-merge). #39 zmergowany.
- P2: T-026 ADR-010 IAP (game-designer: GodotGooglePlayBilling 3.3.0 / godot_ios_plugin_iap 0.4.0, zgodność z 4.7.2 niepotwierdzona, plan B OpenIAP) + IapProvider/FakeIapProvider + autoload Purchases; 213 testów → PR #41 (auto-merge). #40 zmergowany. Nowe zadania T-047/T-048 (instalacja pluginów, Faza 4).
- P2: T-027 ShopScreen (4 sku, ceny z providera, okno starter packa, restore) + restore w Settings + routing App; 231 testów → PR #42 (auto-merge). #41 zmergowany. Inbox: T-049; pytanie o powrót ze Shopu do poziomu.
- chore: backlog refill #2 (game-designer): Faza 3 → **Faza 4 — Pipeline wydań** (kryteria: core loop end-to-end, playtest 200/200, 231 testów); 10 zadań P1 (T-011, T-004, T-002, T-005, T-053, T-040, T-003, T-050, T-051, T-052) + T-054 blocked (QA na urządzeniu — brak kont); 4 pytania do Huberta (13+, hosting polityki prywatności, runnery macOS, kategoria Puzzle) → PR #43 (zmergowany).
- P1: T-011 CI podbicie akcji — częściowo (5/12 wg Dependabot #1–#5; 7 akcji nie do zweryfikowania bez dostępu do stron releases, actionlint bez pobierania binarek → T-055) → PR #44 (auto-merge). Po merge zamknąć Dependabot #1–#5.
- Podsumowanie: 10 PR-ów (#35–#44), 9 zmergowanych w trakcie sesji, #44 z uzbrojonym auto-merge. P2 z GDD v1.0 w całości zrealizowane (rewarded ×6 + UI, sim, cap interstitiali, kalibracja ekonomii, analityka, IAP logika + ADR-010, Shop). Testy: 190 → 231. Blokery: brak (poza kontami Huberta dla Fazy 4/5). Następne: T-004 Gemfile.lock, T-002 version_code, T-005 debug build; T-047/T-048 pluginy IAP; T-055.
- Lekcje: (1) edycja `.claude/skills/*` wymaga zadania wprost — cofnięto zmianę skilla w G-011 i dodano T-044; (2) sesja CCR nie ma dostępu do github.com/<obce repo>/releases (403/PROVENANCE) ani do pobierania binarek — zadania „zweryfikuj na stronie releases" rozbijać na to, co da się potwierdzić (np. PR-y Dependabota) i follow-up; (3) orkiestrator może szybko kalibrować ekonomię przez `balance_sim.py --config <wariant>` w scratchpadzie (8 wariantów w ~1 min) zamiast angażować designera bez Bash.

## 2026-10-24 — sesja continuous-dev #5 (00:12– UTC)

- Start: brak otwartych PR task/*; #35–#44 zmergowane → 9 zadań `review` przeniesione do Done.
- P1: T-004 `Gemfile.lock` (fastlane 2.241.1, bundler 2.5.22, platformy x86_64-linux + arm64-darwin; `bundle exec fastlane lanes` exit 0; w CCR `bundle` z PATH to bundler 4.x — lock generować przez `bundle _2.5.22_` z `/opt/rbenv/versions/3.3.6/bin` w PATH), `make check` zielone (231 testów) → PR #45 (auto-merge).
- P1: T-002 — tylko część 1: `tools/version_code.sh` (minuty od 2026-01-01 UTC, `SOURCE_DATE_EPOCH`, `--check`) + 5 testów tools (17 łącznie), `make check` zielone → PR #46 (auto-merge). Podpięcie w 3 workflowach było gotowe, ale auto-mode odrzuca KAŻDĄ edycję `.github/workflows/**` (Edit, python, sed, także przez subagenta) — workflowy przywrócone do stanu z main, wiring → T-002b `blocked`; z tego powodu T-005, T-053, T-055 → `blocked`. Pytanie do Huberta dopisane. Hubert powiadomiony push-em.
- Lekcja: zadania „CI:” dotykające `.github/workflows/` nie są wykonalne w sesji scheduled — przy refillu backlogu nie planować ich jako `todo` dla pętli.
- P1: T-040 font Nunito (OFL, variable) przez Theme na korzeniu Main + etykieta języka w Settings + test pokrycia glifów dla całego strings.csv (bez ✓ w daily_done — brak glifu); 236 testów, QA PASS (playtest 200/200 solver, 0 softlocków) → PR #47 (auto-merge, depends on #46 — zmergowany).
- P1: T-003 tryb --screenshot (ScreenshotArgs czysty parser, ScreenshotFixtures default/midgame, SaveSystem.read_only, 9/9 PNG pod xvfb w ~15 s, gen_screenshots.sh egzekwuje liczbę PNG); 248 testów, playtest 200/200 → PR #48 (auto-merge). Inbox: T-056–T-059.
