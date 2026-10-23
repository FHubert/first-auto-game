extends GdUnitTestSuite

const SAVE_SCRIPT: String = "res://src/core/save_system.gd"
const TEST_PATH: String = "user://test_save.json"

var _sys: Node


func before_test() -> void:
	_sys = auto_free(load(SAVE_SCRIPT).new())
	_sys.save_path = TEST_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_save_and_load_round_trip() -> void:
	var s := GameState.new()
	s.coins = 42
	s.level = 3
	assert_bool(_sys.save(s)).is_true()
	assert_bool(FileAccess.file_exists(TEST_PATH + ".tmp")).is_false()
	var loaded: GameState = _sys.load()
	assert_int(loaded.coins).is_equal(42)
	assert_int(loaded.level).is_equal(3)


func test_load_missing_file_returns_new_state() -> void:
	var loaded: GameState = _sys.load()
	assert_int(loaded.coins).is_equal(0)
	assert_int(loaded.level).is_equal(1)


func test_load_corrupted_file_returns_new_state() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var loaded: GameState = _sys.load()
	assert_object(loaded).is_not_null()
	assert_int(loaded.coins).is_equal(0)


func test_load_invalid_content_returns_new_state() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"schema_version":1,"coins":"x"}')
	f.close()
	assert_int(_sys.load().coins).is_equal(0)


func test_save_overwrites_existing() -> void:
	var s := GameState.new()
	s.coins = 1
	_sys.save(s)
	s.coins = 2
	_sys.save(s)
	assert_int(_sys.load().coins).is_equal(2)


func test_round_trip_themes_and_purchases() -> void:
	var s := GameState.new()
	s.themes_owned = ["classic", "neon"]
	s.theme_active = "neon"
	s.purchases = {"remove_ads": true}
	assert_bool(_sys.save(s)).is_true()
	var loaded: GameState = _sys.load()
	assert_array(loaded.themes_owned).is_equal(["classic", "neon"])
	assert_str(loaded.theme_active).is_equal("neon")
	assert_bool(loaded.has_purchase("remove_ads")).is_true()
