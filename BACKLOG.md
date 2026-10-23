# Backlog

Statusy: `todo` · `in_progress` · `review` (PR otwarty) · `blocked` · `done`
Każde zadanie: ID, status, tytuł, **kryterium akceptacji (KA)**, skill.
Pętla bierze pierwsze `todo` z najwyższej sekcji. Zadania P0 muszą być `done` zanim pętla wejdzie w P1.

## P0 — fundamenty (Faza 1–2)

- [ ] R-001 `review` Research rynku i wybór gatunku → PR #10
  KA: `docs/RESEARCH.md` z analizą 3 kandydatów (gatunek, przykłady top-10, szacunkowy ARPDAU, złożoność contentu, czy content jest generowalny proceduralnie, konkurencja ASO w PL/US/DE). Rekomendacja z uzasadnieniem. Decyzja: **bierz kandydata nr 1** (Hubert zaakceptował delegację wyboru), chyba że `## Pytania do Huberta` ma odpowiedź inną. Zaktualizuj `docs/STATUS.md`.
  Skill: `analytics-review` (sekcja research) + WebSearch/WebFetch.

- [ ] R-002 `review` GDD v1 dla wybranego gatunku → PR #__PR__
  KA: `docs/GDD.md` ze statusem `APPROVED` (zamiast `DRAFT`): core loop (1 akapit + diagram ASCII), sesja 2–5 min, progresja, ekonomia (waluty, sinki, źródła), meta (daily, streak), lista ekranów, lista mechanik z priorytetem MVP/later. Każda mechanika ma zdanie "jak to przetestujemy headless". `docs/MONETIZATION.md` z placementami. `docs/ASO.md` z 3 wariantami tytułu (sprawdzone w sklepach, że wolne) i 20 keywordami.
  Skill: `game-economy`, `ads-iap`, `aso`.

- [ ] R-003 `todo` Backlog MVP z GDD
  KA: sekcje P1/P2 poniżej wypełnione 15–25 zadaniami wynikającymi z GDD, każde z KA i skillem, w kolejności zależności (core loop → save → UI → meta → monetyzacja). Zadanie podzielone tak, by każde mieściło się w ~300 liniach.
  Skill: `godot-dev`.

- [ ] T-001 `todo` Smoke: środowisko i pętla działają end-to-end
  KA: `make setup && make check` przechodzi lokalnie i w CI (`test.yml` zielone na PR). Dodaj do `game/src/core/version.gd` stałą `BUILD_INFO` i test, który ją czyta. To jest dry-run pętli — ma się zakończyć zmergowanym PR.
  Skill: `godot-test`.

## P1 — core loop i retencja (wypełnia R-003)

## P2 — monetyzacja i meta (wypełnia R-003)

## P3 — polish / later

## Inbox (nieprzeanalizowane — przegląd w cotygodniowym refreshu)

- [ ] T-002 `todo` Wspólne, monotoniczne źródło version_code dla build-android.yml i release.yml (np. epoch-minutes lub licznik w vars); run_number per workflow może cofać numer i Play odrzuci AAB. Skill: godot-build
- [ ] T-003 `todo` Implementacja --screenshot=<scene> --out=<dir> w main.gd (zapis PNG po 1 klatce), żeby tools/gen_screenshots.sh działał. Skill: godot-dev
- [ ] T-004 `todo` Gemfile.lock wygenerowany i zacommitowany (bundle lock --add-platform x86_64-linux arm64-darwin). Skill: store-release
- [ ] G-001 `todo` Balans: make sim pokazuje ~8,6 interstitiali/DAU przy interstitial_every_n_rounds=3 — za dużo vs KPI cel 3,0; zaproponować cap (np. co 5 rund + min 120 s) i potwierdzić symulacją. Skill: game-economy
- [ ] T-005 `todo` Zweryfikować w edytorze Godot 4.7 klucze export_presets.cfg (Android/iOS) i nazwę pliku editor settings + klucz android_sdk_path użyty w workflowach; poprawić jeśli się różnią. Skill: godot-build
- [ ] T-006 `todo` Postawić pierwszy tag v0.1.0 (git describe w prompcie biweekly-release wymaga istniejącego taga). Skill: store-release
- [ ] T-007 `todo` Sprawdzić czy deny Edit(fastlane/Fastfile) itd. w .claude/settings.json działa jak zamierzono (metadata edytowalne, lanes nie); patrz ZWERYFIKUJ w docs/AUTOMATION.md. Skill: godot-test
- [ ] T-011 `todo` CI: podbić wersje akcji w .github/workflows (checkout v7, setup-python v6, cache v6, upload-artifact v7, google-github-actions/auth v3) i Gemfile; `make check` + actionlint. Skill: godot-build

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
