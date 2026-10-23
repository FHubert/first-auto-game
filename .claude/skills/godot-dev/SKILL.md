---
name: godot-dev
description: Uzyj przy kazdej zmianie kodu gry, scen .tscn lub autoloadow w game/ (GDScript 4, Godot 4.7). Zawiera strukture projektu, wzorce, bezpieczna edycje .tscn i checkliste przed PR.
---

# godot-dev — kod gry w Godot 4.7 / GDScript

Silnik przypięty w `Makefile` (`GODOT_VERSION ?= 4.7.2-stable`). Projekt: `game/` (`game/project.godot`, renderer `mobile`, viewport 720x1280 portrait).
Weryfikacja: `make test` (po każdej zmianie), `make check` (przed PR). Wcięcia w GDScript to TABY (gdformat).

## 1. Struktura projektu
| Ścieżka | Co tam jest |
|---|---|
| `game/src/core/` | stan i pętla: `game_state.gd`, `game_round.gd`, `save_system.gd`, `version.gd`, `main.gd`+`main.tscn` |
| `game/src/systems/` | `config.gd`, `ad_service.gd`+`ad_provider.gd`+`fake_ad_provider.gd`, `analytics_service.gd`+`analytics_provider.gd`+`fake_analytics_provider.gd`, `content_generator.gd` |
| `game/src/levels/`, `game/src/ui/` | sceny poziomów i UI (puste na starcie) |
| `game/assets/{sprites,audio,fonts}` | assety (zasady: skill `asset-gen`) |
| `game/test/unit/` | testy gdUnit4 `test_*.gd` |
| `game/test/integration/` | `playtest_bot.gd` (kontrakt bota: `start/step/result` w `GameRound`) |
| `game/test/reports/` | raporty (ignorowane przez git poza `.gitkeep`) |
Nowy plik logiki → `game/src/<katalog>/nazwa.gd`, test → `game/test/unit/test_nazwa.gd`.

## 2. GDScript 4 typowany — wzorce
Zawsze typy w zmiennych, argumentach i zwrotkach (lint tego pilnuje w stylu repo).
```gdscript
class_name EconomyRules
extends RefCounted
## Czysta logika (bez Node) - testowalna bez sceny.

signal coins_changed(new_total: int)

var coins: int = 0
var _history: Array[int] = []          # typowana tablica


func reward_for_win(level: int) -> int:
	var base: int = int(GameConfig.get_value("win_reward_coins", 10))   # ZERO magicznych liczb
	return base + level / 10                                           # int / int = int (ostrzeżenie INTEGER_DIVISION - użyj int(level / 10.0) gdy chcesz jawnie)


func add(amount: int) -> void:
	assert(amount >= 0, "amount must be >= 0")
	coins += amount
	coins_changed.emit(coins)
```
Zasady:
- `snake_case` funkcje/zmienne, `PascalCase` + `class_name` klasy, `UPPER_SNAKE` stałe, prywatne z `_`.
- Typy Variant tylko tam, gdzie API wymaga (`get_value()` zwraca Variant → rzutuj: `int(...)`, `float(...)`).
- `Dictionary` w repo jest nietypowany (Godot 4.7 ma typowane słowniki, ale trzymaj się stylu repo).
- Sygnały zamiast referencji między systemami: `signal x(arg: int)`, `x.emit(v)`, `obj.x.connect(callable)`.
- `@onready var _label: Label = $Build` dla węzłów sceny; `@export var speed: float = 1.0` dla parametrów edytora (balans NIE tu, tylko w `GameConfig`).
- Logika w `RefCounted`/`Resource` (np. `GameRound`, `GameState`), `Node` tylko cienka warstwa (UI, autoload).

## 3. Autoloady (`[autoload]` w `game/project.godot`)
| Nazwa globalna | Plik | Do czego |
|---|---|---|
| `GameConfig` | `src/systems/config.gd` | parametry balansu: `GameConfig.get_value("klucz", domyślna)`, `apply_remote(dict)`, `reset()` |
| `Analytics` | `src/systems/analytics_service.gd` | `Analytics.track_design("ads:rewarded:x:granted")`, `track_progression`, `track_business`, `track_resource` |
| `Ads` | `src/systems/ad_service.gd` | `Ads.maybe_show_interstitial(round_index)`, `Ads.request_rewarded(placement_id, on_reward_callable)` |
| `SaveSystem` | `src/core/save_system.gd` | `SaveSystem.save(state)`, `SaveSystem.load() -> GameState` (atomowy zapis JSON do `user://save.json`) |

Nowy parametr balansu: dopisz do `DEFAULTS` w `config.gd` (typ domyślnej wartości = typ klucza; `apply_remote` odrzuca niezgodne typy) i użyj `GameConfig.get_value`. `tools/balance_sim.py` czyta te same klucze.

### Jak testować kod używający autoloadów (mock/Fake)
Autoloady NIE są ładowane do instancji tworzonych w teście przez `load(...).new()`, ale globalne nazwy (`GameConfig`, `Analytics`, `Ads`) istnieją w drzewie testu. Wzorzec z repo (`test_ad_service.gd`):
```gdscript
_provider = FakeAdProvider.new()
_ads = auto_free(load("res://src/systems/ad_service.gd").new())   # świeża instancja serwisu
_ads.provider = _provider            # podmiana providera na Fake
_ads.clock = func() -> float: return _now[0]   # sztuczny zegar zamiast czasu realnego
```
- Reklamy: `FakeAdProvider` (`always_ready`, `reward_on_show`, liczniki `rewarded_shown`). Prawdziwy SDK reklam to kolejna klasa `extends AdProvider` (ADR-003).
- Analityka: `FakeAnalyticsProvider.events` zbiera zdarzenia; `Analytics` w trybie headless sam wybiera Fake.
- Config: w `before_test()`/`after_test()` wołaj `GameConfig.reset()`, nadpisuj przez `GameConfig.apply_remote({...})`.
- Zapis: ustaw `SaveSystem.save_path = "user://test_save.json"` i sprzątaj plik po teście.
- Czas: nigdy `Time.get_ticks_msec()` bezpośrednio w logice - wstrzykuj `Callable` (jak `Ads.clock`).

## 4. Edycja `.tscn` jako tekstu (ostrożnie)
Format (Godot 4): nagłówek `[gd_scene load_steps=N format=3 uid="uid://..."]`, potem `[ext_resource ...]`, `[sub_resource ...]`, `[node ...]`, `[connection ...]`. `load_steps` = liczba zasobów + 1 (zła wartość nie psuje ładowania, ale popraw).
Istniejący przykład (`src/core/main.tscn`):
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/main.gd" id="1_main"]

[node name="Main" type="Control"]
script = ExtResource("1_main")

[node name="Build" type="Label" parent="."]
text = "Build"
```
Reguły:
1. NIGDY nie zmieniaj ani nie usuwaj istniejących `uid="uid://..."` (w nagłówku sceny ani w `[ext_resource]`). UID trzyma referencje, gdy pliki się przesuwają.
2. NIE usuwaj `[ext_resource]`, którego `id` jest jeszcze użyte (`grep -n 'ExtResource("id")'`).
3. Nowy zasób → nowy `[ext_resource ... id="2_xxxxx"]` z UNIKALNYM id w pliku (np. `2_btn`), `load_steps` +1. UID dla nowego zasobu możesz pominąć (Godot doda go przy pierwszym zapisie/imporcie) - nie wymyślaj `uid://` ręcznie.
4. Dodanie węzła: nowy blok `[node name="Start" type="Button" parent="."]` PO węźle-rodzicu. Korzeń nie ma `parent=`. Dzieci korzenia: `parent="."`, wnuki: `parent="Rodzic"`, głębiej `parent="A/B"`.
5. Pliki Godota wymagają zgodności: węzeł w `parent=` musi już istnieć wyżej w pliku; nazwy rodzeństwa unikalne.
6. Skrypt do węzła: `[ext_resource type="Script" path="res://src/ui/start.gd" id="2_start"]` + `script = ExtResource("2_start")` w węźle.
7. Po edycji ZAWSZE `make test`, a przy zmianach UI: `godot --headless --path game --quit` ładuje projekt (błędy parsowania sceny wypiszą się w logu).
8. Preferuj budowanie UI w kodzie/małych scenach niż wielkie ręczne edycje; sceny >100 linii edytuj tylko dopisując bloki na końcu.

## 5. Pliki `.uid` i `.import` (Godot 4.7)
- Każdy `.gd` (i shader) ma obok plik `nazwa.gd.uid` generowany przy pierwszym zapisie/imporcie. **Commituj je** (nie dodawaj `*.uid` do `.gitignore`); przenosząc/usuwając skrypt poza Godotem, rusz też jego `.uid`.
- Assety importowane (`.png`, `.wav`, `.ttf`) mają obok `nazwa.png.import` — też commitowane. Ignorowany jest tylko katalog `game/.godot/`.
- Nowy `.gd` utworzony ręcznie nie ma jeszcze `.uid`: uruchom `make test` albo `godot --headless --path game --import` i dołącz powstałe `.uid` do commita.

## 6. Pułapki headless (CI nie ma ekranu ani GPU)
- Logika gry nie może używać `Input`, `Viewport`, `get_window()`, `DisplayServer` (poza detekcją trybu), `await get_tree().create_timer()` bez potrzeby. Wejście wstrzykuj przez argumenty/sygnały.
- Wykrywanie headless: `DisplayServer.get_name() == "headless"` (tak robią `Ads`/`Analytics` → wybierają Fake).
- `get_tree().quit(code)` kończy proces z kodem (używa tego `main.gd` w trybie `--playtest`). Argumenty po `--`: `OS.get_cmdline_user_args()`.
- `push_error()` w testach bywa traktowany jako błąd - nie zostawiaj go w ścieżkach, które test uruchamia celowo.
- `assert()` działa tylko w buildach debug; walidacja wejścia, na której polega gra, musi być zwykłym `if`.
- Losowość: zawsze `RandomNumberGenerator` z `seed` (deterministyczne testy i bot), nigdy `randi()` globalne w logice.
- Zapis: `user://` (nie `res://`, które na urządzeniu jest tylko do odczytu).

## 7. Checklista przed PR
- [ ] Zmienione tylko pliki ze specyfikacji; < ~300 linii kodu.
- [ ] Typowane sygnatury i zmienne; brak magicznych liczb (balans → `GameConfig.DEFAULTS`).
- [ ] Nowa logika ma test w `game/test/unit/` (skill `godot-test`); nic nie osłabione.
- [ ] Nowy `.gd` ma `.uid`; `.tscn` bez zmienionych `uid://`.
- [ ] Nowa mechanika → sekcja w `docs/GDD.md`; nowy ekran → wpis (1 scena na linię, `res://...tscn`) w `tools/screens.txt`, który czyta `tools/gen_screenshots.sh`; decyzja architektoniczna → ADR.
- [ ] Brak nowych addonów (ADR-007), brak zmian w `project.godot` poza `[autoload]`, `[input]`, `[display]`.
- [ ] `make check` zielone (lint + test + export-check) - wklej wynik do PR.

Źródła: docs.godotengine.org/en/4.7/contributing/development/file_formats/tscn.html; godotengine.org/article/uid-changes-coming-to-godot-4-4/ (pliki .uid).
