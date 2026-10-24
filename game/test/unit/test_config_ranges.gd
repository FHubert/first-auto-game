extends GdUnitTestSuite

var _cfg: Node


func before_test() -> void:
	_cfg = auto_free(load("res://src/systems/config.gd").new())


func _ruled(key: String) -> bool:
	var v: Variant = _cfg.DEFAULTS[key]
	return v is int or v is float or v is Array


func test_every_numeric_default_has_rule_and_no_orphans() -> void:
	var missing: Array = []
	for key: String in _cfg.DEFAULTS:
		if _ruled(key) and not _cfg.RANGES.has(key) and not _cfg.ARRAY_RULES.has(key):
			missing.append(key)
	var orphans: Array = []
	for key: String in _cfg.RANGES:
		if not _cfg.DEFAULTS.has(key) or _cfg.DEFAULTS[key] is Array:
			orphans.append(key)
	for key: String in _cfg.ARRAY_RULES:
		if not _cfg.DEFAULTS.has(key):
			orphans.append(key)
	assert_array(missing).override_failure_message("missing rules: %s" % [missing]).is_empty()
	assert_array(orphans).override_failure_message("orphan rules: %s" % [orphans]).is_empty()


func test_all_defaults_within_ranges() -> void:
	var bad: Array = []
	for key: String in _cfg.DEFAULTS:
		if not _cfg._in_range(key, _cfg.DEFAULTS[key]):
			bad.append(key)
	assert_array(bad).override_failure_message("defaults out of range: %s" % [bad]).is_empty()


func test_out_of_range_values_rejected() -> void:
	var bad: Dictionary = {
		"solver_max_states": 1_000_000_000,
		"hint_cost_coins": -5,
		"levels_per_extra_color": 0,
		"tube_capacity": 99,
		"daily_reward_multipliers": [],
	}
	assert_int(_cfg.apply_remote(bad)).is_equal(0)
	for key: String in bad:
		assert_that(_cfg.get_value(key)).is_equal(_cfg.DEFAULTS[key])


func test_invariant_violation_rolls_back_batch() -> void:
	assert_int(_cfg.apply_remote({"colors_max": 14})).is_equal(0)
	# 12 + 4 + 1 > ACTION_BASE: in range per key, but breaks the invariant
	var batch: Dictionary = {"empty_tubes": 4, "starting_coins": 150}
	assert_int(_cfg.apply_remote(batch)).is_equal(0)
	assert_int(_cfg.get_value("colors_max")).is_equal(12)
	assert_int(_cfg.get_value("empty_tubes")).is_equal(2)
	assert_int(_cfg.get_value("starting_coins")).is_equal(100)


func test_valid_batch_applied() -> void:
	var batch: Dictionary = {"hint_cost_coins": 30, "rewarded_multiplier": 3, "colors_max": 10}
	assert_int(_cfg.apply_remote(batch)).is_equal(3)
	assert_float(_cfg.get_value("rewarded_multiplier")).is_equal(3.0)
	assert_int(_cfg.get_value("colors_max")).is_equal(10)


func test_colors_upper_bound_matches_theme_palette() -> void:
	# = liczba kolorów motywu (ThemeCatalog), tyle kształtów ma ColorSymbols
	for key: String in [
		"tutorial_colors", "colors_start", "colors_max", "daily_colors", "gen_exact_max_colors"
	]:
		assert_int(_cfg.RANGES[key][1]).is_equal(ColorSymbols.SHAPES)
	assert_int(_cfg.RANGES["colors_max"][1]).is_equal(12)
