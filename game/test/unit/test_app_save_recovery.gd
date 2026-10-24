extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_app_recovery.json"

var _old_path: String
var _prev_analytics: AnalyticsProvider
var _fake: FakeAnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()
	SaveSystem.save_path = _old_path
	Analytics.provider = _prev_analytics


func _cleanup() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _start_app() -> App:
	var app: App = auto_free(App.new())
	app.clock = TestClock.fixed()
	add_child(app)
	return app


func _recovered_count() -> int:
	var n: int = 0
	for e in _fake.events:
		if str(e.get("event_id", "")).begins_with("save:recovered:"):
			n += 1
	return n


func test_corrupted_main_reports_backup_recovery() -> void:
	var s := GameState.new()
	s.coins = 5
	s.settings["tutorial_done"] = true
	SaveSystem.save(s)
	SaveSystem.save(s)
	_write_raw(SAVE_PATH, '{"coins": ')
	var app := _start_app()
	assert_int(app.state.coins).is_equal(5)
	assert_int(_recovered_count()).is_equal(1)
	(
		assert_bool(
			_fake.events.any(
				func(e: Dictionary) -> bool: return e.get("event_id", "") == "save:recovered:backup"
			)
		)
		. is_true()
	)
	await get_tree().process_frame


func test_valid_main_reports_no_recovery() -> void:
	var s := GameState.new()
	s.settings["tutorial_done"] = true
	SaveSystem.save(s)
	_start_app()
	assert_int(_recovered_count()).is_equal(0)
	await get_tree().process_frame
