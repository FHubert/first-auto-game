class_name ContentGenerator
extends RefCounted
## Water-sort level generator: seeded shuffle + solver, regenerates seed+attempt.
## Deterministic per (seed, level), see ADR-009.

## Multipliers of the integer seed mix (own function: builtin hash() may change
## between engine versions, see ADR-009).
const MIX_MUL_A: int = 0x9E3779B1
const MIX_MUL_B: int = 0x85EBCA6B
const MIX_MUL_C: int = 0xC2B2AE35
const MIX_MASK: int = 0x7FFFFFFF
const MIX_SHIFT: int = 15
const MIN_COLORS: int = 2

## Migawka konfiguracji (GameConfig.snapshot()): generator NIE czyta GameConfig, wiec moze
## dzialac na watku roboczym bez wyscigu z reset()/apply_remote() (ADR-015).
var _snapshot: Dictionary = {}


## Bez argumentu: migawka z chwili utworzenia (wolac na watku glownym).
func _init(snapshot: Dictionary = {}) -> void:
	_snapshot = snapshot if not snapshot.is_empty() else GameConfig.snapshot()


## Level for (seed, level) in the ADR-009 contract: {seed, level, difficulty, payload}.
func generate(seed_value: int, level: int) -> Dictionary:
	var params: Dictionary = level_params(level)
	var data: Dictionary = _generate_with_params(_mix(seed_value, level), params, level)
	return {
		"seed": seed_value,
		"level": level,
		"difficulty": params["difficulty"],
		"payload": data,
	}


## Daily Level for a UTC day number (level 0, seed from daily_seed_salt).
func generate_daily(utc_day: int) -> Dictionary:
	var params: Dictionary = daily_params(utc_day)
	var salt: int = _cfg_int("daily_seed_salt")
	var data: Dictionary = _generate_with_params(_mix(salt, utc_day), params, 0)
	return {
		"seed": salt,
		"level": 0,
		"utc_day": utc_day,
		"difficulty": params["difficulty"],
		"payload": data,
	}


## Payload must be solvable and its stored solution must replay to a win.
func is_solvable(level_data: Dictionary) -> bool:
	var payload: Dictionary = level_data.get("payload", {})
	if int(payload.get("min_moves", 0)) <= 0:
		return false
	var solution: Array[Vector2i] = []
	for m in payload.get("solution", []):
		solution.append(m)
	return SortSolver.replay(SortBoard.from_payload(payload), solution)


## Deterministic integer mix of two values into a non-negative 31-bit seed.
func _mix(a: int, b: int) -> int:
	var h: int = (a * MIX_MUL_A + b * MIX_MUL_B) & MIX_MASK
	h = ((h ^ (h >> MIX_SHIFT)) * MIX_MUL_C) & MIX_MASK
	return (h ^ (h >> MIX_SHIFT)) & MIX_MASK


func _generate_with_params(level_seed: int, params: Dictionary, level: int) -> Dictionary:
	# level 0 = Poziom dnia (osobny limit kolorów exact, T-180)
	var exact_colors: int = (
		_cfg_int("gen_exact_max_colors_daily") if level == 0 else _cfg_int("gen_exact_max_colors")
	)
	var result: Dictionary = _search(level_seed, params, exact_colors)
	if result.is_empty():
		push_error("ContentGenerator: no solvable board for level %d, fewer colors" % level)
		var reduced: Dictionary = params.duplicate()
		var colors: int = maxi(MIN_COLORS, int(params["colors"]) - 1)
		reduced["colors"] = colors
		reduced["tubes"] = colors + int(params["empty_tubes"])
		reduced["min_moves_floor"] = mini(int(params["min_moves_floor"]), colors)
		result = _search(level_seed, reduced, exact_colors)
		result["fallback"] = true
		if not result.has("tubes"):
			result = _empty_payload(reduced)
			result["fallback"] = true
	return result


## Tries gen_max_attempts shuffles; returns the first board reaching the floor,
## else the best solvable one, else {}.
func _search(level_seed: int, params: Dictionary, exact_max_colors: int) -> Dictionary:
	var max_states: int = _cfg_int("solver_max_states")
	# Cheap pass first: boards the solver cannot crack quickly are skipped (reshuffled).
	var quick_budget: int = _cfg_int("gen_quick_state_budget")
	var quick: Dictionary = _search_pass(
		level_seed, params, mini(max_states, quick_budget), exact_max_colors
	)
	if not quick.is_empty():
		return quick
	return _search_pass(level_seed, params, max_states, exact_max_colors)


## One pass over the attempts with `max_states` for both exact and weighted solves.
func _search_pass(
	level_seed: int, params: Dictionary, max_states: int, exact_max_colors: int
) -> Dictionary:
	var attempts: int = _cfg_int("gen_max_attempts")
	var weight: float = _cfg_float("solver_fallback_weight")
	var floor_moves: int = int(params["min_moves_floor"])
	var best: Dictionary = {}
	var best_moves: int = 0
	for attempt in attempts:
		var tubes: Array = _deal(level_seed + attempt, params)
		var board := SortBoard.new(tubes, int(params["capacity"]))
		if _is_trivial(board):
			continue
		# Exact A* is too slow on big boards (~0.4 ms/state), so try a small budget first.
		var res: Dictionary = {"moves": SortSolver.NO_SOLUTION, "exact": false}
		if int(params["colors"]) <= exact_max_colors:
			var exact_budget: int = _cfg_int("gen_exact_state_budget")
			res = SortSolver.solve(board, mini(max_states, exact_budget))
		if int(res["moves"]) == SortSolver.NO_SOLUTION and not res["exact"]:
			res = SortSolver.solve(board, max_states, weight)
		var moves: int = int(res["moves"])
		if moves <= 0:
			continue
		var candidate: Dictionary = {
			"capacity": int(params["capacity"]),
			"colors": int(params["colors"]),
			"tubes": tubes,
			"min_moves": moves,
			"min_moves_exact": bool(res["exact"]),
			"min_moves_floor": floor_moves,
			"attempt": attempt,
			"solution": res["path"],
			"expanded": int(res["expanded"]),
		}
		if moves >= floor_moves:
			return candidate
		if moves > best_moves:
			best_moves = moves
			best = candidate
	return best


## Fisher-Yates shuffle (only randi() % n) dealt into full tubes plus empty ones.
func _deal(rng_seed: int, params: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var capacity: int = int(params["capacity"])
	var colors: int = int(params["colors"])
	var units: Array[int] = []
	for c in colors:
		for _k in capacity:
			units.append(c)
	for i in range(units.size() - 1, 0, -1):
		var j: int = int(rng.randi() % (i + 1))
		var tmp: int = units[i]
		units[i] = units[j]
		units[j] = tmp
	var tubes: Array = []
	for t in colors:
		tubes.append(units.slice(t * capacity, (t + 1) * capacity))
	for _e in int(params["empty_tubes"]):
		tubes.append([])
	return tubes


func _is_trivial(board: SortBoard) -> bool:
	if board.is_won():
		return true
	for i in board.tube_count():
		if board.is_full(i) and board.is_uniform(i):
			return true
	return false


func _empty_payload(params: Dictionary) -> Dictionary:
	return {
		"capacity": int(params["capacity"]),
		"colors": int(params["colors"]),
		"tubes": [],
		"min_moves": 0,
		"min_moves_exact": false,
		"min_moves_floor": int(params["min_moves_floor"]),
		"attempt": 0,
		"solution": [] as Array[Vector2i],
	}


## Level parameters from GameConfig (colors, tubes, breather, difficulty, min moves).
func level_params(level: int) -> Dictionary:
	var colors: int = _cfg_int("tutorial_colors")
	if level > 1:
		var per_extra: int = maxi(1, _cfg_int("levels_per_extra_color"))
		var extra: int = (level - 2) / per_extra
		colors = mini(_cfg_int("colors_max"), _cfg_int("colors_start") + extra)
	var every: int = maxi(1, _cfg_int("breather_every"))
	var breather: bool = level % every == 0
	var d: float = difficulty_curve(level)
	if breather:
		d *= _cfg_float("breather_factor")
	d = clampf(d, 0.0, 1.0)
	var easy: float = _cfg_float("min_moves_factor_easy")
	var hard: float = _cfg_float("min_moves_factor_hard")
	var empty: int = _cfg_int("empty_tubes")
	return {
		"level": level,
		"capacity": _cfg_int("tube_capacity"),
		"empty_tubes": empty,
		"colors": colors,
		"tubes": colors + empty,
		"breather": breather,
		"difficulty": d,
		"min_moves_floor": ceili(colors * lerpf(easy, hard, d)),
	}


## Parameters for the Daily Level (level 0, fixed colors and move factor).
func daily_params(utc_day: int) -> Dictionary:
	var colors: int = _cfg_int("daily_colors")
	var factor: float = _cfg_float("daily_min_moves_factor")
	var easy: float = _cfg_float("min_moves_factor_easy")
	var hard: float = _cfg_float("min_moves_factor_hard")
	var empty: int = _cfg_int("empty_tubes")
	var span: float = maxf(hard - easy, 0.0001)
	return {
		"level": 0,
		"utc_day": utc_day,
		"capacity": _cfg_int("tube_capacity"),
		"empty_tubes": empty,
		"colors": colors,
		"tubes": colors + empty,
		"breather": false,
		"difficulty": clampf((factor - easy) / span, 0.0, 1.0),
		"min_moves_floor": ceili(colors * factor),
	}


## Logistic curve between difficulty_min and difficulty_max (all from GameConfig).
func difficulty_curve(level: int) -> float:
	var d_min: float = _cfg_float("difficulty_min")
	var d_max: float = _cfg_float("difficulty_max")
	var mid: float = _cfg_float("difficulty_midpoint_level")
	var k: float = _cfg_float("difficulty_steepness")
	return d_min + (d_max - d_min) / (1.0 + exp(-k * (float(level) - mid)))


func _cfg_int(key: String) -> int:
	return int(_snapshot[key])


func _cfg_float(key: String) -> float:
	return float(_snapshot[key])
