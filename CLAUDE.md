# first-auto-game — zasady dla każdej sesji Claude

Gra mobilna (Android + iOS) w **Godot 4.7.2 / GDScript**, monetyzowana rewarded ads + IAP.
Repo jest prowadzone przez autonomiczną pętlę Claude (scheduled tasks). Każda sesja
startuje bez pamięci — ten plik, `BACKLOG.md`, `KPI.md` i `docs/` są jedynym źródłem prawdy.

## Metryka nadrzędna
Patrz `KPI.md`. Skrót: D1 retention ≥ 35 %, D7 ≥ 12 %, ARPDAU ≥ 0,05 USD, crash-free ≥ 99,5 %.

## Stan projektu
- Faza: patrz `docs/STATUS.md` (sekcja "Aktualna faza"). Nie przeskakuj faz.
- Jeśli `docs/GDD.md` ma status `DRAFT` → jedyne dozwolone zadania to z sekcji `## P0 — fundamenty` w BACKLOG.md.

## Pętla pracy (obowiązkowa kolejność, bez skrótów)
1. `cat BACKLOG.md`. Jeśli jakikolwiek otwarty PR z gałęzi `task/*` ma czerwone CI
   (`gh pr list --state open --json number,headRefName,statusCheckRollup`) — NAJPIERW go napraw.
2. W przeciwnym razie weź PIERWSZE zadanie ze statusem `todo` z sekcji o najwyższym
   priorytecie (P0 > P1 > P2). Pomiń `blocked`.
3. Przeczytaj `docs/GDD.md`, `docs/DECISIONS.md` i skill z `.claude/skills/` właściwy dla zadania
   (mapowanie w sekcji "Skille" niżej). Dopiero potem dotykaj kodu.
4. `git checkout -b task/<ID>` z aktualnego `main`. Zmień status zadania na `in_progress`,
   commit `chore(<ID>): start`.
5. Implementuj. Jeden task = jeden PR = max ~300 zmienionych linii kodu (bez assetów/lock-files).
   Większe zadanie → podziel: dopisz kolejne zadania do BACKLOG.md, zrób tylko pierwszy kawałek.
6. `make check` MUSI być zielone (testy gdUnit4 + lint + dry-run exportu). Nigdy nie wyłączaj,
   nie pomijaj i nie osłabiaj testów, żeby przeszły.
7. Każda nowa mechanika → test jednostkowy + aktualizacja `docs/GDD.md`.
   Każdy nowy ekran → wpis w `tools/gen_screenshots.sh`.
   Każda decyzja architektoniczna → ADR w `docs/DECISIONS.md`.
8. `gh pr create --fill --label bot` z opisem: co / dlaczego / jak przetestowano / ryzyka.
   `gh pr merge --auto --squash`.
9. Zmień status zadania na `review`, dopisz `→ PR #N`. Dopisz 2–3 linie do `docs/LOG.md` z datą.
10. Nowe pomysły/bugi odkryte po drodze → `## Inbox` w BACKLOG.md. NIE realizuj ich teraz.
11. Pytanie wymagające decyzji produktowej/biznesowej → `## Pytania do Huberta`, task → `blocked`,
    weź następny. Nigdy nie czekaj na odpowiedź w sesji.

## Twarde zasady (naruszenie = sesja nieudana)
- Zero sekretów w repo: keystore, .p8, service account JSON, klucze AdMob/GA. Placeholdery
  `__ENV_NAME__` w `export_presets.cfg` wstrzykuje CI (`tools/inject_secrets.sh`).
- Nie edytuj `.github/workflows/*`, `fastlane/*`, `export_presets.cfg` ani `.claude/*`
  bez zadania w backlogu, które tego wprost dotyczy.
- Nie podbijaj wersji ręcznie — `release.yml` ustawia `version/name` i `version/code`.
- Grafika i audio: tylko własne (generowane w `tools/gen_assets.py`) lub CC0 z listy w
  `.claude/skills/asset-gen/`. Każdy obcy asset → wpis w `docs/LICENSES.md`.
- Nie dodawaj zależności (addony, pluginy) poza listą w `docs/DECISIONS.md` bez ADR.
- Nie zmieniaj `game/project.godot` poza sekcjami `[autoload]`, `[input]`, `[display]`.
- Sceny `.tscn` edytuj tekstowo ostrożnie: nie zmieniaj istniejących `uid://`, nie usuwaj
  `[ext_resource]`, nowym zasobom nadawaj unikalne id. Po edycji zawsze `make test`.
- Nie uruchamiaj `git push --force`, nie usuwaj gałęzi innych niż własna `task/*`.
- Nie commituj do `main` bezpośrednio.

## Komendy
| Komenda | Co robi |
|---|---|
| `make setup` | pobiera Godot headless + export templates + addony (idempotentne) |
| `make test` | gdUnit4 headless, wynik w `game/test/reports/` |
| `make lint` | gdlint + gdformat --check |
| `make playtest` | bot gra N tur headless, raport JSON (`game/test/reports/playtest.json`) |
| `make sim` | symulacja ekonomii offline (`tools/balance_sim.py`) |
| `make export-check` | dry-run exportu Android do scratch, bez podpisu |
| `make check` | lint + test + export-check (bramka przed PR) |
| `make screenshots` | screenshoty headless do `fastlane/metadata/` |

## Skille (które czytać przy jakim zadaniu)
| Zadanie dotyczy | Skill |
|---|---|
| Kod gry, sceny, GDScript | `.claude/skills/godot-dev/SKILL.md` |
| Testy, bot, CI czerwone | `.claude/skills/godot-test/SKILL.md` |
| Export, build, Android/iOS | `.claude/skills/godot-build/SKILL.md` |
| Balans, ekonomia, progresja | `.claude/skills/game-economy/SKILL.md` |
| Reklamy, IAP, consent | `.claude/skills/ads-iap/SKILL.md` |
| Wydanie, metadata, review | `.claude/skills/store-release/SKILL.md` |
| Tytuł, opis, keywordy, screenshoty | `.claude/skills/aso/SKILL.md` |
| Metryki, backlog tygodniowy | `.claude/skills/analytics-review/SKILL.md` |
| Grafika, dźwięk, ikony | `.claude/skills/asset-gen/SKILL.md` |

## Routing modelu (zasada kosztowa — obowiązkowa)
Sesja główna (orkiestrator, Fable/Opus) **nie pisze kodu ani plików sama**. Robi wyłącznie:
wybór zadania, dekompozycję, specyfikację dla subagenta, przegląd wyniku, decyzje architektoniczne,
analizę metryk i planowanie backlogu. Całą resztę deleguje do subagentów z `.claude/agents/`:

| Rodzaj pracy | Agent | Model |
|---|---|---|
| Implementacja wg jasnej specyfikacji, testy, refaktor, assety, metadata, tłumaczenia, LOG | `gameplay-dev`, `asset-worker`, `release-manager` | **haiku** (trywialne, <50 linii, mechaniczne) lub **sonnet** (reszta) |
| Playtest, raport QA, analiza czerwonego CI | `qa-playtester` | sonnet |
| GDD, zmiany mechanik, balans, research rynku, ADR | `game-designer` | opus/fable (ten sam model co orkiestrator) |
| Interpretacja metryk, przepisanie backlogu, eksperymenty | `monetization-analyst` | opus/fable |

Reguła kciuka: jeśli zadanie da się opisać w 10 linijkach tak, że junior je zrobi bez pytań → haiku.
Jeśli wymaga dotknięcia >3 plików albo zrozumienia istniejącej architektury → sonnet.
Jeśli wymaga wyboru *co* zbudować, a nie *jak* → orkiestrator / opus-tier agent.
Orkiestrator zawsze podaje subagentowi: pliki do dotknięcia, KA z backlogu, komendę weryfikującą
(`make test` / `make check`) i żąda w odpowiedzi: listy zmienionych plików + wyniku komendy.
Wynik subagenta orkiestrator sprawdza (czyta diff, uruchamia `make check` sam) — nie ufa na słowo.

## Agenci (`.claude/agents/`)
`game-designer`, `gameplay-dev`, `qa-playtester`, `monetization-analyst`, `release-manager`, `asset-worker`.
Przed otwarciem PR dla zadania P0/P1 uruchom `qa-playtester` na gałęzi — jego raport wklej do opisu PR.

## Styl kodu
- GDScript: typowane zmienne i sygnatury (`var x: int`, `func f(a: float) -> void`), `snake_case`,
  klasy `PascalCase` z `class_name`, sygnały zamiast bezpośrednich referencji między systemami.
- Logika gry (ekonomia, generator, reguły) w czystych klasach bez `Node` — testowalne bez sceny.
- Brak magicznych liczb: wszystkie parametry balansu w `game/src/systems/config.gd` (`GameConfig`),
  nadpisywalne przez remote config.
- Commity: Conventional Commits (`feat(<ID>): …`, `fix(<ID>): …`, `chore(<ID>): …`).
