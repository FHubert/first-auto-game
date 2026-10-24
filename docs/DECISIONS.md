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
- GodotGooglePlayBilling (Android IAP) (ADR-010)
- godot_ios_plugin_iap (iOS IAP, StoreKit) (ADR-010)

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

---

## ADR-009: Format poziomu i deterministyczny generator per seed (sort puzzle)

**Data:** 2026-10-23
**Status:** Accepted

**Kontekst:** Gatunek to water sort (R-001, `docs/GDD.md` v1.0). Poziom kampanii N i Poziom dnia muszą być identyczne dla wszystkich graczy, na Androidzie i iOS, w każdej wersji gry (wsparcie, wspólny Poziom dnia, testy „golden"). Content nie jest zapisywany w repo — powstaje z seeda w runtime i jest weryfikowany solverem w `make test`.

**Decyzja:**
- Poziom = `Dictionary` z kontraktem `ContentGenerator.generate(seed_value, level)`: `seed`, `level`, `difficulty`, `payload`; `payload` = `capacity`, `colors`, `tubes` (`Array` tablic `int` 0..n-1, dół→góra), `min_moves`, `min_moves_exact`, `attempt`, `solution` (lista ruchów `Vector2i(from, to)`). JSON-owalny (do zapisu w trakcie poziomu, later).
- Seed kampanii: `hash([campaign_seed, level])`; seed Poziomu dnia: funkcja dnia UTC (`floor(unix / 86400)`) i `daily_seed_salt` z `GameConfig`. Kolejne próby: `seed + attempt`.
- Losowość wyłącznie przez `RandomNumberGenerator` z jawnym `seed` i tylko metody całkowitoliczbowe (`randi()`, modulo); zakaz `randf()`, globalnego `randi()` i iteracji po `Dictionary` w kolejności zależnej od hasha przy generacji.
- Logika w czystych klasach `RefCounted` (`SortBoard`, `SortSolver`, `ContentGenerator`); solver A* z limitem `solver_max_states`, fallback ważony A*.
- Test „golden" w `make test`: hash `tubes` dla stałych poziomów zapisany w teście. Zmiana generatora zmieniająca poziomy graczy = świadoma decyzja (nowy ADR lub wpis w PR + aktualizacja golden).

**Konsekwencje:**
- Podbicie wersji Godota (ADR-008) może zmienić `hash()`/RNG → golden test to wykryje; wtedy własny hash (np. FNV-1a w GDScript) zamiast wbudowanego `hash()`.
- Zmiana kluczy generatora w remote config zmienia poziomy dla wszystkich — dopuszczalne tylko przed soft launchem albo w A/B od Fazy 6.
- Czas generacji w runtime ograniczony limitem stanów; jeśli test wydajności (≤ 500 ms/poziom) nie przejdzie, alternatywa to paczka poziomów generowana tym samym kodem w buildzie (nowy ADR).

---

## ADR-010: IAP: GodotGooglePlayBilling (Android) + godot_ios_plugin_iap (iOS), za `IapProvider`

**Data:** 2026-10-23
**Status:** Accepted (rozszerza ADR-007 o dwa pluginy; nie zmienia ADR-003)

**Kontekst:**
- Produkty MVP (`docs/MONETIZATION.md`): `remove_ads`, `starter_pack` (non-consumable), `coins_small`, `coins_large` (consumable). ADR-007 nie obejmował pluginów IAP.
- Google Play: od 31.08.2026 nowe aplikacje i aktualizacje muszą używać Billing Library 8+; przedłużenie można wnioskować do 1.11.2026 (BL 7 wycofana tego dnia, BL 8 — 31.08.2027). Źródło: https://developer.android.com/google/play/billing/deprecation-faq (dostęp 2026-10-23). Wydajemy po 1.11.2026 → BL 8+ obowiązkowo, bez przedłużeń.
- `godot-sdk-integrations/godot-google-play-billing`: 3.0.0 = BL 8.0.0 (kompilowany z Godot 4.5, wspiera 4.2+), 3.2.0 = BL 8.3.0 (minSdk 23, compileSdk 36), 3.3.0 („Latest", 27.07.2026) = BL 9.1.0. Źródła: https://github.com/godotengine/godot-google-play-billing/releases, https://store.godotengine.org/asset/godot-foundation/godot-google-play-billing/ (min. Godot 4.2), https://godot-sdk-integrations.github.io/godot-google-play-billing/installation.html (dostęp 2026-10-23). Issue #110 (BL 8) dotyczy tylko gałęzi 1.x (Godot 3).
- iOS: oficjalny `godotengine/godot-ios-plugins` (`InAppStore`, StoreKit 1) „nie jest deprecated, ale nie ma maintainera" (Calinou, 06.01.2026, https://forum.godotengine.org/t/its-official-godot-ios-plugin-obsolete/130507); brak wydań binarnych pod 4.7, migracja na StoreKit 2 (issue #57) niezrobiona. `hrk4649/godot_ios_plugin_iap` v0.4.0 (27.06.2026, MIT, Swift/StoreKit) deklaruje „This release is for Godot 4.7", min. Godot 4.7 (https://store.godotengine.org/asset/hrk4649/godot-ios-plugin-for-in-app-purchase/, dostęp 2026-10-23).

**Decyzja:**
- Android: GodotGooglePlayBilling **3.3.0** (BL 9.1.0), release zip z GitHub/Asset Store do `game/addons/GodotGooglePlayBilling/`. Przypięcie: tag `3.3.0` + SHA-256 zipa w `tools/setup_env.sh` (SHA wpisuje zadanie instalacyjne — ZWERYFIKUJ commit taga). Fallback w razie regresji: 3.2.0 (BL 8.3.0, nadal ≥ 8).
- Wymagania Android: `gradle/use_gradle_build=true` w presecie (zadanie dotykające `export_presets.cfg` wprost), szablon Android build instalowany przez `make setup`, minSdk 24 (ADR-008) ≥ 23 wymaganego przez plugin, compileSdk/targetSdk 36. API: klasa `BillingClient` (`start_connection`, `query_product_details`, `purchase`, `acknowledge_purchase`, `consume_purchase`, `query_purchases`; sygnały `connected`, `query_product_details_response`, `on_purchase_updated`, `query_purchases_response`, …) — patrz `.claude/skills/ads-iap/SKILL.md` §6. Non-consumable → `acknowledge_purchase` (inaczej zwrot po 3 dniach); consumable → `consume_purchase`.
- iOS: `hrk4649/godot_ios_plugin_iap` **v0.4.0** (wydanie dla Godot 4.7), pliki pluginu w `game/ios/plugins/`, włączony w presecie iOS. Przypięcie: tag `v0.4.0` + SHA-256 (ZWERYFIKUJ). Build na runnerze macOS (ADR-005) z Xcode wymaganym przez Godot 4.7.2 (ZWERYFIKUJ wersję Xcode i min. iOS z README pluginu).
- Interfejs w repo: `IapProvider` (RefCounted; `connect_store()`, `query_products(skus)`, `purchase(sku)`, `restore()`, `acknowledge(token)`; sygnały `connected(ok)`, `products_received(products)`, `purchase_updated(sku, state, token)` ze stanami `purchased|pending|failed|canceled`, `restore_finished(skus)`), implementacje `FakeIapProvider` (testy, `make playtest`), `GooglePlayBillingProvider`, `StoreKitProvider`; autoload `Purchases` wybiera providera po `OS.get_name()`/`Engine.has_singleton`, w edytorze i headless zawsze Fake. Logika gry zna tylko `Purchases`.
- Przyznanie nagrody tylko przy stanie PURCHASED (nie PENDING), potem acknowledge/consume/finish; ceny lokalne wyłącznie ze sklepu.
- **Restore purchases** (wymóg Apple App Review Guideline 3.1.1): przycisk „Przywróć zakupy" w Ustawieniach → `Purchases.restore()`; iOS: sync/current entitlements, Android: `query_purchases(INAPP)` przy starcie i powrocie do aplikacji.
- Weryfikacja zakupu w MVP: bez serwera — ufamy sygnałowi Store (+ `signature` z Play). Ryzyko cheatingu (root/jailbreak, podrobione zakupy) zaakceptowane: dotyczy monet i kosmetyki, brak PvP. RTDN, Play Integrity i własny backend poza zakresem (nowy ADR, jeśli przychód z IAP > 20 % lub wykryjemy nadużycia).
- Plan B: `hyodotdev/openiap` → `godot-iap` 4.0.3 (16.10.2026; iOS StoreKit 2, Android BL 8+, jeden API dla obu platform; https://godotengine.org/asset-library/asset/4627) — wymaga nowego ADR; podmiana dotyka tylko providerów.

**Status zgodności z Godot 4.7.2:**
- GodotGooglePlayBilling 3.3.0: **niepotwierdzone** na 4.7.2 (deklarowane 4.2+, plugin v2 AAR; nikt nie publikuje testu na 4.7).
- godot_ios_plugin_iap v0.4.0: **niepotwierdzone** na 4.7.2 (deklarowane „for Godot 4.7"; zgodność 4.7.x zakładana, iOS plugin linkuje nagłówki silnika — ZWERYFIKUJ, czy nie wymaga przebudowy dla 4.7.2).

**Konsekwencje:**
- Faza 5, na urządzeniu: (1) export AAB z Gradle build i plugin ładuje się bez crasha, (2) zakup `remove_ads` licencjonowanym testerem z Play Internal + acknowledge widoczny w Play Console, (3) consume `coins_small` i ponowny zakup, (4) reinstall → restore na obu platformach, (5) Sandbox/TestFlight: purchase, finish transaction, restore, (6) PENDING (wolna metoda płatności) nie przyznaje nagrody.
- Do czasu integracji wszystko działa na `FakeIapProvider`; `make check` nie zależy od pluginów (nie ładują się w headless Linux).
- Zmiana wersji BL przy kolejnych terminach Google (BL 8 wycofana 31.08.2027) = podbicie pluginu, bez zmian w logice gry.
- Plugin iOS ma jednego autora (bus factor 1) → przy braku wydania pod przyszłą wersję Godota przejście na Plan B.

---

## ADR-011: Generacja następnego poziomu w tle (`WorkerThreadPool`, prefetch N+1)

**Data:** 2026-10-24
**Status:** Proposed (Accepted po merge T-136; nie zmienia ADR-009)

**Kontekst:**
- Poziom powstaje w runtime z seeda (ADR-009) synchronicznie w `Level.load_level` — wątek główny stoi na czas `ContentGenerator.generate`. Pomiar CI: mediana ~57–60 ms/poziom, p95 159–189 ms (T-107, T-124); słabsze telefony są kilkukrotnie wolniejsze (współczynnik ZWERYFIKUJ na urządzeniu w T-054), więc przy starcie trudnego poziomu grozi widoczne przycięcie (> 100 ms, 6+ klatek przy 60 FPS).
- Optymalizacja solvera (T-124) dała szum ±6 %; T-134 mierzy hot-spoty przed kolejną próbą. Niezależnie od wyniku, przeniesienie generacji z wątku głównego usuwa przycięcie dla typowej ścieżki „Dalej” po wygranej.
- Alternatywa z ADR-009 (paczka poziomów generowana w buildzie) zwiększa rozmiar i czas builda, a Poziom dnia i zmiany remote configu i tak wymagają generacji w runtime.

**Decyzja:**
- Czysta klasa `LevelPrefetch` (RefCounted, bez `Node`) zleca `ContentGenerator.generate(seed, level + 1)` na `WorkerThreadPool` (wbudowane w Godot 4 — bez nowej zależności, ADR-007 bez zmian) w chwili wygranej; `Level.load_level` odbiera wynik (`take`), a gdy zadanie trwa — czeka na nie (`wait_for_task_completion`); brak żądania → generacja synchroniczna jak dotąd.
- Generator w wątku wyłącznie czyta `GameConfig`; `apply_remote` nie jest wołany w trakcie rundy (remote config stosowany przy starcie aplikacji, Faza 6). Cache = 1 wpis, `cancel_all()` w `Level._exit_tree` (brak wiszących zadań przy zmianie sceny i w testach).
- Kod generatora i solvera bez zmian → poziomy graczy i golden hashe bez zmian.

**Konsekwencje:**
- Testy muszą czekać na zadania (inaczej wycieki / „still in use” jak w T-112); test `take` po `request` == wynik synchroniczny pilnuje determinizmu.
- Jeżeli w przyszłości `GameConfig` będzie zmieniany w trakcie gry (np. A/B w locie), prefetch musi brać snapshot wartości — wtedy nowy ADR.
- Poziom dnia i pierwszy poziom po starcie aplikacji nadal synchroniczne (later: prefetch Poziomu dnia przy wejściu na `Home`).

