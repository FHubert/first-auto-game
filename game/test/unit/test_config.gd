extends GdUnitTestSuite

var _cfg: Node


func before_test() -> void:
	_cfg = auto_free(load("res://src/systems/config.gd").new())


func test_defaults_present() -> void:
	assert_int(_cfg.get_value("interstitial_every_n_rounds")).is_equal(5)
	assert_int(_cfg.get_value("interstitial_min_seconds")).is_equal(120)
	assert_int(_cfg.get_value("interstitial_min_level")).is_equal(8)
	assert_float(_cfg.get_value("rewarded_multiplier")).is_equal(2.0)
	assert_int(_cfg.get_value("daily_reward_base")).is_equal(50)
	assert_int(_cfg.get_value("starting_coins")).is_equal(100)
	assert_int(_cfg.get_value("session_target_seconds")).is_equal(180)


func test_get_value_unknown_returns_default() -> void:
	assert_that(_cfg.get_value("nope")).is_null()
	assert_int(_cfg.get_value("nope", 7)).is_equal(7)


func test_apply_remote_overrides_known_keys() -> void:
	var applied: int = _cfg.apply_remote({"daily_reward_base": 80})
	assert_int(applied).is_equal(1)
	assert_int(_cfg.get_value("daily_reward_base")).is_equal(80)


func test_apply_remote_ignores_unknown_keys() -> void:
	assert_int(_cfg.apply_remote({"unknown_key": 1})).is_equal(0)
	assert_that(_cfg.get_value("unknown_key")).is_null()


func test_apply_remote_ignores_bad_types() -> void:
	var bad: Dictionary = {"daily_reward_base": "lots", "rewarded_multiplier": [1]}
	assert_int(_cfg.apply_remote(bad)).is_equal(0)
	assert_int(_cfg.get_value("daily_reward_base")).is_equal(50)
	assert_float(_cfg.get_value("rewarded_multiplier")).is_equal(2.0)


func test_apply_remote_converts_numeric_types() -> void:
	_cfg.apply_remote({"rewarded_multiplier": 3, "daily_reward_base": 60.0})
	assert_float(_cfg.get_value("rewarded_multiplier")).is_equal(3.0)
	assert_int(_cfg.get_value("daily_reward_base")).is_equal(60)


func test_reset_restores_defaults() -> void:
	_cfg.apply_remote({"daily_reward_base": 99})
	_cfg.reset()
	assert_int(_cfg.get_value("daily_reward_base")).is_equal(50)
