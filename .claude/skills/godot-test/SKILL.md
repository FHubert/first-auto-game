---
name: godot-test
description: Uzyj przy pisaniu testow gdUnit4 v7, uruchamianiu make test / make playtest, czytaniu raportow i diagnozowaniu czerwonego CI. Mowi tez, kiedy test jest zly, a kiedy kod.
---

# godot-test — gdUnit4 v7, playtest bot, czerwone CI

Wersje: Godot 4.7.2 ↔ **gdUnit4 v7.0.0** (`GDUNIT_REF=master` w `Makefile`, bo tagów v7 jeszcze nie ma; po wydaniu przypnij tag v7.x). Addon jest klonowany przez `make setup` do `game/addons/gdUnit4/` (ignorowany przez git). Składnia CLI (`-a`, `-rd`, `-c`, `--ignoreHeadlessMode`) działa bez zmian w v7.

## 1. Struktura testu
Plik `game/test/unit/test_<nazwa>.gd`, klasa dziedziczy `GdUnitTestSuite`, funkcje `test_*` (prefiks obowiązkowy).
```gdscript
extends GdUnitTestSuite

var _cfg: Node


func before() -> void:            # raz na suitę
	pass

func before_test() -> void:       # przed każdym testem
	_cfg = auto_free(load("res://src/systems/config.gd").new())   # auto_free sprzątnie obiekt (brak orphan node)

func after_test() -> void:        # po każdym teście
	GameConfig.reset()

func after() -> void:             # raz na końcu
	pass


func test_apply_remote_overrides_known_keys() -> void:
	var applied: int = _cfg.apply_remote({"daily_reward_base": 80})
	assert_int(applied).is_equal(1)
	assert_int(_cfg.get_value("daily_reward_base")).is_equal(80)
```
Hooki: `before`, `after`, `before_test`, `after_test`. Obiekty tworzone w hookach zwalniaj albo owijaj w `auto_free(...)`, inaczej raport pokaże orphan nodes.

## 2. Asercje - 10 najczęstszych (składnia v7)
```gdscript
assert_int(x).is_equal(3)                    # też is_greater, is_less, is_between(1, 5), is_zero, is_not_negative
assert_float(x).is_equal_approx(23.2, 0.01)  # float ZAWSZE z tolerancją, nie is_equal
assert_bool(b).is_true()                     # is_false
assert_str(s).contains("abc")                # is_equal, starts_with, ends_with, is_empty, has_length(n)
assert_array(a).has_size(3)                  # contains([..]), contains_exactly([..]), contains_exactly_in_any_order, is_empty
assert_dict(d).contains_keys(["a", "b"])     # contains_key_value("a", 1), is_empty, has_size
assert_vector(v).is_equal_approx(Vector2(1, 2), Vector2(0.01, 0.01))
assert_object(o).is_not_null()               # is_null, is_instanceof(Node), is_same(o2)
assert_that(value).is_equal(x)               # gdy typ nieznany
await assert_signal(obj).is_emitted("door_opened")   # is_not_emitted; domyślny timeout 2 s, .wait_until(5000)
```
Błędy wykonania/`push_error`: `await assert_error(func(): kod()).is_push_error("komunikat")` (też `is_success()`, `is_runtime_error(msg)`, `is_push_warning(msg)`).
`await` wymaga `func test_x() -> void:` z `await` w środku - gdUnit obsługuje to sam.

## 3. Parametryzacja i fuzzery
```gdscript
# Parametryzacja: ostatni argument MUSI nazywać się test_parameters
func test_reward(level: int, expected: int, test_parameters := [[1, 10], [10, 11], [30, 13]]) -> void:
	assert_int(EconomyRules.new().reward_for_win(level)).is_equal(expected)

# Fuzzer: 1000 losowych wejść (domyślnie); argument musi zaczynać się od "fuzzer"
func test_difficulty_in_range(fuzzer := Fuzzers.rangei(1, 500), fuzzer_iterations := 200, fuzzer_seed := 42) -> void:
	var d: float = ContentGenerator.new().difficulty_curve(fuzzer.next_value())
	assert_float(d).is_between(0.1, 1.0)
```
Dostępne fuzzery: `Fuzzers.rangei(a,b)`, `eveni`, `oddi`, `rangev2`, `rangev3`, `rand_str(min,max,charset)`. Fuzzer tylko w GDScript. Zawsze podawaj `fuzzer_seed` (powtarzalność).
Mocki/spye: `var m := mock(MojaKlasa) as MojaKlasa`, `do_return(5).on(m).metoda()`, `verify(m, 1).metoda(any_int())`, `spy(instancja)`. Mock klasy z `class_name`; autoloadów nie mockuj - podmieniaj providera (Fake).
Scena: `var runner := scene_runner("res://src/core/main.tscn")`, `await runner.simulate_frames(10)`.

## 4. Testy z autoloadami - podmiana providera na Fake
```gdscript
func before_test() -> void:
	GameConfig.reset()
	_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = func() -> float: return _now[0]     # _now: Array[float], bo lambda nie modyfikuje zmiennej lokalnej

func test_interstitial_respects_min_seconds() -> void:
	assert_bool(_ads.maybe_show_interstitial(3)).is_true()
	_now[0] = 30.0
	assert_bool(_ads.maybe_show_interstitial(6)).is_false()
	assert_int(_provider.interstitials_shown).is_equal(1)
```
Zdarzenia analityki sprawdzaj przez `FakeAnalyticsProvider.events` (ustaw `Analytics.provider = FakeAnalyticsProvider.new()` i przywróć po teście).

## 5. `make test` i raport
```
make test   # godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit -rd res://test/reports -c
```
Kod wyjścia gdUnit: `0` = ok, `100` = są porażki, `101` = ostrzeżenia (orphany itp.). Flagi: `-a <katalog|plik>` (dodaj do uruchomienia), `-i <suite|suite:test>` (pomiń), `-c` (nie przerywaj po pierwszym błędzie), `-rd <katalog>` (raporty), `-rc <n>` (ile raportów trzymać, domyślnie 20).
Raport: `game/test/reports/report_N/results.xml` (JUnit) i `report_N/index.html`. Najnowszy = najwyższe N.
```
R=$(ls -d game/test/reports/report_* | sort -t_ -k2 -n | tail -1)
head -3 $R/results.xml                          # tests= failures= skipped=
grep -B1 -A6 '<failure' $R/results.xml          # treść porażek
```
Jeden test: `godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test/unit/test_ad_service.gd -rd res://test/reports -c` (binarka: `.tools/godot` lub `$GODOT_BIN`).
ZWERYFIKUJ przed użyciem: flaga `--ignoreHeadlessMode` jest w Makefile, ale nie występuje w dokumentacji CLI - sprawdź `--help-advanced` (https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/).

## 6. `make playtest` i `playtest.json`
`make playtest` = `godot --headless --path game -- --playtest --rounds=200 --seed=42 --report=<repo>/game/test/reports/playtest.json`. Inny seed/liczba rund: ta sama komenda z innymi `--seed=`/`--rounds=`. Exit code 1 przy softlocku lub błędzie kontraktu.
Format `playtest.json`:
```json
{ "rounds": 200, "wins": 6, "losses": 194, "softlocks": 0, "avg_steps": 10.96,
  "coins_end": 60, "interstitials_shown": 66, "errors": [] }
```
PASS = `softlocks == 0` i `errors == []` i `rounds == żądane`. `wins/rounds` to tylko sygnał balansu (bot gra losowo, więc niski win rate nie jest błędem softlocka, ale zgłoś go).
Bot (`game/test/integration/playtest_bot.gd`) wymaga kontraktu `GameRound.start(level_data) / step(action) -> bool / result() -> {won, score, steps}` i `ContentGenerator.generate(seed, level)`. Zmieniając te klasy, nie łam kontraktu.

## 7. Diagnoza czerwonego CI
```
gh pr list --state open --json number,headRefName,statusCheckRollup
gh run list --branch task/<ID> --limit 5
gh run view <run-id> --log-failed | tail -120
gh run download <run-id> -n test-reports -D /tmp/reports     # artefakt "test-reports" (14 dni)
```
Workflow `test.yml` robi kolejno: `make setup`, testy narzędzi python, `make lint`, `make test`, `make playtest`. Ustal, który krok padł, i odtwórz LOKALNIE tą samą komendą.

## 8. Test zły czy kod zły? (nie wolno "naprawiać" osłabieniem)
Test jest zły TYLKO gdy: (a) wymaga czegoś sprzecznego z GDD/KA zadania, (b) zależy od czasu/losowości/kolejności bez seeda, (c) ma błąd składni/typu, (d) testuje szczegół implementacji, który zadanie wprost zmienia. Wtedy popraw test i opisz powód w PR.
W każdym innym przypadku kod jest zły. ZABRONIONE: usuwanie/zakomentowanie asercji, `is_equal` → `is_greater`, poszerzanie tolerancji, `skip`/`-i`, zmiana oczekiwanej wartości na to, co kod akurat zwraca, wyłączanie testu w `Makefile`/workflow.
Flaky (raz zielony, raz czerwony) = brak seeda lub zależność od zegara: wstrzyknij seed/`clock`, nie dodawaj retry.
