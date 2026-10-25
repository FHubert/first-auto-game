extends GdUnitTestSuite
## T-252 / ADR-015: watek prefetchu nie czyta GameConfig - migawka + revision().

const GENERATOR_SRC: String = "res://src/systems/content_generator.gd"
const PREFETCH_SRC: String = "res://src/systems/level_prefetch.gd"
const RESET_LOOPS: int = 50

var _prefetch: LevelPrefetch


func before_test() -> void:
	GameConfig.reset()
	_prefetch = LevelPrefetch.new()


func after_test() -> void:
	_prefetch.cancel_all()
	GameConfig.reset()


func _tubes(d: Dictionary) -> Array:
	return d["payload"]["tubes"]


func test_snapshot_independent_of_later_apply_remote() -> void:
	var snap: Dictionary = GameConfig.snapshot()
	var colors_max: int = int(snap["colors_max"])
	GameConfig.apply_remote({"colors_max": colors_max - 2})
	assert_int(int(snap["colors_max"])).is_equal(colors_max)
	assert_int(int(GameConfig.get_value("colors_max"))).is_equal(colors_max - 2)
	var with_snap: Dictionary = ContentGenerator.new(snap).generate(3, 60)
	GameConfig.reset()
	assert_array(_tubes(with_snap)).is_equal(_tubes(ContentGenerator.new().generate(3, 60)))


func test_request_then_apply_remote_equals_sync_with_new_config() -> void:
	_prefetch.request(5, 80)
	GameConfig.apply_remote({"colors_max": 10})
	var got: Dictionary = _prefetch.take(5, 80)
	assert_int(_prefetch.sync_generations).is_equal(1)
	assert_array(_tubes(got)).is_equal(_tubes(ContentGenerator.new().generate(5, 80)))


func test_reset_loop_during_work_keeps_snapshot_result() -> void:
	var expected: Dictionary = ContentGenerator.new().generate(7, 120)
	_prefetch.request(7, 120)
	var revision: int = GameConfig.revision()
	for i in RESET_LOOPS:
		GameConfig.reset()
	assert_int(GameConfig.revision()).is_equal(revision + RESET_LOOPS)
	var got: Dictionary = _prefetch.take(7, 120)
	assert_array(_tubes(got)).is_equal(_tubes(expected))


func test_unchanged_config_keeps_prefetch_result() -> void:
	_prefetch.request(2, 30)
	var got: Dictionary = _prefetch.take(2, 30)
	assert_int(_prefetch.sync_generations).is_equal(0)
	assert_array(_tubes(got)).is_equal(_tubes(ContentGenerator.new().generate(2, 30)))


func test_revision_unchanged_when_nothing_applied() -> void:
	var before: int = GameConfig.revision()
	assert_int(GameConfig.apply_remote({"no_such_key": 1})).is_equal(0)
	assert_int(GameConfig.apply_remote({"colors_max": "bad"})).is_equal(0)
	assert_int(GameConfig.revision()).is_equal(before)
	assert_int(GameConfig.apply_remote({"colors_max": 9})).is_equal(1)
	assert_int(GameConfig.revision()).is_equal(before + 1)


func test_worker_sources_do_not_read_game_config() -> void:
	var needle: String = "GameConfig." + "get_value"
	for path: String in [GENERATOR_SRC, PREFETCH_SRC]:
		assert_bool(FileAccess.get_file_as_string(path).contains(needle)).is_false()
