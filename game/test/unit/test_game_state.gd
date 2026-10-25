extends GdUnitTestSuite


func test_round_trip() -> void:
	var s := GameState.new()
	s.coins = 120
	s.level = 7
	s.streak_days = 3
	s.last_play_utc_day = 20000
	s.settings = {"sound": true}
	var copy: GameState = GameState.from_dict(s.to_dict())
	assert_object(copy).is_not_null()
	assert_int(copy.coins).is_equal(120)
	assert_int(copy.level).is_equal(7)
	assert_int(copy.streak_days).is_equal(3)
	assert_int(copy.last_play_utc_day).is_equal(20000)
	assert_bool(copy.settings["sound"]).is_true()
	assert_bool(copy.settings["music_on"]).is_true()


func test_to_dict_has_schema_version() -> void:
	assert_int(GameState.new().to_dict()["schema_version"]).is_equal(GameState.SCHEMA_VERSION)


func test_from_dict_accepts_json_floats() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["coins"] = 5.0
	var s: GameState = GameState.from_dict(d)
	assert_object(s).is_not_null()
	assert_int(s.coins).is_equal(5)


func test_migrate_v3_is_noop() -> void:
	var d: Dictionary = GameState.new().to_dict()
	assert_dict(GameState.migrate(d)).is_equal(d)


func test_migrate_v2_to_v3_adds_empty_round() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["schema_version"] = 2
	d["level"] = 9
	d.erase("round_in_progress")
	var m: Dictionary = GameState.migrate(d)
	assert_int(m["schema_version"]).is_equal(3)
	assert_dict(m["round_in_progress"]).is_empty()
	var s: GameState = GameState.from_dict(d)
	assert_object(s).is_not_null()
	assert_dict(s.round_in_progress).is_empty()
	assert_int(s.level).is_equal(9)


func test_round_snapshot_survives_state_round_trip() -> void:
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(1, 3))
	for args: Array in [["daily", 20750, 20750], ["campaign", 7, 0]]:
		var s := GameState.new()
		s.round_in_progress = GameState.round_snapshot(args[0], args[1], args[2], r)
		var copy: GameState = GameState.from_dict(s.to_dict())
		var rip: Dictionary = copy.round_in_progress
		assert_str(rip["mode"]).is_equal(args[0])
		assert_int(rip["level_no"]).is_equal(args[1])
		assert_int(rip["utc_day"]).is_equal(args[2])
		assert_object(GameRound.from_dict(rip["round"])).is_not_null()


func test_bad_round_in_progress_type_resets_keeps_level() -> void:
	var s: GameState = _with("round_in_progress", "oops")
	assert_object(s).is_not_null()
	assert_dict(s.round_in_progress).is_empty()
	assert_int(s.level).is_equal(17)


func test_migrate_adds_missing_version() -> void:
	var migrated: Dictionary = GameState.migrate({"coins": 1})
	assert_int(migrated["schema_version"]).is_equal(GameState.SCHEMA_VERSION)


func _with(key: String, value: Variant) -> GameState:
	var d: Dictionary = GameState.new().to_dict()
	d["level"] = 17
	d[key] = value
	return GameState.from_dict(d)


func test_bad_coins_type_resets_coins_keeps_level() -> void:
	var s: GameState = _with("coins", "abc")
	assert_object(s).is_not_null()
	assert_int(s.coins).is_equal(0)
	assert_int(s.level).is_equal(17)


func test_non_integral_level_resets_level_keeps_coins() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["coins"] = 50
	d["level"] = 2.5
	var s: GameState = GameState.from_dict(d)
	assert_int(s.level).is_equal(1)
	assert_int(s.coins).is_equal(50)


func test_bad_settings_container_resets_settings_keeps_level() -> void:
	var s: GameState = _with("settings", [])
	assert_dict(s.settings).is_equal(GameState.DEFAULT_SETTINGS)
	assert_int(s.level).is_equal(17)


func test_huge_coins_clamped_keeps_level() -> void:
	var s: GameState = _with("coins", 1e30)
	assert_int(s.coins).is_equal(GameState.MAX_SAVE_INT)
	assert_int(s.level).is_equal(17)


func test_negative_or_nan_coins_reset_keeps_level() -> void:
	for bad: Variant in [-1, NAN, INF]:
		var s: GameState = _with("coins", bad)
		assert_int(s.coins).is_equal(0)
		assert_int(s.level).is_equal(17)


func test_bad_setting_type_resets_only_that_key() -> void:
	var s: GameState = _with("settings", {"music_on": "x", "sfx_on": false, "locale": 5})
	assert_bool(s.settings["music_on"]).is_true()
	assert_bool(s.settings["sfx_on"]).is_false()
	assert_str(s.settings["locale"]).is_equal("")
	assert_int(s.level).is_equal(17)


func test_themes_owned_gets_classic() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["themes_owned"] = ["neon", "neon"]
	d["theme_active"] = "neon"
	var s: GameState = GameState.from_dict(d)
	assert_array(s.themes_owned).is_equal(["neon", "classic"])


func test_bad_themes_skipped_keep_classic() -> void:
	var s: GameState = _with("themes_owned", ["neon", "", 3])
	assert_array(s.themes_owned).is_equal(["neon", "classic"])
	s = _with("themes_owned", "classic")
	assert_array(s.themes_owned).is_equal(["classic"])
	assert_int(s.level).is_equal(17)


func test_unowned_active_theme_falls_back_to_classic() -> void:
	var s: GameState = _with("theme_active", "neon")
	assert_str(s.theme_active).is_equal("classic")
	assert_int(s.level).is_equal(17)


func test_bad_purchases_skipped() -> void:
	var s: GameState = _with("purchases", {"remove_ads": true, "bad": 1})
	assert_dict(s.purchases).is_equal({"remove_ads": true})
	s = _with("purchases", [])
	assert_dict(s.purchases).is_empty()
	assert_int(s.level).is_equal(17)


func test_bad_new_ints_reset_keep_level() -> void:
	for field: String in ["streak_best", "level_restarts", "starter_offer_start_day"]:
		var s: GameState = _with(field, -1)
		assert_int(s.get(field)).is_equal(0)
		assert_int(s.level).is_equal(17)
	var s2: GameState = _with("streak_saves_used", "1")
	assert_int(s2.streak_saves_used).is_equal(0)
	assert_int(s2.level).is_equal(17)
