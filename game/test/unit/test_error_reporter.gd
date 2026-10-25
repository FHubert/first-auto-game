extends GdUnitTestSuite
## T-296: ErrorReporter (dedup, limit sesji, watki) + integracja z Logger silnika.

var _fake: FakeAnalyticsProvider
var _rep: ErrorReporter


func before_test() -> void:
	_fake = FakeAnalyticsProvider.new()
	_rep = ErrorReporter.new()
	GameConfig.reset()


func after_test() -> void:
	GameConfig.reset()


func _errors() -> Array:
	return _fake.events.filter(func(e: Dictionary) -> bool: return e["type"] == "error")


func test_same_signature_three_times_sends_once() -> void:
	for i in 3:
		_rep.ingest("a.gd", 5, "boom", Logger.ERROR_TYPE_ERROR)
	assert_int(_rep.flush(_fake)).is_equal(1)
	assert_int(_errors().size()).is_equal(1)
	_rep.ingest("a.gd", 5, "boom", Logger.ERROR_TYPE_ERROR)
	assert_int(_rep.flush(_fake)).is_equal(0)


func test_limit_caps_distinct_signatures() -> void:
	for i in 11:
		_rep.ingest("f%s.gd" % char(97 + i), 1, "x", Logger.ERROR_TYPE_SCRIPT)
	assert_int(_rep.flush(_fake)).is_equal(10)
	assert_int(_errors().size()).is_equal(10)


func test_limit_zero_disables() -> void:
	GameConfig.set_for_test("error_report_max_per_session", 0)
	_rep.ingest("a.gd", 1, "x", Logger.ERROR_TYPE_ERROR)
	assert_int(_rep.flush(_fake)).is_equal(0)
	assert_int(_errors().size()).is_equal(0)


func test_numbers_are_normalized_into_same_signature() -> void:
	_rep.ingest("a.gd", 7, "bad index 3 of 10", Logger.ERROR_TYPE_ERROR)
	_rep.ingest("a.gd", 7, "bad index 8 of 42", Logger.ERROR_TYPE_ERROR)
	assert_int(_rep.flush(_fake)).is_equal(1)
	assert_str(str(_errors()[0]["message"])).is_equal("a.gd:N bad index N of N")
	assert_str(str(_errors()[0]["severity"])).is_equal("error")


func test_warning_is_skipped_and_message_truncated() -> void:
	_rep.ingest("a.gd", 1, "warn", Logger.ERROR_TYPE_WARNING)
	assert_int(_rep.flush(_fake)).is_equal(0)
	_rep.ingest("a.gd", 1, "y".repeat(500), Logger.ERROR_TYPE_SHADER)
	assert_int(_rep.flush(_fake)).is_equal(1)
	assert_int(str(_errors()[0]["message"]).length()).is_equal(256)


func test_ingest_from_worker_thread_arrives_only_on_flush() -> void:
	var task: int = WorkerThreadPool.add_task(
		func() -> void: _rep.ingest("w.gd", 2, "from thread", Logger.ERROR_TYPE_ERROR)
	)
	WorkerThreadPool.wait_for_task_completion(task)
	assert_int(_errors().size()).is_equal(0)
	assert_int(_rep.flush(_fake)).is_equal(1)
	assert_int(_errors().size()).is_equal(1)


func test_logger_integration_real_push_error() -> void:
	var logger := ErrorLogger.new()
	OS.add_logger(logger)
	push_error("t296 probe 1")
	OS.remove_logger(logger)
	assert_int(logger.reporter.flush(_fake)).is_equal(1)
	assert_str(str(_errors()[0]["message"])).contains("tN probe N")
