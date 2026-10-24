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
	for p in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
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
	assert_int(loaded.coins).is_equal(int(GameConfig.get_value("starting_coins")))
	assert_str(_sys.last_load_source).is_equal("none")
	assert_int(loaded.level).is_equal(1)


func test_load_corrupted_file_returns_new_state() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var loaded: GameState = _sys.load()
	assert_object(loaded).is_not_null()
	assert_int(loaded.coins).is_equal(int(GameConfig.get_value("starting_coins")))


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


func test_read_only_skips_write() -> void:
	_sys.read_only = true
	assert_bool(_sys.save(GameState.new())).is_true()
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_corrupted_main_loads_backup() -> void:
	var s := GameState.new()
	s.coins = 77
	_sys.save(s)
	_sys.save(s)
	_write_raw(TEST_PATH, '{"coins": ')
	var loaded: GameState = _sys.load()
	assert_int(loaded.coins).is_equal(77)
	assert_str(_sys.last_load_source).is_equal("backup")


func test_both_corrupted_returns_fresh() -> void:
	_write_raw(TEST_PATH, '{"coins": ')
	_write_raw(_sys.backup_path(), "garbage")
	assert_int(_sys.load().coins).is_equal(int(GameConfig.get_value("starting_coins")))
	assert_str(_sys.last_load_source).is_equal("fresh")


func test_missing_file_source_none() -> void:
	_write_raw(_sys.backup_path(), JSON.stringify(GameState.new().to_dict()))
	_sys.load()
	assert_str(_sys.last_load_source).is_equal("none")


func test_second_save_keeps_previous_as_backup() -> void:
	var s := GameState.new()
	s.coins = 1
	_sys.save(s)
	s.coins = 2
	_sys.save(s)
	assert_int(_sys.load().coins).is_equal(2)
	assert_str(_sys.last_load_source).is_equal("main")
	var json := JSON.new()
	assert_int(json.parse(FileAccess.get_file_as_string(_sys.backup_path()))).is_equal(OK)
	assert_int(int(json.data["coins"])).is_equal(1)


func test_save_to_missing_directory_fails_cleanly() -> void:
	_sys.save_path = "user://nope_dir_t163/sub/save.json"
	assert_bool(_sys.save(GameState.new())).is_false()
	assert_bool(FileAccess.file_exists(_sys.save_path + ".tmp")).is_false()


func test_read_only_creates_no_backup() -> void:
	_sys.save(GameState.new())
	_sys.read_only = true
	_sys.save(GameState.new())
	assert_bool(FileAccess.file_exists(_sys.backup_path())).is_false()
