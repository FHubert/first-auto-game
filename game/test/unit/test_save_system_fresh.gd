extends GdUnitTestSuite

const SAVE_SCRIPT: String = "res://src/core/save_system.gd"
const TEST_PATH: String = "user://test_save_fresh.json"

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


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_missing_file_grants_starting_coins() -> void:
	var loaded: GameState = _sys.load()
	assert_str(_sys.last_load_source).is_equal("none")
	assert_int(loaded.coins).is_equal(int(GameConfig.get_value("starting_coins")))


func test_both_files_corrupted_grants_starting_coins() -> void:
	_write(TEST_PATH, "{broken")
	_write(TEST_PATH + ".bak", "nope")
	var loaded: GameState = _sys.load()
	assert_str(_sys.last_load_source).is_equal("fresh")
	assert_int(loaded.coins).is_equal(int(GameConfig.get_value("starting_coins")))


func test_saved_zero_coins_not_overwritten() -> void:
	var s := GameState.new()
	s.coins = 0
	assert_bool(_sys.save(s)).is_true()
	var loaded: GameState = _sys.load()
	assert_str(_sys.last_load_source).is_equal("main")
	assert_int(loaded.coins).is_equal(0)
