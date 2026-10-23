class_name ContentGenerator
extends RefCounted
## Genre-independent level generator placeholder. Deterministic per (seed, level).


func generate(seed_value: int, level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + level * 7919
	return {
		"seed": seed_value,
		"level": level,
		"difficulty": difficulty_curve(level),
		# Genre-specific content goes here; "variant" is a placeholder roll.
		"payload": {"variant": rng.randi_range(0, 99)},
	}


## TODO: real solvability check once a genre exists.
func is_solvable(_level_data: Dictionary) -> bool:
	return true


## Level parameters from GameConfig (colors, tubes, breather, difficulty, min moves).
func level_params(level: int) -> Dictionary:
	var colors: int = int(GameConfig.get_value("tutorial_colors", 2))
	if level > 1:
		var per_extra: int = maxi(1, int(GameConfig.get_value("levels_per_extra_color", 6)))
		var extra: int = (level - 2) / per_extra
		colors = mini(
			int(GameConfig.get_value("colors_max", 12)),
			int(GameConfig.get_value("colors_start", 3)) + extra
		)
	var every: int = maxi(1, int(GameConfig.get_value("breather_every", 5)))
	var breather: bool = level % every == 0
	var d: float = difficulty_curve(level)
	if breather:
		d *= float(GameConfig.get_value("breather_factor", 0.65))
	d = clampf(d, 0.0, 1.0)
	var easy: float = float(GameConfig.get_value("min_moves_factor_easy", 1.2))
	var hard: float = float(GameConfig.get_value("min_moves_factor_hard", 2.0))
	var empty: int = int(GameConfig.get_value("empty_tubes", 2))
	return {
		"level": level,
		"capacity": int(GameConfig.get_value("tube_capacity", 4)),
		"empty_tubes": empty,
		"colors": colors,
		"tubes": colors + empty,
		"breather": breather,
		"difficulty": d,
		"min_moves_floor": ceili(colors * lerpf(easy, hard, d)),
	}


## Parameters for the Daily Level (level 0, fixed colors and move factor).
func daily_params(utc_day: int) -> Dictionary:
	var colors: int = int(GameConfig.get_value("daily_colors", 8))
	var factor: float = float(GameConfig.get_value("daily_min_moves_factor", 1.8))
	var easy: float = float(GameConfig.get_value("min_moves_factor_easy", 1.2))
	var hard: float = float(GameConfig.get_value("min_moves_factor_hard", 2.0))
	var empty: int = int(GameConfig.get_value("empty_tubes", 2))
	var span: float = maxf(hard - easy, 0.0001)
	return {
		"level": 0,
		"utc_day": utc_day,
		"capacity": int(GameConfig.get_value("tube_capacity", 4)),
		"empty_tubes": empty,
		"colors": colors,
		"tubes": colors + empty,
		"breather": false,
		"difficulty": clampf((factor - easy) / span, 0.0, 1.0),
		"min_moves_floor": ceili(colors * factor),
	}


## Logistic curve between difficulty_min and difficulty_max (all from GameConfig).
func difficulty_curve(level: int) -> float:
	var d_min: float = float(GameConfig.get_value("difficulty_min", 0.1))
	var d_max: float = float(GameConfig.get_value("difficulty_max", 1.0))
	var mid: float = float(GameConfig.get_value("difficulty_midpoint_level", 20))
	var k: float = float(GameConfig.get_value("difficulty_steepness", 0.15))
	return d_min + (d_max - d_min) / (1.0 + exp(-k * (float(level) - mid)))
