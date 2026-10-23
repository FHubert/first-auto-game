# GDD — Vialo (nazwa robocza)

Status: APPROVED
Wersja: 1.0 · Data: 2026-10-23 · Zmiana statusu na `APPROVED`: zadanie R-002

> Dopóki status to `DRAFT`, pętla bierze wyłącznie zadania z `BACKLOG.md` → `## P0 — fundamenty` (CLAUDE.md).

Konwencje tego dokumentu:
- Każda liczba balansu to **PROPOZYCJA** z nazwą klucza `GameConfig` (`game/src/systems/config.gd`). Wartości wpisuje `gameplay-dev` w zadaniach z backlogu; tabela zbiorcza kluczy jest w sekcji „Ekonomia → Klucze GameConfig".
- „Poziom" = jedna runda. Istniejące klucze `interstitial_every_n_rounds` itd. zachowują nazwę „rounds" (1 runda = 1 poziom); zmiany nazw nie proponujemy, żeby nie łamać `tools/balance_sim.py` i testów.
- Nazwy klas: istniejące (`GameRound`, `ContentGenerator`, `GameState`, `SaveSystem`, `Ads`, `Analytics`, `PlaytestBot`) zostają. Nowe czyste klasy (bez `Node`): `SortBoard`, `SortSolver`, `Economy`, `DailyRewards`, `DailyChallenge`, `ThemeCatalog`, `TutorialFlow`. Format poziomu i determinizm: ADR-009.

## Pitch
Relaksująca gra w przelewanie kolorów dla dorosłych casualowych graczy: krótkie poziomy, jeden wspólny poziom dnia i kolekcja motywów, po które wraca się codziennie.

## Gatunek i referencje
*Gatunek oraz 2–3 tytuły z top-10 z `docs/RESEARCH.md`. Przy każdym: co bierzemy, a czego nie.*

- Gatunek: sort puzzle — water sort (przelewanie warstw koloru między probówkami), progresja poziomów, content w 100 % generowany z seeda i weryfikowany solverem (`docs/RESEARCH.md`, kandydat 1, 34/45).
- Referencja 1: **Water Sort: Color Puzzle Game** (100 mln+ pobrań Google Play, [RESEARCH 6]) — bierzemy: regułę przelewania (tylko na ten sam kolor lub do pustej), pojemność 4, 2 puste probówki, cofanie i dodatkową probówkę jako boostery. Nie bierzemy: banneru stale na ekranie i interstitiala po każdym poziomie.
- Referencja 2: **Water Match™ ASMR Water Sort** (top-3 pobrań puzzle Android DE, Q4 2025, [RESEARCH 5]) — bierzemy: nacisk na ASMR (płynna animacja przelewania, bulgot, haptyka), motywy wizualne. Nie bierzemy: realistycznej grafiki 3D (nie do wygenerowania w `tools/gen_assets.py`).
- Referencja 3: **Magic Sort** (Grand Games, #1 przychodu w podgatunku, ~50 mln USD w 2025, [RESEARCH 1]) — bierzemy: boostery jako towar IAP (monety → dodatkowa probówka, podpowiedź), pakiet startowy. Nie bierzemy: rozbudowanej mety z dekoracją/fabułą (za dużo contentu na MVP).
- Wyróżnik (decyzja R-001, doprecyzowana): **„Poziom dnia"** — jeden wspólny, deterministyczny poziom na dzień UTC dla wszystkich graczy (seed z daty), z osobną nagrodą i licznikiem; oraz **motywy** (paleta płynów + tło + kształt probówki) odblokowywane monetami — cel na D7.

## Core loop
*Jeden akapit: co gracz robi co 10–30 s, jaką dostaje nagrodę i co ona odblokowuje. Diagram ASCII poniżej.*

Co kilka sekund gracz stuka probówkę źródłową, a potem docelową — górna warstwa koloru przelewa się z animacją i dźwiękiem bulgotu (ruch legalny tylko na ten sam kolor albo do pustej probówki, w granicach pojemności 4). Co 20–60 s kończy poziom: każda probówka jest pusta albo pełna jednego koloru. Nagroda to monety (`win_reward_coins` + premia „idealnie" za liczbę ruchów ≤ minimum solvera + `par_slack_moves`), opcjonalnie ×2 za reklamę rewarded. Monety wydaje na boostery (podpowiedź, dodatkowa probówka, dodatkowe cofnięcia), gdy utknie, oraz na motywy, które zmieniają wygląd każdej kolejnej rozgrywki. Kolejny poziom ma tyle samo albo więcej kolorów i większą minimalną liczbę ruchów, więc nowe wyzwanie wynika z nagrody i progresji. Raz dziennie gracz rozgrywa Poziom dnia i odbiera nagrodę dzienną, co podtrzymuje streak.

```
        +-----------------------------------------------------------+
        |                                                           |
        v                                                           |
 [stuknij źródło] -> [stuknij cel] -> pour() legalny? --nie--> [shake + buzz]
        ^                                 | tak                     |
        |                                 v                         |
        |                        [animacja przelewania]              |
        |                                 |                         |
        |               utknąłeś? <-------+-------> is_won()?       |
        |                  | tak                       | tak         |
        |                  v                           v             |
        |   [panel: cofnij / +probówka /       [ekran wygranej:      |
        |    podpowiedź / restart / pomiń]      monety, ×2 rewarded] |
        |       (monety lub rewarded)                  |             |
        +------------------+                           v             |
                                         [monety -> motywy, boostery]|
                                                       |             |
                                                       v             |
                                     [następny poziom: więcej kolorów,
                                      wyższe min_moves] -------------+
        (raz dziennie: nagroda dzienna + Poziom dnia -> streak +1)
```

## Sesja
*Długość (cel 2–5 min), warunek zakończenia sesji i hook: co czeka na gracza po powrocie.*

- Długość: cel ~3 min (`session_target_seconds` = 180, istniejący klucz) = 4–6 poziomów po 20–60 s; poziom dnia ~60–120 s. Mieści się w 2–5 min (KPI: kill-line 2 min, cel 4 min).
- Zakończenie sesji: naturalny punkt wyjścia po ekranie wygranej (brak timera i brak porażki „game over" — gracz może przerwać w dowolnym momencie; stan planszy w trakcie poziomu nie jest zapisywany w MVP, poziom startuje od nowa — patrz Mechaniki „Zapis planszy w trakcie" = later).
- Hook do następnej sesji: (1) licznik do kolejnego Poziomu dnia (północ UTC) na ekranie głównym, (2) streak i następna nagroda dzienna (dzień 7 = ×6), (3) pasek postępu do następnego motywu („420 / 600"), (4) „następny poziom: 1 kolor więcej" widoczne po co 6. poziomie.

## Progresja
*Krzywa trudności, odblokowania (poziomy, światy, bohaterowie, ulepszenia) i tempo. Po ilu sesjach gracz ma pierwszy „ładny" moment.*

**Parametry poziomu `level` (kampania, poziomy 1..∞)** — liczone w `ContentGenerator`, wszystkie z `GameConfig`:

| Parametr | Wzór | Klucze (PROPOZYCJA) |
|---|---|---|
| Pojemność probówki | stała | `tube_capacity` = 4 |
| Puste probówki | stała | `empty_tubes` = 2 |
| Liczba kolorów `n` | poziom 1: `tutorial_colors`; dalej `min(colors_max, colors_start + floor((level - 2) / levels_per_extra_color))` | `tutorial_colors` = 2, `colors_start` = 3, `levels_per_extra_color` = 6, `colors_max` = 12 |
| Trudność `d` ∈ [0,1] | istniejąca logistyczna `ContentGenerator.difficulty_curve(level)`; co `breather_every` poziom `d *= breather_factor` | `difficulty_min` 0.1, `difficulty_max` 1.0, `difficulty_midpoint_level` 20, `difficulty_steepness` 0.15 (istniejące); `breather_every` = 5, `breather_factor` = 0.65 (nowe) |
| Próg minimalnej liczby ruchów | `min_moves_floor = ceil(n × lerp(min_moves_factor_easy, min_moves_factor_hard, d))` | `min_moves_factor_easy` = 1.2, `min_moves_factor_hard` = 2.0 |

Przykładowe wartości (z wzorów powyżej, do potwierdzenia testem generatora):

| Poziom | Kolory `n` | Probówki | `d` | `min_moves_floor` |
|---|---|---|---|---|
| 1 (tutorial) | 2 | 4 | 0,15 | 3 |
| 2 | 3 | 5 | 0,15 | 4 |
| 5 (breather) | 3 | 5 | 0,12 | 4 |
| 8 | 4 | 6 | 0,23 | 6 |
| 19 | 5 | 7 | 0,52 | 9 |
| 20 (breather) | 6 | 8 | 0,36 | 9 |
| 40 (breather) | 9 | 11 | 0,62 | 16 |
| 56+ | 12 | 14 | ~1,0 | 24 |

- FTUE (skill `game-economy` §3): poziomy 1–5 mają 2–3 kolory i bez blokującej porażki (brak „game over"), więc win rate ≈ 100 % — powyżej wymaganego ≥ 85 %. Pierwsza wygrana < 60 s (poziom 1: 2 kolory, ~3–4 ruchy). Pierwsza nagroda (monety) < 30 s.
- „Porażka" w tym gatunku = utknięcie (brak legalnych ruchów) albo pętla bez postępu → restart/pomiń. Near miss: panel „Utknąłeś" pokazuje, ile ruchów brakuje do rozwiązania wg solvera (np. „Jesteś 3 ruchy od celu") i oferuje dodatkową probówkę (rewarded) — wymóg near-miss ze skilla §2.
- Tempo: przy ~10–12 poziomach/dzień (3 sesje × 4 poziomy, założenie z KPI „sesje/DAU" cel 3,0) gracz osiąga plateau 12 kolorów ok. dnia 5–6; dalej różnorodność daje `d` (próg ruchów) i breathery.
- Pierwszy „ładny" moment: sesja 2–3 (dzień 1–2) — pierwszy kupiony motyw (koszt `theme_cost_base` = 600 monet ≈ 1,5–2 dni gry, patrz Ekonomia). Drugi: dzień 7 streaka (nagroda ×6 = 300 monet).
- Odblokowania: co 6 poziomów +1 kolor (komunikat na ekranie wygranej), Poziom dnia dostępny od ukończenia poziomu `daily_unlock_level` = 3 (po tutorialu), sklep motywów od poziomu 1.

## Ekonomia
*Waluty, źródła i sinki. Wartości startowe trzymamy w `game/src/systems/config.gd`, nie w tym dokumencie.*

| Waluta | Typ (miękka / twarda) | Źródła | Sinki | Uwagi |
|---|---|---|---|---|
| `coins` (Monety) | miękka (jedyna w MVP, skill §1) | wygrana poziomu (`win_reward_coins` = 15), premia „idealnie" (`par_bonus_coins` = 10, gdy ruchy ≤ `min_moves` + `par_slack_moves` = 2), ×2 za rewarded `double_coins` (`rewarded_multiplier` = 2.0), Poziom dnia (`daily_challenge_coins` = 50), nagroda dzienna (`daily_reward_base` = 50 × mnożnik dnia), start (`starting_coins` = 100), IAP (`coins_small`, `coins_large`, `starter_pack`) | dodatkowa probówka (`extra_tube_cost_coins` = 60), podpowiedź (`hint_cost_coins` = 25), +3 cofnięcia (`undo_refill_cost_coins` = 20), motywy (`theme_cost_base` = 600, `theme_cost_growth` = 1.8 → 600 / 1080 / 1944) | saldo nigdy < 0 (`Economy.spend` zwraca `false`, `GameState.from_dict` odrzuca ujemne) |
| `undo_charges` (cofnięcia) | zasób per poziom, nie waluta | `undo_free_per_level` = 3 na start poziomu; +`undo_refill_amount` = 3 za rewarded `undo_refill` albo za monety | 1 cofnięcie = 1 ładunek | reset przy każdym starcie/restarcie poziomu |

Potwierdzone `make sim` (G-011/G-013, seed 1, 1000 graczy): gracz zaangażowany zarabia ~250–300 monet/dzień aktywny (8 wygranych × 15 + 3 × 10 „idealnie" + ~2 × 15 za ×2 + Poziom dnia + nagroda dzienna); 1. motyw w 2. dniu aktywnym, 3. motyw ok. 10. dnia aktywnego (cel 12–14; mediana wśród kupujących), interstitial 1,36/DAU, impresje łącznie 4,1/DAU, mediana d30/d1 ≈ 1,7 (brak inflacji). Przed kalibracją (10/5): 1. motyw 3. dnia, 3. motywu nikt nie kupował w 30 dni.
- Rezerwa sinków przeciw inflacji: kolejne motywy (later) i rosnący koszt podpowiedzi w trudnych poziomach (later).

**Klucze GameConfig (PROPOZYCJA dla `gameplay-dev`; istniejące oznaczone *)**

| Klucz | Wartość | Uwagi |
|---|---|---|
| `interstitial_every_n_rounds`* | **5** | G-001 (było 3): 3 dawało ~8,6 impr./DAU w sim |
| `interstitial_min_seconds`* | **120** | G-001 (było 90) |
| `interstitial_min_level` | 8 | brak interstitiali w FTUE / pierwszej sesji |
| `rewarded_multiplier`* | 2.0 | H1 testuje 3.0 |
| `daily_reward_base`* | 50 | |
| `daily_reward_multipliers` | `[1, 1, 2, 2, 3, 3, 6]` | Array; dzień 7 = ×6 |
| `starting_coins`* | **100** (było 0) | pierwszy sink (probówka 60) dostępny w 1. sesji |
| `win_reward_coins`* | **15** | G-013 (było 10) |
| `par_slack_moves` | 2 | |
| `par_bonus_coins` | **10** | G-013 (było 5) |
| `daily_challenge_coins` | 50 | |
| `daily_unlock_level` | 3 | |
| `session_target_seconds`* | 180 | |
| `difficulty_*`* (4 klucze) | bez zmian | |
| `breather_every` / `breather_factor` | 5 / 0.65 | skill §2 |
| `tube_capacity` / `empty_tubes` | 4 / 2 | |
| `tutorial_colors` / `colors_start` / `colors_max` / `levels_per_extra_color` | 2 / 3 / 12 / 6 | |
| `min_moves_factor_easy` / `min_moves_factor_hard` | 1.2 / 2.0 | |
| `gen_max_attempts` | 20 | regeneracja seed+k |
| `solver_max_states` | 50000 | limit stanów A* |
| `solver_fallback_weight` | 3.0 | ważony A* po przekroczeniu limitu |
| `campaign_seed` | 1 | wspólny dla wszystkich graczy |
| `daily_seed_salt` | 104729 | |
| `daily_colors` / `daily_min_moves_factor` | 8 / 1.8 | Poziom dnia: stały, średnio-trudny |
| `undo_free_per_level` / `undo_refill_amount` / `undo_refill_cost_coins` | 3 / 3 / 20 | |
| `extra_tube_cost_coins` / `extra_tube_max_per_level` | 60 / 1 | |
| `hint_cost_coins` | 25 | |
| `skip_unlock_restarts` | 2 | „Pomiń" (rewarded) po 2 restartach tego samego poziomu |
| `theme_cost_base` / `theme_cost_growth` | 600 / 1.8 | |
| `streak_save_max_per_week` | 1 | ratowanie streaka za rewarded |
| `starter_offer_min_level` / `starter_offer_hours` | 12 / 72 | |
| `pour_anim_seconds` | 0.4 | UI, nie balans; w configu, by stroić bez builda |

## Meta
*Daily reward (wartości dni 1–7), streak (co go resetuje, czy jest grace period) i cele 7- oraz 30-dniowe.*

- Daily reward: odbierana raz na dzień UTC na ekranie głównym (popup przy pierwszym wejściu dnia). Dzień cyklu = `((streak_days - 1) % 7) + 1`. Wartości = `daily_reward_base` × `daily_reward_multipliers`: **D1 50, D2 50, D3 100, D4 100, D5 150, D6 150, D7 300** monet. Przycisk „Odbierz ×2" = rewarded `daily_x2` (skill: najlepszy placement pod ARPDAU). Po D7 cykl od początku.
- Streak: `GameState.streak_days` +1, gdy gracz ukończy ≥ 1 poziom (dowolny) w nowym dniu UTC względem `last_play_utc_day`. Ten sam dzień → bez zmian. Przerwa dokładnie 1 dnia (ostatnia gra przedwczoraj) → **grace**: popup „Uratuj streak" za rewarded `streak_save` (max `streak_save_max_per_week` = 1 na 7 dni UTC); odmowa lub przerwa ≥ 2 dni → reset do 1. Czas wyłącznie w dniach UTC (`floor(unix / 86400)`), źródło czasu wstrzykiwane (`Callable`, jak `Ads.clock`) — testowalne bez zegara.
- Poziom dnia (wyróżnik): jeden poziom na dzień UTC, ten sam dla wszystkich (seed z dnia UTC, ADR-009), `daily_colors` = 8, próg `daily_min_moves_factor` = 1.8 × n; nagroda `daily_challenge_coins` = 50 raz na dzień; licznik `daily_completed_total` i odznaka „ukończono dziś" na ekranie głównym. Licznik do następnego (północ UTC).
- Cele 7 dni: (1) 7-dniowy streak = nagroda D7 300 monet, (2) pierwszy kupiony motyw (koszt 600 ≈ dzień 2), (3) 7 ukończonych Poziomów dnia, (4) poziom ~50 (11 kolorów).
- Cele 30 dni: (1) wszystkie 3 płatne motywy MVP (600 + 1080 + 1944 = 3624 monety ≈ dzień 12–14), (2) 20+ Poziomów dnia w miesiącu → (later) motyw miesiąca i kalendarz odznak, (3) najlepszy streak ≥ 30 (`streak_best`).

## Generator contentu
*Opisz algorytm generacji (seed, parametry z configu). Test rozwiązywalności: headless solver przechodzi każdy poziom dla zakresu seedów, uruchamiany w `make test`.*

- Algorytm (`ContentGenerator.generate(seed_value, level) -> Dictionary`, kontrakt zachowany: `seed`, `level`, `difficulty`, `payload`; czysta klasa `RefCounted`):
  1. Parametry z sekcji Progresja: `n`, `tube_capacity` (C), `empty_tubes` (E), `d`, `min_moves_floor`.
  2. Stan rozwiązany: `n` probówek po C jednostek jednego koloru (`0..n-1`) + E pustych.
  3. Mieszanie z seeda: `RandomNumberGenerator` z `seed = level_seed + attempt`, gdzie `level_seed = hash([campaign_seed, level])` (kampania) albo `daily_seed(utc_day)` (Poziom dnia). Wszystkie `n × C` jednostek tasujemy Fisher–Yatesem (tylko `randi()`, bez `randf()` — determinizm, ADR-009) i rozdajemy do `n` probówek po C; E probówek zostaje pustych. To odpowiada dowolnie długiej sekwencji ruchów wstecz „po jednej jednostce" od stanu rozwiązanego.
  4. Odrzucenie trywialnych: jeśli jakakolwiek probówka jest już pełna jednego koloru albo stan jest wygrany → następna próba.
  5. Solver (`SortSolver`, A*, heurystyka h = liczba granic kolorów wewnątrz probówek; dopuszczalna, bo jeden przelew usuwa co najwyżej jedną granicę) liczy `min_moves` z limitem `solver_max_states`. Po przekroczeniu limitu: ważony A* (`solver_fallback_weight` = 3.0) z tym samym limitem → `min_moves` = długość znalezionego rozwiązania, `min_moves_exact = false`.
  6. Akceptacja: rozwiązywalny i `min_moves >= min_moves_floor`. W przeciwnym razie próba `attempt + 1` (czyli seed+1), maksymalnie `gen_max_attempts` = 20. Jeśli żadna próba nie spełnia progu, ale są rozwiązywalne → bierzemy rozwiązywalną z największym `min_moves` (najniższy `attempt` przy remisie; deterministycznie). Jeśli żadna nie jest rozwiązywalna → `push_error` + poziom zapasowy = stan po 1. rozwiązywalnej próbie z `n-1` kolorami (test wymaga, by to nie wystąpiło w zakresie testowym).
  7. `payload` = `{"capacity": C, "colors": n, "tubes": Array[Array[int]] (dół→góra), "min_moves": int, "min_moves_exact": bool, "attempt": int, "solution": Array[Vector2i]}` (`solution` służy botowi i podpowiedzi).
  - Dlaczego nie „N legalnych ruchów wstecz" (propozycja z R-001): odwrotność przelewu „ile się zmieści" jest legalna tylko gdy w źródle zostaje ten sam kolor albo źródło się opróżnia, więc taki scramble rzadko odsłania głębsze warstwy i daje płytkie poziomy. Tasowanie jednostek + solver daje pełne mieszanie, a gwarancję rozwiązywalności przenosi na solver i regenerację seed+k.
- Seed i zakres testowy: kampania `campaign_seed` = 1, poziomy **1..200** (test w `make test`); Poziom dnia: dni UTC **20750..20779** (30 dni od 2026-10-24; 2026-10-23 = dzień UTC 20749). Test „golden": hash `tubes` dla poziomów 1, 2, 10, 50 zapisany w teście — zmiana generatora/silnika, która zmienia poziomy graczy, czerwieni CI.
- Test rozwiązywalności (solver, limit ruchów): dla każdego poziomu z zakresu: (a) `min_moves > 0`, (b) odtworzenie `solution` przez `SortBoard.pour` kończy się `is_won() == true` w dokładnie `min_moves` ruchach, (c) `attempt < gen_max_attempts`, (d) ≥ 95 % poziomów 1..200 spełnia `min_moves >= min_moves_floor` (raport odsetka w logu testu), (e) czas generacji poziomu ≤ 500 ms headless na CI (mierzone; jeśli przekroczy — zadanie: prekompilacja paczki poziomów w buildzie, later). Limit ruchów bota = `min_moves` (bot gra ścieżką solvera).
- Co dzieje się z poziomem, który nie przechodzi testu: generator sam regeneruje z `seed + attempt` (attempt = 1..`gen_max_attempts`-1) — opisane w kroku 6; poziom nigdy nie trafia do gracza nierozwiązywalny. Jeśli w zakresie testowym wystąpi poziom bez rozwiązywalnej próby → test czerwony i zadanie na strojenie (`empty_tubes`, `gen_max_attempts`), nie wyłączenie testu.

## Ekrany
*Lista ekranów. Każdy ekran ma wpis w `tools/gen_screenshots.sh`.*

- `Boot` — zgoda UMP/ATT (Faza 5; w MVP: `FakeAdProvider`), wczytanie `SaveSystem`; wejście z: start aplikacji; wyjście do: `Home` (albo od razu `Level` przy pierwszym uruchomieniu — poziom 1 bez menu).
- `Home` — przycisk „Graj: poziom N", karta „Poziom dnia" (stan + licznik do północy UTC), monety, streak, pasek do następnego motywu, wejścia do Motywów, Sklepu, Ustawień; wejście z: `Boot`, `LevelComplete`, `Level` (pauza → menu); wyjście do: `Level`, `DailyRewardPopup`, `Themes`, `Shop`, `Settings`.
- `DailyRewardPopup` — nagroda dnia (7 kafelków), „Odbierz" / „Odbierz ×2" (rewarded `daily_x2`), wariant „Uratuj streak" (rewarded `streak_save`); wejście z: `Home` (pierwsze wejście dnia); wyjście do: `Home`.
- `Level` — probówki, HUD: numer poziomu / „Poziom dnia", licznik ruchów, cofnij (z licznikiem ładunków), restart, +probówka, podpowiedź, pauza; tryby `campaign` i `daily`; wejście z: `Home`, `LevelComplete`; wyjście do: `LevelComplete`, `StuckPanel`, `Home`.
- `StuckPanel` (overlay) — „Utknąłeś — X ruchów od celu": cofnij, +probówka (monety / rewarded `extra_tube`), +3 cofnięcia (monety / rewarded `undo_refill`), restart, pomiń (rewarded `skip_level`, po `skip_unlock_restarts` restartach); wejście z: `Level`; wyjście do: `Level`.
- `LevelComplete` — monety (+premia „idealnie"), „×2" (rewarded `double_coins`), „Dalej"; komunikat o nowym kolorze/postępie motywu; tu (i tylko tu) może wystąpić interstitial `level_end` po „Dalej"; wejście z: `Level`; wyjście do: `Level` (następny), `Home`.
- `Themes` — siatka motywów (podgląd probówek w palecie), cena / „Aktywny" / „Kup"; wejście z: `Home`; wyjście do: `Home`.
- `Shop` — IAP: `remove_ads`, `coins_small`, `coins_large`, `starter_pack` (gdy aktywny), „Przywróć zakupy" (wymóg Apple 3.1.1); wejście z: `Home`, `StuckPanel` (brak monet); wyjście do: poprzedni ekran.
- `Settings` — dźwięk, muzyka, haptyka, język (EN/PL/DE/systemowy), „Przywróć zakupy", „Prywatność / zgoda" (UMP privacy options), wersja (`BUILD_INFO`); wejście z: `Home`, pauza w `Level`; wyjście do: poprzedni ekran.

## Mechaniki
*Każda mechanika ma priorytet MVP lub later oraz sposób testu headless (gdUnit4 albo bot z `make playtest`). Mechanika bez sposobu testu nie wchodzi do MVP.*

| Mechanika | Priorytet (MVP / later) | Jak testujemy headless |
|---|---|---|
| Przelewanie (`SortBoard.pour(from, to)`: tylko na ten sam kolor lub do pustej, przelewa całą górną serię w granicach wolnego miejsca) | MVP | gdUnit4 na `SortBoard`: tabela przypadków (pusta, ten sam kolor, inny kolor, pełna, częściowy przelew, from == to) — legalny zmienia stan zgodnie z oczekiwaniem, nielegalny zwraca `false` i nie zmienia stanu. |
| Warunek wygranej (`is_won`: każda probówka pusta albo pełna jednego koloru) | MVP | gdUnit4: stany wygrane/niewygrane (w tym „monochromatyczne, ale rozdzielone 2+2" = niewygrany). |
| Generator z seeda + regeneracja seed+k | MVP | gdUnit4: determinizm (2× ten sam seed → identyczne `tubes`), golden hash dla 4 poziomów, poziomy 1..200 i 30 dni Poziomu dnia rozwiązywalne (kryteria a–e w sekcji Generator). |
| Solver A* (`SortSolver.solve(board, max_states) -> {moves, path, exact}`) | MVP | gdUnit4: ręczne plansze ze znanym minimum (np. 1, 2, 4 ruchy), plansza nierozwiązywalna → `moves = -1`, limit stanów respektowany (licznik rozwiniętych ≤ `max_states`). |
| Krzywa trudności (kolory, `d`, breather, `min_moves_floor`) | MVP | gdUnit4: wartości z tabeli Progresja dla poziomów 1, 2, 5, 8, 19, 20, 40, 56; monotoniczność `n` w poziomie. |
| Licznik ruchów + premia „idealnie" | MVP | gdUnit4 na `GameRound`: rozwiązanie ścieżką solvera daje `perfect = true`; ścieżka dłuższa o `par_slack_moves + 1` → `false`. |
| Cofnij (stos ruchów, `undo_free_per_level` ładunków) | MVP | gdUnit4: pour → undo przywraca identyczny stan; po wyczerpaniu ładunków undo zwraca `false`; restart resetuje ładunki. |
| Dodatkowa probówka (max `extra_tube_max_per_level`) | MVP | gdUnit4: po dodaniu probówek = n+E+1, druga próba w tym poziomie odrzucona; wygrana nadal wykrywana. |
| Podpowiedź (1. ruch ścieżki solvera z bieżącego stanu) | MVP | gdUnit4: po wykonaniu podpowiedzi `min_moves` z nowego stanu = poprzednie − 1 dla 20 losowych stanów pośrednich. |
| Wykrywanie utknięcia (brak ruchów zmieniających stan) | MVP | gdUnit4: spreparowany deadlock → `is_stuck() == true`; bot losowy w `make playtest` (tryb `--random`) raportuje liczbę utknięć i 0 softlocków (pętla > `MAX_STEPS` bez stuck = błąd). |
| Restart / Pomiń poziom (pomiń po `skip_unlock_restarts`) | MVP | gdUnit4: restart przywraca stan startowy; `can_skip()` false przed 2 restartami, true po; skip podnosi `level` bez monet. |
| Ekonomia (`Economy.earn/spend`, koszty boosterów, motywów) | MVP | gdUnit4: saldo nigdy < 0, `spend` przy braku środków zwraca `false` bez zmiany; `make sim` exit 0 z kluczami z tej sekcji. |
| Nagroda dzienna + streak + grace (`DailyRewards`) | MVP | gdUnit4 z wstrzykniętym dniem UTC: dzień 1..7 wartości 50..300, ponowny odbiór tego samego dnia odrzucony, przerwa 1 dnia → `can_save_streak`, ≥ 2 dni → reset do 1, limit 1 ratunku na 7 dni. |
| Poziom dnia (`DailyChallenge`) | MVP | gdUnit4: ten sam dzień → identyczny poziom; 30 kolejnych dni → 30 różnych, rozwiązywalnych; nagroda raz na dzień. |
| Motywy (`ThemeCatalog`: 1 darmowy + 3 płatne; paleta 12 płynów + tło + kształt probówki z 2 wariantów) | MVP | gdUnit4: koszt n-tego motywu = `round(theme_cost_base × growth^(n-1))`, zakup bez środków odrzucony, aktywny motyw zapisany w `GameState`; każdy motyw ma 12 różnych hex (test). |
| Tutorial (poziom 1, 3 kroki: wskaż źródło → wskaż cel → „ukończ") | MVP | gdUnit4 na `TutorialFlow` (maszyna stanów bez `Node`): kroki przechodzą tylko po właściwym ruchu, po ukończeniu flaga w `GameState.settings`. |
| Interstitial z capem (`level_end`, co `interstitial_every_n_rounds`, min `interstitial_min_seconds`, od `interstitial_min_level`, nigdy po rewarded w tej samej przerwie, nie przy `ads_removed`) | MVP | gdUnit4 `test_ad_service.gd` z `FakeAdProvider` i symulowanym zegarem; `make playtest` raportuje `interstitials_shown` / 200 poziomów. |
| Rewarded (6 placementów, `docs/MONETIZATION.md`) | MVP | gdUnit4: `FakeAdProvider` granted → nagroda przyznana raz; skipped/unavailable → brak nagrody, przycisk ukryty gdy `is_rewarded_ready() == false`. |
| IAP (`remove_ads`, 2 pakiety monet, `starter_pack`) za `IapProvider` + `FakeIapProvider` | MVP (logika i fake), SDK w Fazie 5 | gdUnit4: PURCHASED → przyznanie i zapis; PENDING → brak; restore przywraca `remove_ads`; starter pack tylko raz i tylko w oknie `starter_offer_hours`. |
| Zapis/odczyt postępu (GameState schema v2 + migracja v1→v2) | MVP | gdUnit4: round-trip `to_dict/from_dict`, migracja v1 → v2 z wartościami domyślnymi, odrzucenie ujemnych/złych typów (istniejący wzorzec testów). |
| Lokalizacja EN/PL/DE (CSV TranslationServer, bez addonów) | MVP | gdUnit4: każdy klucz ma 3 niepuste tłumaczenia; teksty przycisków ≤ 18 znaków (limit layoutu). |
| Animacja przelewania + SFX + haptyka (`Input.vibrate_handheld`) | MVP | headless: brak asercji wizualnych; test sprawdza, że `pour_anim_seconds` z configu jest używany i że widok emituje `pour_finished` (scena z `--headless`), `make screenshots` daje PNG `Level`. |
| Analityka (eventy z sekcji Analityka) | MVP | gdUnit4 z `FakeAnalyticsProvider` zapisującym wywołania: sekwencja start → complete → ×2 generuje oczekiwane eventy z parametrami. |
| Zapis planszy w trakcie poziomu (wznowienie po zabiciu aplikacji) | later | gdUnit4: serializacja `SortBoard` + stos undo round-trip. |
| Ukryte kolory („?" — warstwy odkrywane po zdjęciu wyższej) | later | gdUnit4 na `SortBoard` + solver z wiedzą pełną (generator), test odkrywania. |
| Tryb ball sort (kulki zamiast płynu; przenoszenie 1 jednostki) | later | ten sam `SortBoard` z flagą `pour_max = 1`; testy reguły jak dla przelewania. |
| Symbole kolorów (dostępność, daltonizm) | later | gdUnit4: każdy z 12 kolorów ma unikalny symbol w `ThemeCatalog`. |
| Kalendarz Poziomów dnia + motyw miesiąca | later | gdUnit4 na `DailyChallenge`: licznik w miesiącu UTC, próg 20 → odblokowanie. |
| Lokalne notyfikacje (streak, Poziom dnia) | later | wymaga pluginu → ADR; test logiki harmonogramu w czystej klasie. |
| Udostępnianie wyniku Poziomu dnia (tekst jak Wordle) | later | gdUnit4: generowany tekst dla danego wyniku = oczekiwany string. |
| Ranking Poziomu dnia | later | wymaga backendu — poza zakresem do decyzji Huberta. |

## Styl graficzny
*Paleta (max 6 kolorów, hex), kształty i animacje. Wszystko ma być generowalne w `tools/gen_assets.py`, bez ręcznie rysowanych assetów.*

- Paleta: **UI — 6 kolorów** (zgodnie z `tools/palette.json`): tło `#14213D`, tło alternatywne/panele `#1F3A6B`, akcent/monety `#FFD166`, przycisk główny `#2EC4B6`, tekst `#FFFFFF`, szkło probówki `#CAD2E0` (alfa 35 %). **Płyny — osobna paleta contentu 12 kolorów per motyw** (gatunek wymaga do 12 rozróżnialnych kolorów; to wyjątek od limitu 6, patrz Otwarte pytania). Motyw „Classic": `#E63946` czerwony, `#FB8500` pomarańczowy, `#FFD166` żółty, `#80ED99` jasnozielony, `#2A9D8F` morski, `#4CC9F0` błękitny, `#3A86FF` niebieski, `#8338EC` fioletowy, `#FF70A6` różowy, `#9C6644` brązowy, `#ADB5BD` szary, `#F8F9FA` biały. Pozostałe motywy MVP („Pastel", „Neon", „Ocean") definiuje `tools/gen_assets.py` (JSON palet), każdy z 12 kolorami o min. odległości ΔE ≥ 20 między sobą (test w `tools/test_tools.py`).
- Kształty: probówka = zaokrąglony prostokąt (wariant „tube") albo prostokąt z szyjką (wariant „flask"), rysowane w `_draw()` / generowane jako PNG 9-slice; warstwy płynu = prostokąty; ikony UI (cofnij, restart, +probówka, żarówka, moneta, płomień streaka) = proste figury z `tools/gen_assets.py`. Brak tekstur i ilustracji.
- Animacje (tween / klatki): wyłącznie tweeny: podniesienie probówki (0,1 s), przechylenie i przelew (`pour_anim_seconds` = 0,4 s, ubywanie/przybywanie warstwy), „pełna probówka" (pulsowanie + korek, 0,3 s), shake przy nielegalnym ruchu (0,2 s), konfetti z prostokątów na wygranej (cząsteczki `CPUParticles2D`).
- Kontrast tekstu na tle (minimum): WCAG AA 4,5 : 1 dla tekstu; `#FFFFFF` na `#14213D` ≈ 15,9 : 1, `#14213D` na `#FFD166` (przyciski akcentu) ≈ 11 : 1 (ZWERYFIKUJ kalkulatorem WCAG przy implementacji).

## Audio
*Liczba ścieżek muzycznych i SFX, ich źródło (własne generowane lub CC0) oraz wpis każdego obcego pliku w `docs/LICENSES.md`.*

- Muzyka: 1 ścieżka ambient (pad + delikatne arpeggio, pętla 60–90 s, OGG), generowana syntezą w `tools/gen_assets.py`; domyślnie głośność 50 %.
- SFX: 6 dźwięków generowanych w `tools/gen_assets.py`: przelew/bulgot (3 warianty wysokości, losowane — ASMR), probówka pełna (dzwonek), wygrana (krótki jingiel), klik UI, błąd (miękki buzz), monety. Brak obcych plików → `docs/LICENSES.md` bez zmian, dopóki nie dodamy CC0 (wtedy wpis obowiązkowy).
- Ustawienia wyciszenia: osobno muzyka / dźwięki / haptyka w `Settings`, zapisane w `GameState.settings` (`music_on`, `sfx_on`, `haptics_on`); muzyka wycisza się, gdy aplikacja traci fokus i podczas reklamy.

## Analityka
*Lista eventów GameAnalytics: nazwa, parametry, moment wysyłki. Zmiana listy wymaga aktualizacji Data Safety (Play) i Privacy Nutrition Labels (ASC).*

Lista zatwierdzona (v1.0). Mapowanie na GA przez istniejący autoload `Analytics` (`track_progression`, `track_design`, `track_resource`, `track_business`):

- `session_start` — start aplikacji; parametry: wersja (`BUILD_INFO`), platforma. GA: sesja automatyczna SDK + `track_design("session:start")` (`App.track_session_start`, `_ready` i powrót fokusu).
- `session_end` — utrata fokusu/zamknięcie; parametr: czas trwania [s]. GA: automatyczne + `track_design("session:end", seconds)` (`App.track_session_end`, utrata fokusu/zamknięcie).
- `level_start` — start poziomu; parametry: `mode` (`campaign`/`daily`), numer poziomu lub dzień UTC, `colors`, `min_moves`. GA: `track_progression("Start", mode, "level_%04d")` + `track_design("level:start", min_moves)`.
- `level_complete` — wygrana; parametry: poziom, `moves`, `min_moves`, czas [s], `undos_used`, `boosters_used`, `perfect`. GA: `track_progression("Complete", mode, "level_%04d", moves)`.
- `level_fail` — restart / pomiń / wyjście do menu bez wygranej; parametry: poziom, `reason` (`restart`/`skip`/`quit`), czas. GA: `track_progression("Fail", mode, "level_%04d")` + `track_design("level:fail:<restart|skip|quit>")` (dla skip dodatkowo `level:skip:free|rewarded`).
- `level_stuck` — pokazanie `StuckPanel`; parametry: poziom, `moves_to_goal`. GA: `track_design("level:stuck", moves_to_goal)`.
- `booster_used` — cofnij poza darmowymi / probówka / podpowiedź / +3 cofnięcia; parametry: `type`, `source` (`free`/`coins`/`rewarded`). GA: `track_design("booster:<type>:<source>")` + przy monetach `track_resource("Sink", "coins", koszt, "economy", "<type>")` (przez `Economy.spend`).
- `rewarded_offered` / `rewarded_completed` — parametr: placement id z `docs/MONETIZATION.md` (`double_coins`, `extra_tube`, `undo_refill`, `skip_level`, `daily_x2`, `streak_save`). GA: `track_design("ads:rewarded:<placement>:offered|granted|skipped|unavailable")` (istniejący wzorzec w `Ads`).
- `interstitial_shown` — parametr: placement id `level_end`, numer poziomu. GA: `track_design("ads:interstitial:shown", level)` (istniejące).
- `daily_reward_claimed` — parametry: dzień streaka, `doubled` (bool). GA: `track_design("daily_reward:day_<n>[:x2]")` + `track_resource("Source", "coins", kwota, "economy", "daily_reward")`.
- `streak_changed` — parametry: `from`, `to`, `reason` (`continue`/`saved`/`reset`). GA: `track_design("streak:<reason>", to)`.
- `daily_challenge_complete` — parametry: dzień UTC, `moves`, `min_moves`. GA: progression `mode = daily` (wyżej) + `track_resource("Source", "coins", 50, "daily_challenge", "<utc_day>")`.
- `theme_unlocked` — parametry: `theme_id`, `source` (`coins`/`iap`). GA: `track_resource("Sink", "coins", koszt, "theme", theme_id)`.
- `coins_earned` — wygrana poziomu (raz na poziom, skill §7). GA: `track_resource("Source", "coins", kwota, "economy", "win")` (+ `perfect`, `rewarded`) przez `Economy.earn`.
- `iap_purchase` — parametry: sku, cena (centy), waluta. GA: `track_business(sku, amount_cents, currency)` (od T-026, `Purchases`).
- `consent_result` — wynik UMP / ATT. GA: `track_design("consent:ump:<status>")`, `track_design("consent:att:<status>")` przez `Ads.report_consent` (wywołania od Fazy 5).

## Otwarte pytania
*Pytania wymagające decyzji produktowej. Każde trafia też do `BACKLOG.md` → `## Pytania do Huberta`.*

1. Nazwa robocza „Vialo" — przyjęto: „Vialo: Water Sort Puzzle" (`docs/ASO.md`, wariant A), do zmiany; przed rejestracją w ASC/Play wymagane sprawdzenie EUIPO/UPRP.
2. Paleta płynów 12 kolorów per motyw (wyjątek od limitu 6 kolorów UI) — przyjęto: tak, do zmiany.
3. Dzień gry liczony w UTC (Poziom dnia zmienia się o 01:00/02:00 w PL i DE) — przyjęto: UTC dla wszystkich, do zmiany (alternatywa: lokalna północ, gorsza testowalność i „wspólny" poziom przestaje być wspólny).
4. `starter_pack` bez `remove_ads` (żeby nie kanibalizować `remove_ads`) — przyjęto: tak, do zmiany.
5. Brak rankingu/backendu dla Poziomu dnia w MVP — przyjęto: brak, do zmiany.
