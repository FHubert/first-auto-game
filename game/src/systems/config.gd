extends Node
## Autoload "GameConfig": all balance parameters, overridable by remote config.

const DEFAULTS: Dictionary = {
	# Ads
	"interstitial_every_n_rounds": 3,
	"interstitial_min_seconds": 90,
	"rewarded_multiplier": 2.0,
	# Economy
	"daily_reward_base": 50,
	"starting_coins": 100,
	"win_reward_coins": 10,
	# Economy (GDD v1.0)
	"par_bonus_coins": 5,
	"hint_cost_coins": 25,
	"extra_tube_cost_coins": 60,
	"undo_refill_cost_coins": 20,
	"theme_cost_base": 600,
	"theme_cost_growth": 1.8,
	"daily_challenge_coins": 50,
	"daily_unlock_level": 3,
	# Session
	"session_target_seconds": 180,
	# Difficulty curve (logistic)
	"difficulty_min": 0.1,
	"difficulty_max": 1.0,
	"difficulty_midpoint_level": 20,
	"difficulty_steepness": 0.15,
	# Generator / progression (GDD v1.0)
	"tube_capacity": 4,
	"empty_tubes": 2,
	"tutorial_colors": 2,
	"colors_start": 3,
	"colors_max": 12,
	"levels_per_extra_color": 6,
	"breather_every": 5,
	"breather_factor": 0.65,
	"min_moves_factor_easy": 1.2,
	"min_moves_factor_hard": 2.0,
	"gen_max_attempts": 20,
	"solver_max_states": 50000,
	"solver_fallback_weight": 3.0,
	"campaign_seed": 1,
	"daily_seed_salt": 104729,
	"daily_colors": 8,
	"daily_min_moves_factor": 1.8,
	# Round / boosters (GDD v1.0)
	"undo_free_per_level": 3,
	"undo_refill_amount": 3,
	"extra_tube_max_per_level": 1,
	"skip_unlock_restarts": 2,
	"par_slack_moves": 2,
	"hint_solver_max_states": 20000,
}

var _values: Dictionary = DEFAULTS.duplicate(true)


func get_value(key: String, default: Variant = null) -> Variant:
	return _values.get(key, default)


## Overrides known keys only; wrong types are skipped. Returns applied count.
func apply_remote(remote: Dictionary) -> int:
	var applied: int = 0
	for key: Variant in remote:
		if typeof(key) != TYPE_STRING or not DEFAULTS.has(key):
			continue
		var converted: Variant = _coerce(DEFAULTS[key], remote[key])
		if converted == null:
			push_warning("GameConfig: ignoring remote '%s' (bad type)" % key)
			continue
		_values[key] = converted
		applied += 1
	return applied


func reset() -> void:
	_values = DEFAULTS.duplicate(true)


## Returns value converted to the default's type, or null if incompatible.
func _coerce(default: Variant, value: Variant) -> Variant:
	var want: int = typeof(default)
	var got: int = typeof(value)
	if want == got:
		return value
	if want == TYPE_FLOAT and got == TYPE_INT:
		return float(value)
	if want == TYPE_INT and got == TYPE_FLOAT and is_equal_approx(value, roundf(value)):
		return int(value)
	return null
