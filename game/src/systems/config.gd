extends Node
## Autoload "GameConfig": all balance parameters, overridable by remote config.

const DEFAULTS: Dictionary = {
	# Ads
	"interstitial_every_n_rounds": 3,
	"interstitial_min_seconds": 90,
	"rewarded_multiplier": 2.0,
	# Economy
	"daily_reward_base": 50,
	"starting_coins": 0,
	"win_reward_coins": 10,
	# Session
	"session_target_seconds": 180,
	# Difficulty curve (logistic)
	"difficulty_min": 0.1,
	"difficulty_max": 1.0,
	"difficulty_midpoint_level": 20,
	"difficulty_steepness": 0.15,
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
