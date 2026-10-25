extends GdUnitTestSuite

var _prefetch: LevelPrefetch


func before_test() -> void:
	GameConfig.reset()
	_prefetch = LevelPrefetch.new()


func after_test() -> void:
	_prefetch.cancel_all()
	GameConfig.reset()


func _same(a: Dictionary, b: Dictionary) -> void:
	assert_array(a["payload"]["tubes"]).is_equal(b["payload"]["tubes"])
	assert_int(a["payload"]["min_moves"]).is_equal(b["payload"]["min_moves"])
	assert_int(a["payload"]["attempt"]).is_equal(b["payload"]["attempt"])


func test_take_after_request_equals_sync() -> void:
	for level in [2, 26, 50]:
		_prefetch.request(1, level)
		_same(_prefetch.take(1, level), ContentGenerator.new().generate(1, level))
	assert_int(_prefetch.sync_generations).is_equal(0)


func test_take_without_request_is_sync() -> void:
	var got: Dictionary = _prefetch.take(1, 7)
	_same(got, ContentGenerator.new().generate(1, 7))
	assert_int(_prefetch.sync_generations).is_equal(1)


func test_other_level_request_is_closed() -> void:
	_prefetch.request(1, 10)
	var got: Dictionary = _prefetch.take(1, 11)
	_same(got, ContentGenerator.new().generate(1, 11))
	assert_int(got["level"]).is_equal(11)
	assert_int(_prefetch.sync_generations).is_equal(1)


func test_cache_is_consumed_once() -> void:
	_prefetch.request(1, 3)
	_prefetch.take(1, 3)
	_prefetch.take(1, 3)
	assert_int(_prefetch.sync_generations).is_equal(1)


func test_cancel_all_after_request_then_take_is_sync() -> void:
	_prefetch.request(1, 5)
	_prefetch.cancel_all()
	assert_int(_prefetch._task_id).is_equal(-1)
	_same(_prefetch.take(1, 5), ContentGenerator.new().generate(1, 5))
	assert_int(_prefetch.sync_generations).is_equal(1)


func test_level_exit_tree_leaves_no_task() -> void:
	var level: Level = load("res://src/levels/level.tscn").instantiate()
	level.state = GameState.new()
	level.clock = TestClock.fixed()
	add_child(level)
	var pf: LevelPrefetch = LevelPrefetch.new()
	level.prefetch = pf
	pf.request(1, 3)
	remove_child(level)
	level.free()
	assert_int(pf._task_id).is_equal(-1)


func test_empty_thread_result_falls_back_to_sync() -> void:
	var pf: NoWorkPrefetch = NoWorkPrefetch.new()
	pf.request(1, 4)
	var got: Dictionary = pf.take(1, 4)
	assert_bool(got.is_empty()).is_false()
	_same(got, ContentGenerator.new().generate(1, 4))
	assert_int(pf.sync_generations).is_equal(1)


class NoWorkPrefetch:
	extends LevelPrefetch

	func _work(_gen: ContentGenerator, _seed_value: int, _level: int) -> void:
		pass
