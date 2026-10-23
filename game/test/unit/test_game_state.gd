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
	assert_dict(copy.settings).is_equal({"sound": true})


func test_to_dict_has_schema_version() -> void:
	assert_int(GameState.new().to_dict()["schema_version"]).is_equal(GameState.SCHEMA_VERSION)


func test_from_dict_accepts_json_floats() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["coins"] = 5.0
	var s: GameState = GameState.from_dict(d)
	assert_object(s).is_not_null()
	assert_int(s.coins).is_equal(5)


func test_migrate_v1_is_noop() -> void:
	var d: Dictionary = GameState.new().to_dict()
	assert_dict(GameState.migrate(d)).is_equal(d)


func test_migrate_adds_missing_version() -> void:
	var migrated: Dictionary = GameState.migrate({"coins": 1})
	assert_int(migrated["schema_version"]).is_equal(1)


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
