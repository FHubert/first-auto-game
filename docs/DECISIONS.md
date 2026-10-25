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
**Status:** Accepted (T-136; nie zmienia ADR-009)

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
- Rozszerzenie (T-167): `App` zleca `request(campaign_seed, state.level)` przy wejściu na `Home` (pomija wznawialną rundę kampanii) i przekazuje instancję do `Level.prefetch` przy „Graj”; wyjście z `Home` gdzie indziej → `cancel_all()`.


## ADR-012: Lokalne notyfikacje — interfejs teraz, plugin w Fazie 5

**Data:** 2026-10-24
**Status:** Proposed (T-150)

**Kontekst:**
- Reguła 3 KPI: retencja D7 (≥ 12 %) jest najsłabszym ogniwem, a przypomnienie o serii / Poziomie dnia to najtańsza dźwignia powrotu.
- Brak SDK i kont w tej fazie — nie da się zweryfikować pluginu na urządzeniu, więc nie dodajemy zależności.
- `ConsentProvider` pokazuje wzorzec: interfejs no-op w repo, realna implementacja podmieniana później.

**Decyzja:**
- Czysta `NotificationPlanner` (RefCounted; czas i strefa wstrzykiwane) planuje 0–2 wpisy, a `NotificationProvider` (no-op) i `FakeNotificationProvider` (testy) izolują platformę. Bez nowej zależności (ADR-007 bez zmian do czasu wyboru pluginu).
- Plugin Android 13+ (`POST_NOTIFICATIONS`) / iOS (`UNUserNotificationCenter`) w Fazie 5 osobnym ADR.

**Konsekwencje:**
- Logika w pełni testowalna headless; podpięcie w `Main` i ustawienia — kolejne zadania.
- Klucze tłumaczeń `notif_*` i podpięcie w `App` (FOCUS_OUT → `cancel_all` + `schedule`, FOCUS_IN/`_ready` → `cancel_all`, stałe ID 1/2/3, event `notif:scheduled:<kind>`) — T-151; provider niedostępny (`is_available() == false`) → zero wywołań.
- Zgoda systemowa (T-223): `permission_status()`/`request_permission(callback)` w providerze, decyzja „czy pytać” w czystej `NotificationPermission.should_ask`; `App` pyta raz przy wejściu na `Home`, flaga `notif_permission_asked` zapisana przed prośbą, planowanie tylko przy `granted`/`not_required`.
- ZWERYFIKUJ: nazwa pluginu dla Godot 4.7 (kompatybilność z eksportem Android/iOS).


## ADR-013: Ładowanie reklam — preload i ponawianie w `AdService`, provider bez logiki retry

**Data:** 2026-10-25
**Status:** Accepted (2026-10-25, T-225: `AdProvider.load_*` + sygnały, preload/ponawianie w `AdService` wg `AdLoadPolicy`, eventy `ads:load:*`)

**Kontekst:**
- `AdProvider` (ADR-003) ma dziś tylko `is_*_ready()` i `show_*()` — bez pojęcia ładowania. `FakeAdProvider` jest „zawsze gotowy”, więc żadna ścieżka testowa nie sprawdza, co się dzieje po pokazie albo po błędzie sieci.
- AdMob: „RewardedAd is a one-time-use object”, „Ads can only be shown once per load”, zalecany preload po zamknięciu reklamy; ponawianie ładowania z callbacku błędu „strongly discouraged”, a jeśli konieczne — „limit ad load retries” (https://developers.google.com/admob/unity/rewarded, 2026-10-25; strona dla Unity — dla pluginu Godot ZWERYFIKUJ w Fazie 5, ale model obiektu jest wspólny dla SDK Android/iOS).
- Bez preloadu i ponawiania rewarded po 1. pokazie albo po 1. błędzie zostałby niedostępny do końca sesji — przyciski rewarded są ukryte, gdy reklama nie jest gotowa (MONETIZATION → Zasady), czyli 0 impresji (ARPDAU).

**Decyzja:**
- Interfejs `AdProvider` dostaje `load_rewarded()`, `load_interstitial()` i sygnały `*_loaded` / `*_load_failed(code)`; adapter SDK (Faza 5) tylko tłumaczy wywołania i callbacki pluginu, bez własnej logiki ponawiania.
- Kiedy ładować i kiedy ponawiać decyduje `AdService` z czystą klasą `AdLoadPolicy` (RefCounted, bez `Node`, czas wstrzykiwany): wykładniczy odstęp `ad_load_retry_base_seconds` × 2^(n−1) do `ad_load_retry_max_seconds`, rezygnacja po `ad_load_max_retries` kolejnych błędach na format na sesję (wartości w `GameConfig`, zmienne remote configiem; GDD → Ekonomia).
- `FakeAdProvider` domyślnie ładuje od razu i z sukcesem (testy i `make playtest` bez zmian), a tryby `fail_next_loads`/`hold_loads` pozwalają testować błędy i opóźnienia headless.
- Bez nowej zależności (ADR-007 bez zmian).

**Konsekwencje:**
- Kontrakt T-165 (`test_provider_contracts.gd`) obejmuje nowe metody — adapter AdMob bez nich wykryty przed urządzeniem.
- Nowy event `ads_load` (`ads:load:fail:<format>`, `ads:load:giveup:<format>`) — kategoria „Advertising interactions” w Data Safety / Privacy Labels (`docs/RELEASE_CHECKLIST.md`).
- Inbox T-212 (id przerwy w `interstitial_closed`) do rozważenia razem z sygnałami ładowania przy pisaniu adaptera.
- Wartości 2 / 64 / 6 to założenie (przykład AppLovin MAX: https://support.applovin.com/en/max/android/ad-formats/rewarded-ads, 2026-10-25) — kalibracja po soft launchu eventem `ads_load`.


## ADR-014: Podpowiedź liczona w tle (`HintJob`) z tokenem anulowania — uzupełnia ADR-011

**Data:** 2026-10-25
**Status:** Accepted (T-222; nie zmienia ADR-009 ani ADR-011)

**Kontekst:**
- T-210 (`measure_hint.gd`, 36 stanów w trakcie rundy) pokazał, że `GameRound.hint()` blokuje wątek główny do ~2,7 s (x86 CI; telefon budżetowy kilkukrotnie wolniej, współczynnik ZWERYFIKUJ w T-054 — próg ANR to 5 s). Wolne są stany 0 % poziomów 40/56/80/120: przebieg exact wyczerpuje `hint_solver_max_states` (20 000 stanów ≈ 2,3 s, 80–140 µs/stan), potem przebieg ważony znajduje rozwiązanie szybko.
- Wariant A (mniejszy budżet, bez zmiany UX) zmierzony na tych samych stanach, med/p95/max ms (hint): limit 2000 — 8–25: 13,4/31,3/31,3; 26–55: 8,9/245,2/245,2; 56+: 87,6/326,3/326,3; dzienny: 19,1/197,2/197,2. Limit 5000 — 13,1/39,2/39,2; 6,6/555,9/555,9; 83,0/747,8/747,8; 20,3/439,6/439,6. Limit 10000 — 13,5/32,0/32,0; 6,8/1158,7/1158,7; 86,5/1432,8/1432,8; 19,6/807,7/807,7. Bramka (p95 ≤ 100 ms i max ≤ 500 ms w KAŻDYM przedziale) niespełniona przy żadnym limicie: stany 0 % wyczerpują exact przy każdym limicie ≥ 2000, a p95 ≤ 100 ms to ≈ 1000 stanów łącznie z obu przebiegów. Poprawność (rozwiązanie znalezione tam, gdzie baza 20 000 je znajdowała): 24/24 przy każdym limicie, ale przy 2000 w 3 z 24 stanów ścieżka dłuższa niż optymalna (przebieg ważony), przy 5000 w 1.

**Decyzja:**
- Wariant B: `HintJob` (RefCounted, `WorkerThreadPool`, wzorzec `LevelPrefetch`) liczy dokładnie to samo co `GameRound._solve_cached` (exact, a gdy brak wyniku — przebieg ważony) na KLONIE planszy zrobionym na wątku głównym; wynik jest identyczny jak synchroniczny (test). `solver_max_states`, generator i poziomy bez zmian.
- `SortSolver.solve` dostaje opcjonalny `SolverCancel` (flaga bool: zapis z wątku głównego, odczyt w roboczym — atomowy), sprawdzany co 256 rozwinięć (~30 ms), więc `cancel()` w `_after_action`/`_bind_round`/`_exit_tree` nie blokuje wątku głównego dłużej niż to. Bez tokena zachowanie solvera bez zmian (golden hashe).
- `Level._request_hint`: z cache lub bez środków (sklep) — od razu przez `offers.buy_hint()`; inaczej przycisk „…” (disabled) i liczenie w tle. Monety pobierane DOPIERO po wyniku (`offers.buy_hint()` z zasilonym cache), a wynik przyjmowany tylko dla planszy z chwili żądania (`solution_key()`); ruch/cofnięcie/restart/zakup/wyjście z poziomu anuluje zadanie, monety nietknięte. Wynik bez ścieżki nie pobiera monet.
- `StuckPanel.show_for` ZOSTAJE synchroniczny (odstępstwo od KA T-222): `_check_stuck` woła je tylko gdy `round.is_stuck()` (brak legalnych ruchów), więc solver rozwija 1 stan — T-210 zmierzył 0,3–0,9 ms dla wszystkich 11 martwych stanów, a test `test_stuck_board_solves_in_one_expansion` pilnuje ≤ 2 rozwinięć i < 50 ms.

**Konsekwencje:**
- Wątek główny: `HintJob.request` (klon + `add_task`) 0,1–0,3 ms zamiast do 2,7 s (tabela w GDD). Czas do podpowiedzi (worker) bez zmian — przycisk „…” do ~2,7 s na CI w najgorszym stanie; na telefonie może to być kilkanaście sekund, więc ZWERYFIKUJ w T-054 i rozważ ograniczenie budżetu (A) dodatkowo.
- Konfiguracja czytana w wątku przez `HintJob` jest przekazywana jako argumenty z wątku głównego (limit, waga); solver nie dotyka `GameConfig`.
- Przyszłe zmiany stanu planszy poza `pour_finished`/`_after_action` muszą wołać `_cancel_hint()` albo polegać na kluczu planszy (odrzuca wynik).


## ADR-015: Konfiguracja dla wątków roboczych — migawka z wątku głównego — uzupełnia ADR-011 i ADR-014

**Data:** 2026-10-25
**Status:** Accepted (T-252; nie zmienia ADR-009, ADR-011 ani ADR-014)

**Kontekst:**
- `LevelPrefetch._work` wołał `ContentGenerator.generate`, który czytał `GameConfig.get_value` (~22 odczyty) na wątku roboczym, a `GameConfig.reset()`/`apply_remote()` podmieniają `_values` na wątku głównym. Wyścig dał 1× czerwony `test_daily_ui.gd > test_daily_level_flow` („Nonexistent 'float' constructor”, Inbox T-244); w grze to samo grozi przy remote configu (Faza 6) z aktywnym prefetchem. Założenie „apply_remote nie w trakcie rundy” nie było wymuszone.
- `HintJob` (ADR-014) ma właściwy wzorzec: parametry kopiowane na wątku głównym.

**Decyzja:**
- `GameConfig.snapshot()` zwraca głęboką kopię `_values`; `GameConfig.revision()` to licznik zwiększany przez `reset()`, `set_for_test()` i `apply_remote()` (tylko gdy zastosowano >= 1 klucz).
- `ContentGenerator._init(snapshot := {})` bierze migawkę (domyślnie `GameConfig.snapshot()` z chwili utworzenia) i czyta klucze wyłącznie przez `_cfg_int`/`_cfg_float` z klucza-literału (zgodne ze strażnikiem `test_config_keys.gd`, bez nowych wyjątków). Generator i `LevelPrefetch` nie zawierają `GameConfig.get_value` (test).
- `LevelPrefetch.request` robi migawkę i zapamiętuje `revision()` na wątku głównym; `_work` dostaje gotowy generator. `take()` przy innej `revision()` odrzuca wynik i generuje synchronicznie (`sync_generations` +1) z bieżącą konfiguracją.
- Wynik generacji bez zmian (golden hashe, poziomy 1..200, Poziom dnia).

**Konsekwencje:**
- Każdy nowy kod na `WorkerThreadPool` dostaje konfigurację jako argument/migawkę, nie z `GameConfig`.
- Zmiana konfiguracji w trakcie prefetchu kosztuje jedną synchroniczną generację przy `take()` (rzadkie: remote config na starcie).
