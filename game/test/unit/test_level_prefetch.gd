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


## Pomiar (T-136): mediana z 5 load-ek, bez asercji progu czasowego.
func test_measure_take_time() -> void:
	for level in [2, 26, 50, 120]:
		var cold: Array = []
		var warm: Array = []
		for _i in 5:
			var t0: int = Time.get_ticks_usec()
			_prefetch.take(1, level)
			cold.append(Time.get_ticks_usec() - t0)
			_prefetch.request(1, level)
			OS.delay_msec(150)
			t0 = Time.get_ticks_usec()
			_prefetch.take(1, level)
			warm.append(Time.get_ticks_usec() - t0)
		cold.sort()
		warm.sort()
		print("PREFETCH_MEASURE level=%d sync_us=%d prefetched_us=%d" % [level, cold[2], warm[2]])
