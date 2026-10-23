# Automatyzacja: pętla pracy

Jak działa autonomiczna pętla, co ją uruchamia, czym jest ograniczona i jak ją zatrzymać. Zasady pracy pojedynczej sesji są w `CLAUDE.md`; ten plik opisuje całość z lotu ptaka.

## 1. Diagram pętli

```
   Scheduled tasks (Claude Code Remote)
   ┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │ nightly-dev  │  │ weekly-analytics │  │ biweekly-release │
   │ codziennie 2 │  │ niedziela 20:00  │  │ wtorek 9:00      │
   └──────┬───────┘  └────────┬─────────┘  └────────┬─────────┘
          │ orkiestrator (opus/fable) planuje, deleguje, sprawdza
          │ subagenci: gameplay-dev · qa-playtester · game-designer
          │            monetization-analyst · release-manager · asset-worker
          ▼                   ▼                      ▼
     branch task/<ID>   PR "weekly backlog      tag v<semver>
     + make check       refresh"                     │
          │                   │                      ▼
          └────────┬──────────┘            release.yml (GitHub Actions)
                   ▼                       prepare → changelog → android + ios
          PR (label `bot`) ──► CI: test.yml        │
          auto-merge (squash) po zielonym CI       ▼
                   │                      Play internal + TestFlight
                   ▼                               │
                main ◄─────────────────────  environment `production`
                   │                         (RĘCZNA zgoda Huberta)
                   │                               ▼
                   │                      sklepy: Play 10 % rollout, App Review
                   │                               │
                   │                               ▼
                   │                  użytkownicy → GameAnalytics / AdMob / Play
                   │                               │
                   │                    tools/metrics_pull.py (weekly-analytics)
                   │                               ▼
                   └──────────── KPI.md → reguły decyzyjne → BACKLOG.md (P1/P2) ──► nightly-dev
   Straż: nightly-sanity.yml (03:30 UTC) → issue `bot`+`P0` → backlog-sync.yml → BACKLOG.md ## Inbox
```

## 2. Scheduled tasks

Zakładasz je w Claude Code Remote (środowisko = to repo). Prompty wklej dosłownie. W ustawieniach każdego zadania włącz powiadomienia e-mail (są podstawą procedury z pkt 7).

| # | Nazwa | Cron | Co robi |
|---|---|---|---|
| 1 | `nightly-dev` | `CRON_TZ=Europe/Warsaw 0 2 * * *` | jedno zadanie z BACKLOG.md → PR z auto-merge |
| 2 | `weekly-analytics` | `CRON_TZ=Europe/Warsaw 0 20 * * 0` | metryki → reguły → odświeżony backlog → PR |
| 3 | `biweekly-release` | `CRON_TZ=Europe/Warsaw 0 9 * * 2` | co wtorek sprawdza; wydaje tylko gdy od ostatniego taga minęło >= 13 dni |

### Task 1: `nightly-dev`
Cron: `CRON_TZ=Europe/Warsaw 0 2 * * *`

```
Jesteś orkiestratorem w repo first-auto-game. Przeczytaj CLAUDE.md w całości i postępuj dokładnie według sekcji 'Pętla pracy' i 'Routing modelu'. Sam nie piszesz kodu — delegujesz do subagentów z .claude/agents/ (gameplay-dev na sonnet lub haiku, qa-playtester na sonnet), a sam planujesz, specyfikujesz i sprawdzasz. Zrealizuj JEDNO zadanie z BACKLOG.md. Jeśli istnieje otwarty PR z gałęzi task/* z czerwonym CI, NAJPIERW go napraw. Na koniec: status w BACKLOG.md, wpis w docs/LOG.md, PR z auto-merge. Nie zadawaj pytań — decyzje produktowe zapisuj w sekcji 'Pytania do Huberta' i bierz następne zadanie.
```

### Task 2: `weekly-analytics`
Cron: `CRON_TZ=Europe/Warsaw 0 20 * * 0`

```
Jesteś orkiestratorem w repo first-auto-game. Przeczytaj CLAUDE.md i KPI.md. Uruchom subagenta monetization-analyst: ma wykonać skill .claude/skills/analytics-review/SKILL.md — pobrać metryki (python3 tools/metrics_pull.py; przed wydaniem gry użyj --dry-run i zaznacz to w KPI.md), zastosować reguły decyzyjne z KPI.md, przepisać sekcje P1/P2 w BACKLOG.md (max 10 zadań, każde z mierzalnym KA), przenieść wpisy z Inbox do właściwych sekcji lub do P3, i dopisać 1 eksperyment do docs/EXPERIMENTS.md. Sprawdź jego wynik, otwórz PR 'chore: weekly backlog refresh' z auto-merge. Jeśli KPI.md zawiera przez 2 tygodnie z rzędu wartości poniżej kill-line, utwórz docs/PIVOT_OR_KILL.md i zadanie blocked z pytaniem do Huberta.
```

### Task 3: `biweekly-release`
Cron: `CRON_TZ=Europe/Warsaw 0 9 * * 2` (co wtorek; wydanie tylko gdy od ostatniego taga minęło >= 13 dni, co wymusza sam prompt, czyli efektywnie co 2 tygodnie)

```
Jesteś orkiestratorem w repo first-auto-game. Jeśli docs/STATUS.md wskazuje fazę < 4, zakończ bez działania. Sprawdź `git describe --tags`: jeśli ostatni tag v* jest młodszy niż 13 dni, zakończ. W przeciwnym razie uruchom subagenta release-manager: przejść docs/RELEASE_CHECKLIST.md, zaktualizować changelog i fastlane/metadata, i jeśli WSZYSTKIE punkty checklisty są spełnione — utworzyć tag v<semver> (patch bump) i push tagu. Jeśli coś nie jest spełnione — nie taguj; dopisz brakujące punkty jako zadania P0 do BACKLOG.md i otwórz PR. Promocja do produkcji i tak wymaga ręcznego zatwierdzenia w GitHub Environment production.
```

Uwagi do promptów:
- Przed pierwszym tagiem `git describe --tags` kończy się błędem (brak tagów). Faza < 4 i tak zatrzymuje task; przy pierwszym wydaniu zrób tag ręcznie lub z sesji interaktywnej.
- Task 1 przy domyślnym stanie repo (GDD w statusie `DRAFT`) bierze tylko zadania z `## P0 — fundamenty`.

## 3. Koszty i limity

- **1 task na noc** (`nightly-dev`), jedno zadanie backlogu na przebieg. Zadanie większe niż limit się dzieli (wpis do backlogu), nie rozciąga.
- **<= 300 zmienionych linii kodu na PR** (bez assetów i lock-files). Szablon PR (`.github/PULL_REQUEST_TEMPLATE.md`) ma tę pozycję na checkliście.
- **Auto-merge tylko dla PR z labelem `bot`** (`gh pr create --fill --label bot`, potem `gh pr merge --auto --squash`). PR bez labela (Twoje własne) scalasz ręcznie. Auto-merge zadziała tylko, gdy w repo jest włączone "Allow auto-merge" i wymagane checki w branch protection (pkt 4).
- Routing modelu obniża koszt: orkiestrator (opus/fable) tylko planuje i sprawdza; implementacja idzie do `sonnet`, a trywialne, mechaniczne prace (<50 linii) do `haiku` (ADR-006).
- Poziom wydatków: brak twardego limitu w repo. Pilnuj zużycia w ustawieniach konta; jeśli rośnie, najpierw zmniejsz częstotliwość `nightly-dev` (np. `0 2 * * 1-5`).
- `make check` w hooku `pre_push.sh` dubluje CI przed pushem. To celowy koszt czasu (kilka minut), a nie tokenów.

## 4. Bezpieczniki

| Bezpiecznik | Gdzie | Co robi |
|---|---|---|
| Branch protection na `main` | GitHub → Settings → Branches | wymagane: PR, zielony check `test`, brak force-push; bez tego `--auto` scali czerwony PR |
| Environment `production` | GitHub → Settings → Environments | required reviewer = Hubert; job `promote` w `release.yml` czeka na zgodę |
| Deny-lista w `.claude/settings.json` | repo | blokuje edycję `.github/workflows/**`, `.claude/**`, plików lane fastlane (`Fastfile`, `Appfile`, `Matchfile`, `Pluginfile`), odczyt kluczy (`*.jks`, `*.p8`, `*.keystore`, `*.p12`, `*service-account*.json`), `git push --force*`, `rm -rf *` |
| Hooki (`.claude/hooks/`) | repo | `pre_push.sh`: `make check` przed każdym `git push` (exit 2 = blokada); `post_edit_gd.sh`: gdformat po edycji `*.gd`; `on_stop.sh`: nie pozwala skończyć sesji z gałęzią `task/*` bez PR lub zadaniem `in_progress` bez `→ PR` (max 2 blokady na sesję) |
| `nightly-sanity.yml` | GitHub Actions, 03:30 UTC | codzienny smoke; przy porażce tworzy issue z labelami `bot` + `P0`, `backlog-sync.yml` wpisuje je do `## Inbox` w BACKLOG.md |
| Sekrety | GitHub Secrets | placeholdery `__ENV__` w `export_presets.cfg`, wstrzykiwane przez `tools/inject_secrets.sh`; `tools/validate_presets.py` w `make export-check` wykrywa prawdziwe sekrety |
| `release.yml` | GitHub Actions | wersja tylko z taga; nic nie trafia na produkcję bez approve |

### Dlaczego deny na workflowy i `.claude/`
Deny na `.github/workflows/**`, `.claude/**` i pliki lane fastlane dotyczy **pętli nocnej** (agentów). Pętla nie może sama rozszerzyć swoich uprawnień ani zmienić pipeline'u wydań. Takie zmiany robisz **ręcznie albo z sesji interaktywnej** (Ty przy komputerze), po zadaniu w backlogu, które tego wprost dotyczy (CLAUDE.md, twarde zasady).

Odstępstwo od pierwotnego założenia: zamiast `Edit(fastlane/**)` blokowane są tylko 4 pliki lane. Powód: `release-manager`, `asset-worker` i skill `aso` muszą edytować `fastlane/metadata/**` (tytuły, opisy, changelogi, lokalizacje), a reguły `Edit` obejmują też narzędzie `Write`. Dlatego deny wyliczono plik po pliku (ZWERYFIKUJ przed użyciem: https://code.claude.com/docs/en/permissions, czy deny w stylu gitignore da się zawęzić wyjątkiem). Jeśli wolisz pełną blokadę `fastlane/**`, zmiany metadata muszą wtedy robić sesje interaktywne.

### Ograniczenia deny-listy (bądź świadomy)
- To reguły dla narzędzi Claude Code, nie piaskownica. `Bash(python3 *)` i `Bash(bash tools/*)` technicznie mogą zapisać cokolwiek; `Bash(rm -rf *)` nie złapie `rm -fr`. Ostateczną obroną są: branch protection, wymagane review ścieżek wrażliwych (zalecany `CODEOWNERS` dla `.github/`, `fastlane/`, `.claude/`) i `production` environment.
- Hook `post_edit_gd.sh` zmienia plik po edycji. Jeśli następna edycja zgłosi, że plik się zmienił, agent musi go przeczytać ponownie. To zachowanie normalne.
- Pole `if` w hooku `pre_push.sh` filtruje wywołania do `git push`; skrypt sam też sprawdza komendę, więc działa nawet bez filtra. Hook nie ma obejścia (żadnej zmiennej "pomiń"), bo agent mógłby ją ustawić.

## 5. Uruchomienie lokalnie na Macu

Pętla działa tak samo lokalnie jak w scheduled task: te same pliki, ten sam prompt.

```bash
cd ~/path/first-auto-game
make setup                 # raz: Godot headless, export templates, gdUnit4, gdtoolkit
claude                     # sesja interaktywna; wklej prompt Task 1 (lub 2, lub 3)
# albo jednorazowo, bez interakcji:
claude -p "$(cat prompt-nightly.txt)"   # prompt zapisz do pliku z sekcji 2
```
Wymagane: `gh auth status` zalogowany, `jq` lub `python3` (hooki), `make`, `bundle` tylko dla fastlane. Lokalnie `.claude/settings.json` obowiązuje tak samo (hooki i deny). Nie używaj `--dangerously-skip-permissions`: wyłącza barierę deny-listy.
Test hooków na sucho: `echo '{"tool_input":{"command":"git push origin x"}}' | .claude/hooks/pre_push.sh; echo $?` (0 = przepuszczone, 2 = zablokowane).

## 6. Jak zatrzymać pętlę

1. **Normalnie:** wyłącz (lub usuń) scheduled task na liście zadań w Claude Code Remote. Trwający przebieg dokończy się albo sam wygaśnie. Zacznij od `nightly-dev`; analityka i release są mało kosztowne.
2. **Awaryjnie, gdy do `main` coś trafia nie tak:** `gh repo edit --enable-auto-merge=false` (nic już nie scali się samo), a w branch protection wymagaj review. Zamknij otwarte PR z labelem `bot`: `gh pr list --label bot --json number --jq '.[].number' | xargs -n1 gh pr close`.
3. **Wydania:** nie zatwierdzaj `production`. Samego taga nie da się cofnąć bezpiecznie po starcie `release.yml`; anuluj workflow: `gh run cancel <id>`.
4. **Sekrety:** w razie podejrzenia wycieku unieważnij je u źródła (Play service account, klucz ASC, keystore) i wyczyść GitHub Secrets.

## 7. Procedura: "pętla się zapętliła"

Definicja: 3 noce z rzędu czerwone, czyli `nightly-dev` nie doprowadził do zmergowanego PR (CI czerwone, PR wisi, sesja padła albo zrobiła zero) lub trzy ostatnie wpisy w `docs/LOG.md` mają wynik FAIL. Sygnał: e-mail z notyfikacji scheduled task (pkt 2) i/lub issue `P0` z `nightly-sanity`.

1. Wyłącz `nightly-dev` (pkt 6.1), żeby nie dokładać szumu.
2. Zbierz fakty:
   ```bash
   gh run list --workflow=test.yml --limit 10
   gh pr list --state open --label bot --json number,headRefName,statusCheckRollup
   gh run view <id> --log-failed | tail -120
   tail -40 docs/LOG.md
   ```
3. Zaklasyfikuj przyczynę: (a) środowisko (pobranie Godota, templates, sieć → `make setup`, cache), (b) test czerwony na `main`, (c) to samo zadanie zawodzi za każdym razem, (d) konflikt/spór z hookiem lub deny-listą, (e) limit konta/modelu.
4. Zadanie, które się zapętla: w `BACKLOG.md` ustaw status `blocked` i dopisz pytanie w `## Pytania do Huberta` (co próbowano, link do runa, hipoteza). Pętla weźmie następne zadanie.
5. Naprawy pipeline'u (workflow, fastlane, `.claude/`) rób ręcznie, bo agent ich nie dotknie.
6. Uruchom jeden przebieg ręcznie (`claude` + prompt Task 1) i obserwuj. Dopiero po zmergowanym PR włącz scheduled task z powrotem.
7. Dopisz wnioski do `docs/LOG.md` (jeden wpis: przyczyna, naprawa, data).

## 8. Struktura `.claude/`

| Plik | Rola |
|---|---|
| `.claude/settings.json` | uprawnienia (allow/deny) i hooki; bez ustawionego `model` (wybiera orkiestrator) |
| `.claude/hooks/pre_push.sh` | PreToolUse na `git push` → `make check` |
| `.claude/hooks/post_edit_gd.sh` | PostToolUse na Edit/Write → gdformat dla `*.gd` (poza `addons/`) |
| `.claude/hooks/on_stop.sh` | Stop → blokada, gdy praca niedokończona (licznik w `$TMPDIR`/`/tmp`, max 2) |
| `.claude/agents/*.md` | 6 subagentów: `game-designer`, `gameplay-dev`, `qa-playtester`, `monetization-analyst`, `release-manager`, `asset-worker` |
| `.claude/skills/*/SKILL.md` | 9 skilli (mapowanie zadanie → skill w CLAUDE.md) |

Schemat hooków (zgodny z dokumentacją Claude Code): `hooks.<Zdarzenie>[] = { matcher, hooks: [{ type: "command", command, timeout (sekundy), if }] }`. Blokada: exit 2 + komunikat na stderr (PreToolUse) albo JSON `{"decision":"block","reason":"..."}` na stdout z exit 0 (Stop). Stop ma własne zabezpieczenie: pole `stop_hook_active` w wejściu oraz limit kolejnych kontynuacji po stronie Claude Code (domyślnie 8); nasz licznik ogranicza blokady do 2.
Źródła: https://code.claude.com/docs/en/hooks, https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/skills, https://code.claude.com/docs/en/permissions.
