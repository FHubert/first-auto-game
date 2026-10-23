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


func test_migrate_v2_is_noop() -> void:
	var d: Dictionary = GameState.new().to_dict()
	assert_dict(GameState.migrate(d)).is_equal(d)


func test_migrate_adds_missing_version() -> void:
	var migrated: Dictionary = GameState.migrate({"coins": 1})
	assert_int(migrated["schema_version"]).is_equal(GameState.SCHEMA_VERSION)


func test_rejects_wrong_types() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["coins"] = "many"
	assert_object(GameState.from_dict(d)).is_null()
	d = GameState.new().to_dict()
	d["settings"] = []
	assert_object(GameState.from_dict(d)).is_null()
	d = GameState.new().to_dict()
	d["level"] = 2.5
	assert_object(GameState.from_dict(d)).is_null()


func test_rejects_negative_coins() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["coins"] = -1
	assert_object(GameState.from_dict(d)).is_null()


func test_rejects_newer_schema() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["schema_version"] = GameState.SCHEMA_VERSION + 1
	assert_object(GameState.from_dict(d)).is_null()


func _v1_save() -> Dictionary:
	return {
		"schema_version": 1,
		"coins": 5,
		"level": 3,
		"streak_days": 2,
		"last_play_utc_day": 100,
		"settings": {},
	}


func test_round_trip_all_fields() -> void:
	var s := GameState.new()
	s.coins = 9
	s.level = 4
	s.streak_days = 2
	s.last_play_utc_day = 20001
	s.daily_reward_last_claim_day = 20000
	s.daily_last_completed_day = 19999
	s.daily_completed_total = 6
	s.streak_best = 8
	s.streak_saves_used = 1
	s.streak_save_window_day = 19990
	s.themes_owned = ["classic", "neon"]
	s.theme_active = "neon"
	s.levels_completed = 12
	s.level_restarts = 3
	s.starter_offer_start_day = 19995
	s.purchases = {"remove_ads": true}
	s.settings["music_on"] = false
	s.settings["locale"] = "pl"
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var copy: GameState = GameState.from_dict(d)
	assert_object(copy).is_not_null()
	assert_dict(copy.to_dict()).is_equal(s.to_dict())
	assert_bool(copy.owns_theme("neon")).is_true()
	assert_bool(copy.owns_theme("gold")).is_false()
	assert_bool(copy.has_purchase("remove_ads")).is_true()
	assert_bool(copy.has_purchase("other")).is_false()


func test_migrate_v1_defaults() -> void:
	var s: GameState = GameState.from_dict(_v1_save())
	assert_object(s).is_not_null()
	assert_int(s.coins).is_equal(5)
	assert_int(s.level).is_equal(3)
	assert_int(s.streak_days).is_equal(2)
	assert_int(s.last_play_utc_day).is_equal(100)
	var fresh: Dictionary = GameState.new().to_dict()
	fresh["coins"] = 5
	fresh["level"] = 3
	fresh["streak_days"] = 2
	fresh["last_play_utc_day"] = 100
	assert_dict(s.to_dict()).is_equal(fresh)
	assert_bool(s.settings["music_on"]).is_true()
	assert_array(s.themes_owned).is_equal(["classic"])


func test_settings_merge() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["settings"] = {"sfx_on": false, "custom": 1}
	var s: GameState = GameState.from_dict(d)
	assert_bool(s.settings["sfx_on"]).is_false()
	assert_bool(s.settings["haptics_on"]).is_true()
	assert_int(s.settings["custom"]).is_equal(1)


func test_rejects_bad_setting_type() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["settings"] = {"music_on": "yes"}
	assert_object(GameState.from_dict(d)).is_null()
	d["settings"] = {"locale": 5}
	assert_object(GameState.from_dict(d)).is_null()


func test_themes_owned_gets_classic() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["themes_owned"] = ["neon", "neon"]
	d["theme_active"] = "neon"
	var s: GameState = GameState.from_dict(d)
	assert_array(s.themes_owned).is_equal(["neon", "classic"])


func test_rejects_bad_themes() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["theme_active"] = "neon"
	assert_object(GameState.from_dict(d)).is_null()
	d = GameState.new().to_dict()
	d["themes_owned"] = ["classic", ""]
	assert_object(GameState.from_dict(d)).is_null()
	d["themes_owned"] = ["classic", 3]
	assert_object(GameState.from_dict(d)).is_null()
	d["themes_owned"] = "classic"
	assert_object(GameState.from_dict(d)).is_null()


func test_rejects_bad_purchases() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["purchases"] = {"remove_ads": 1}
	assert_object(GameState.from_dict(d)).is_null()
	d["purchases"] = []
	assert_object(GameState.from_dict(d)).is_null()


func test_rejects_negative_new_ints() -> void:
	for field: String in ["streak_best", "level_restarts", "starter_offer_start_day"]:
		var d: Dictionary = GameState.new().to_dict()
		d[field] = -1
		assert_object(GameState.from_dict(d)).is_null()
	var d2: Dictionary = GameState.new().to_dict()
	d2["streak_saves_used"] = "1"
	assert_object(GameState.from_dict(d2)).is_null()
