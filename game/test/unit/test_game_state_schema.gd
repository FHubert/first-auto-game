extends GdUnitTestSuite


func test_bad_schema_version_type_migrates_as_v1(
	bad: Variant,
	test_parameters := [[{"a": 1}], [[1, 2]], ["abc"], [true], [null], [0], [-5], [NAN]]
) -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["level"] = 17
	d["coins"] = 42
	d["schema_version"] = bad
	var s: GameState = GameState.from_dict(d)
	assert_object(s).is_not_null()
	assert_int(s.level).is_equal(17)
	assert_int(s.coins).is_equal(42)
	assert_int(GameState.migrate(d)["schema_version"]).is_equal(GameState.SCHEMA_VERSION)
	assert_that(test_parameters).is_not_null()


func test_missing_schema_version_keeps_fields() -> void:
	var d: Dictionary = {"level": 9, "coins": 7}
	var s: GameState = GameState.from_dict(d)
	assert_object(s).is_not_null()
	assert_int(s.level).is_equal(9)
	assert_int(s.coins).is_equal(7)


func test_float_schema_version_3_is_not_migrated() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["schema_version"] = 3.0
	var snap: Dictionary = {"mode": "daily", "level_no": 2, "utc_day": 5, "round": {}}
	d["round_in_progress"] = snap
	var s: GameState = GameState.from_dict(d)
	assert_object(s).is_not_null()
	assert_dict(s.round_in_progress).is_equal(snap)


func test_newer_schema_version_returns_null() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["schema_version"] = GameState.SCHEMA_VERSION + 1
	assert_object(GameState.from_dict(d)).is_null()
