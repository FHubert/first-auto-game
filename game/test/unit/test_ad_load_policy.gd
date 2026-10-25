extends GdUnitTestSuite

var _p: AdLoadPolicy


func before_test() -> void:
	GameConfig.reset()
	_p = AdLoadPolicy.new()


func after_test() -> void:
	GameConfig.reset()


func test_delay_table_doubles_then_caps() -> void:
	GameConfig.set_for_test("ad_load_max_retries", 50)
	var expected: Array[float] = [2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 64.0]
	var now: float = 100.0
	for delay: float in expected:
		_p.on_requested(now)
		assert_float(_p.on_failed(now) - now).is_equal(delay)
		now += delay


func test_is_due_before_and_after_deadline() -> void:
	_p.on_requested(10.0)
	var due: float = _p.on_failed(10.0)
	assert_bool(_p.is_due(due - 0.1)).is_false()
	assert_bool(_p.is_due(due)).is_true()
	assert_bool(_p.is_due(due + 5.0)).is_true()


func test_not_due_while_loading_or_without_failure() -> void:
	assert_bool(_p.is_due(1000.0)).is_false()
	_p.on_failed(0.0)
	_p.on_requested(50.0)
	assert_bool(_p.is_due(1000.0)).is_false()


func test_gives_up_after_max_retries() -> void:
	for i: int in 5:
		_p.on_failed(float(i))
		assert_bool(_p.gave_up()).is_false()
	_p.on_failed(5.0)
	assert_int(_p.failures()).is_equal(6)
	assert_bool(_p.gave_up()).is_true()
	assert_bool(_p.is_due(100000.0)).is_false()


func test_success_resets_failure_count() -> void:
	_p.on_failed(0.0)
	_p.on_failed(2.0)
	_p.on_loaded()
	assert_int(_p.failures()).is_equal(0)
	assert_bool(_p.gave_up()).is_false()
	assert_float(_p.on_failed(50.0) - 50.0).is_equal(2.0)


func test_zero_retries_gives_up_after_first_failure() -> void:
	GameConfig.set_for_test("ad_load_max_retries", 0)
	assert_bool(_p.gave_up()).is_false()
	_p.on_failed(0.0)
	assert_bool(_p.gave_up()).is_true()
	assert_bool(_p.is_due(1000.0)).is_false()


func test_reset_clears_state() -> void:
	for i: int in 6:
		_p.on_failed(float(i))
	_p.reset()
	assert_int(_p.failures()).is_equal(0)
	assert_bool(_p.gave_up()).is_false()
	assert_float(_p.on_failed(0.0)).is_equal(2.0)


func test_remote_batch_with_base_above_max_rejected_whole() -> void:
	var batch: Dictionary = {
		"ad_load_retry_base_seconds": 60, "ad_load_retry_max_seconds": 10, "starting_coins": 150
	}
	assert_int(GameConfig.apply_remote(batch)).is_equal(0)
	assert_int(GameConfig.get_value("ad_load_retry_base_seconds")).is_equal(2)
	assert_int(GameConfig.get_value("ad_load_retry_max_seconds")).is_equal(64)
	assert_int(GameConfig.get_value("starting_coins")).is_equal(100)


func test_remote_batch_valid_retry_keys_applied() -> void:
	var batch: Dictionary = {"ad_load_retry_base_seconds": 5, "ad_load_retry_max_seconds": 30}
	assert_int(GameConfig.apply_remote(batch)).is_equal(2)
	assert_float(_p.on_failed(0.0)).is_equal(5.0)
