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


## Logistic curve between difficulty_min and difficulty_max (all from GameConfig).
func difficulty_curve(level: int) -> float:
	var d_min: float = float(GameConfig.get_value("difficulty_min", 0.1))
	var d_max: float = float(GameConfig.get_value("difficulty_max", 1.0))
	var mid: float = float(GameConfig.get_value("difficulty_midpoint_level", 20))
	var k: float = float(GameConfig.get_value("difficulty_steepness", 0.15))
	return d_min + (d_max - d_min) / (1.0 + exp(-k * (float(level) - mid)))
