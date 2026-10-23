# Decyzje architektoniczne (ADR)

Format: `ADR-NNN: tytuł` · Data · Status · Kontekst · Decyzja · Konsekwencje.
Zaakceptowanego ADR nie edytujemy. Zmiana decyzji = nowy ADR, który zastępuje stary.

---

## ADR-001: Silnik: Godot 4

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Pętla autonomiczna musi budować, testować i eksportować grę z CLI, bez GUI. Scena powinna być plikiem tekstowym, żeby diff w PR był czytelny. Licencja nie może obciążać przychodu.

**Decyzja:** Godot 4.3+ z GDScript. Testy i playtesty w trybie `--headless`. Sceny `.tscn` w formacie tekstowym. Export CLI na Android (AAB) i iOS.

Alternatywy odrzucone:
- Unity: model licencyjny z niepewnością (runtime fee 2023 i późniejsze zmiany), workflow edytor-centryczny, headless możliwy, ale nienaturalny.
- Unreal: zbyt ciężki dla małej gry mobilnej, koszt utrzymania builda i C++/Blueprint.
- Flutter + Flame: dobre do 2D, ale brak edytora scen i słabszy pipeline headless dla gier.

**Konsekwencje:**
- Testy i export muszą działać bez GUI. Wersja Godot jest przypięta w `make setup`.
- Mniejszy ekosystem pluginów niż w Unity. Stąd ADR-007.

---

## ADR-002: Testy: gdUnit4

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Każda mechanika wymaga testu jednostkowego, a testy scen muszą działać w CI bez ekranu.

**Decyzja:** gdUnit4 uruchamiany przez `make test` w trybie headless. Raport XML/JSON trafia do `game/test/reports/`. Workflow `test.yml` czyta raport i blokuje merge przy czerwonym wyniku.

**Konsekwencje:**
- Każda nowa mechanika ma test (CLAUDE.md, pkt 7).
- Testów nie wyłącza się, nie pomija i nie osłabia, żeby przeszły.
- gdUnit4 jest jedyną dozwoloną biblioteką testową (ADR-007).

---

## ADR-003: Reklamy: AdMob przez plugin godot-admob-plugin

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Model monetyzacji to rewarded ads + IAP. Potrzebujemy wymienialnego SDK reklam i możliwości testów bez sieci.

**Decyzja:**
- AdMob przez plugin `poing-studios/godot-admob-plugin`.
- Cała logika gry komunikuje się z reklamami wyłącznie przez interfejs `AdProvider` (rewarded, interstitial, consent).
- Implementacja `FakeAdProvider` do testów i do `make playtest`.

**Konsekwencje:**
- Zmiana SDK nie dotyka logiki gry.
- Wsparcie UMP i ATT w pluginie trzeba zweryfikować w R-002 / Fazie 5. Jeśli plugin go nie ma, obsługa zgody idzie przez `AdProvider`.
- Ad unit ID idą z sekretów `ADMOB_*` (`docs/SETUP_HUBERT.md`), nigdy nie są w repo.

---

## ADR-004: Analityka: GameAnalytics + Firebase Remote Config (Faza 6)

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Potrzebujemy darmowej analityki z oficjalnym SDK dla Godot oraz mechanizmu A/B dla hipotez z `docs/MONETIZATION.md`.

**Decyzja:**
- GameAnalytics (oficjalny SDK Godot, darmowy) do eventów z `docs/GDD.md` → Analityka.
- Firebase Remote Config wyłącznie do testów A/B, dopiero w Fazie 6.
- Do Fazy 6 wartości żyją w `GameConfig`.

**Konsekwencje:**
- Sekrety `GA_GAME_KEY` i `GA_SECRET_KEY` (`docs/SETUP_HUBERT.md`).
- Zmiana listy eventów wymaga aktualizacji Data Safety i Privacy Nutrition Labels (`docs/RELEASE_CHECKLIST.md`).
- Firebase Test Lab (crash-free) to osobne narzędzie i nie oznacza zależności od Firebase SDK w grze.

---

## ADR-005: Wydania: GitHub Actions + fastlane

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Build i publikacja muszą działać z CI, bez ręcznego wgrywania plików do sklepów. Produkcja wymaga kontroli człowieka.

**Decyzja:**
- GitHub Actions + fastlane: `supply` dla Google Play, `pilot` dla TestFlight.
- Build iOS na runnerze macOS.
- Promocja do produkcji wymaga ręcznego approve w GitHub Environment `production` (required reviewer: Hubert).
- Wersja podbijana przez `release.yml`, nie ręcznie.

**Konsekwencje:**
- Sekrety w GitHub Secrets (`docs/SETUP_HUBERT.md`).
- Na Play start od staged rollout 10 %.
- Nic nie trafia na produkcję bez approve.

---

## ADR-006: Routing modelu: orkiestrator planuje, subagenci implementują

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Koszt sesji rośnie, gdy model najwyższej klasy pisze kod i pliki. Pętla ma wiele mechanicznych zadań.

**Decyzja:** Zgodnie z sekcją „Routing modelu" w CLAUDE.md:
- Orkiestrator (Fable / Opus) wybiera zadanie, dekomponuje je, pisze specyfikację, przegląda wynik. Nie pisze kodu ani plików sam.
- Implementacja: `haiku` (trywialne, <50 linii) lub `sonnet` (reszta, >3 pliki lub zrozumienie architektury).
- Projekt mechanik i balans: `game-designer`, `monetization-analyst` (opus / fable).

**Konsekwencje:**
- Orkiestrator sprawdza diff i uruchamia `make check` sam. Nie ufa raportowi subagenta na słowo.

---

## ADR-007: Dozwolone zależności

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Każdy addon to kod zewnętrzny, obciążenie licencyjne i ryzyko w buildzie. Pętla autonomiczna nie może dorzucać zależności sama.

**Decyzja:** Dozwolona lista:
- gdUnit4
- godot-admob-plugin
- gameanalytics-godot
- GodotFirebase (opcjonalnie, Faza 6)

Wszystko inne wymaga nowego ADR przed dodaniem do repo.

**Konsekwencje:**
- PR dodający addon bez ADR jest odrzucany w review (CLAUDE.md, twarde zasady).
- Nowe assety obce podlegają `docs/LICENSES.md`, osobno od tej listy.

---

## ADR-008: Wersja Godot 4.7.2

**Data:** 2026-10-23
**Status:** Accepted (rozszerza ADR-001, ADR-002 i ADR-007; nie zmienia ich treści)

**Kontekst:**
- `godot-admob-plugin` (poing-studios) i `gameanalytics-godot` wymagają Godot >= 4.5 (ADR-003, ADR-004).
- Google Play wymaga od 31.08.2026 target API 36; Godot 4.7.2 ma domyślnie `targetSdk=36`, `compileSdk=36`.
- gdUnit4 master (v7) wymaga Godot >= 4.7; wersje v5.x/v6.x nie obejmują 4.7.

**Decyzja:** Projekt jest przypięty do Godot 4.7.2-stable. Jedyne źródło wersji to `GODOT_VERSION` w `Makefile` (przekazywana do `tools/setup_env.sh`). gdUnit4: `GDUNIT_REF=master` (v7.0.0), bo tagów v7.x jeszcze nie ma — po wydaniu przypiąć najwyższy tag v7.x. Android: target SDK 36, min SDK 24, Build-Tools 36.1.0, Platform 36, NDK 29.0.14206865, CMake 3.10.2.4988404, JDK 17 (wg źródeł Godota 4.7.2; strona docs 4.7 podaje starsze 35.0.1/35/r28b).

**Konsekwencje:**
- gdUnit4 v7; testy i `make check` działają bez zmian w kodzie gry.
- Workflowy używają `editor_settings-4.7.tres`; zmiana wersji minor wymaga zmiany nazwy pliku (T-005).
- Pluginy reklam i analityki są odblokowane (Faza 5/6).
- Przy wydaniu taga gdUnit4 v7.x zamienić `master` na tag (powtarzalność builda).

