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

## 2026-10-23 — sesja continuous-dev #3 (20:11 UTC – w trakcie)

- P1: T-019 scena Level + BoardView/TubeView (motyw z themes.json, tap/przelew/shake, sygnał `pour_finished`, klucze `pour_anim_seconds`/`tube_lift_seconds`/`shake_seconds`), 132 testy, QA PASS (3 seedy 200/200) → PR #26 (auto-merge).
- P1: T-020 HUD + LevelComplete + przepływ poziomów/zapis/streak (137 testów, QA PASS) → PR #27 (auto-merge). #26 zmergowany w trakcie sesji.
- P1: T-021 StuckPanel + Boosters (czysta klasa) + hint/+probówka w HUD + pomiń po restartach, 145 testów, QA: KA OK (uwaga o GDD — mechaniki już opisane) → PR #28 (auto-merge). #27 zmergowany.
- P1: G-005 FTUE TutorialFlow (maszyna stanów) + overlay z dłonią + ukrycie boosterów w tutorialu, 150 testów, QA PASS → PR #29 (auto-merge). #28 zmergowany.
- Inbox: T-035 pełna animacja przelewu, T-039 sygnał tube_deselected, T-038 testy shop_requested, T-036 szum FNV w logu testów, T-037 test wygranej bez „idealnie" + bezpieczeństwo tweenów. G-007 oznaczone `done` (#25 zmergowany).
