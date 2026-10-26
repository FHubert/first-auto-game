extends GdUnitTestSuite

## T-313: strażnik FTUE w `make check`. Poziomy kampanii 1-7 wygrywalne przez greedy w 1. próbie,
## bez utknięcia, dla DEFAULTS i każdej paczki docs/remote_config/*.json.

## Decyzja 10 / T-298 (GDD `## Progresja`): bramka 1-7 = 100 % wygranych w 1. próbie.
const FTUE_LEVELS: int = 7
## Seedy rng bota greedy (jak pomiar T-162).
const SEEDS: Array[int] = [42, 7, 1]
## Limit ruchów = MOVES_FACTOR * min_moves (baza T-298 + decyzja 10).
const MOVES_FACTOR: int = 3
## Bezpiecznik pętli gry (pętla bez postępu bez utknięcia).
const MAX_PLAY_STEPS: int = 600
## nazwa paczki -> powód + link do EXP, gdy paczka celowo zmienia level_params 1-7. Dziś puste.
const PARAMS_EXCEPTIONS: Dictionary = {}


func before_test() -> void:
	GameConfig.reset()


func after_test() -> void:
	GameConfig.reset()


func _dir() -> String:
	return (
		ProjectSettings.globalize_path("res://").path_join("../docs/remote_config").simplify_path()
	)


## DEFAULTS + po jednej konfiguracji na plik JSON (lista z katalogu, nie zaszyta).
func _configs() -> Dictionary:
	var out: Dictionary = {"DEFAULTS": {}}
	var dir: String = _dir()
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() != "json":
			continue
		var file: FileAccess = FileAccess.open(dir.path_join(f), FileAccess.READ)
		assert_object(file).is_not_null()
		out[f.get_basename()] = JSON.parse_string(file.get_as_text())
	return out


func _apply(pkg: Dictionary) -> void:
	GameConfig.reset()
	if not pkg.is_empty():
		GameConfig.apply_remote(pkg)


## Gra greedy poziom `level` z payloadu; zwraca listę naruszeń (pusta = OK).
func _play(tag: String, level_data: Dictionary, seed: int) -> Array[String]:
	var errs: Array[String] = []
	var rnd := GameRound.new()
	rnd.start(level_data)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var prev: Vector2i = Vector2i(-1, -1)
	var steps: int = 0
	while not rnd.is_done() and steps < MAX_PLAY_STEPS:
		if rnd.is_stuck():
			errs.append("%s: stuck after %d moves" % [tag, rnd.moves()])
			return errs
		var m: Vector2i = PlaytestBot.pick_greedy(rnd.board(), rnd.board().legal_moves(), prev, rng)
		prev = m
		rnd.try_move(m.x, m.y)
		steps += 1
	if not rnd.is_done() or not bool(rnd.result()["won"]):
		errs.append("%s: not won at 1st attempt (%d moves)" % [tag, rnd.moves()])
	elif rnd.moves() > MOVES_FACTOR * rnd.min_moves():
		errs.append(
			"%s: %d moves > %d x min_moves %d" % [tag, rnd.moves(), MOVES_FACTOR, rnd.min_moves()]
		)
	return errs


## Strażnik: naruszenia dla paczki `pkg` (nazwa `config_name`) i seeda rng, poziomy 1..FTUE_LEVELS.
func _check(config_name: String, pkg: Dictionary, seed: int) -> Array[String]:
	var errs: Array[String] = []
	_apply(pkg)
	var campaign_seed: int = int(GameConfig.get_value("campaign_seed"))
	for level: int in range(1, FTUE_LEVELS + 1):
		var data: Dictionary = ContentGenerator.new().generate(campaign_seed, level)
		var tag: String = "%s level %d seed %d" % [config_name, level, seed]
		errs.append_array(_play(tag, data, seed))
	GameConfig.reset()
	return errs


func test_ftue_levels_winnable_first_attempt() -> void:
	var configs: Dictionary = _configs()
	for name: String in configs:
		for seed: int in SEEDS:
			var errs: Array[String] = _check(name, configs[name], seed)
			assert_array(errs).override_failure_message("\n".join(errs)).is_empty()


func test_level_params_identical_to_defaults() -> void:
	GameConfig.reset()
	var base: Array[Dictionary] = []
	for n: int in range(1, FTUE_LEVELS + 1):
		base.append(ContentGenerator.new().level_params(n))
	var configs: Dictionary = _configs()
	for name: String in configs:
		if PARAMS_EXCEPTIONS.has(name):
			continue
		_apply(configs[name])
		for n: int in range(1, FTUE_LEVELS + 1):
			var got: Dictionary = ContentGenerator.new().level_params(n)
			var msg: String = "%s level %d: level_params differ from DEFAULTS" % [name, n]
			assert_dict(got).override_failure_message(msg).is_equal(base[n - 1])
		GameConfig.reset()


## RANGES nie pozwala zepsuć poziomów 1-7 (empty_tubes 0 generuje fallback z mniejszą liczbą
## kolorów), więc negatyw = ręczny poziom bez pustych probówek przez ten sam helper `_play`.
func test_guard_detects_stuck_level() -> void:
	var data: Dictionary = {"payload": {"tubes": [[0, 1], [1, 0]], "capacity": 2, "min_moves": 3}}
	var errs: Array[String] = _play("broken_pkg level 1 seed 42", data, SEEDS[0])
	assert_array(errs).has_size(1)
	assert_str(errs[0]).contains("broken_pkg").contains("level 1").contains("stuck")
