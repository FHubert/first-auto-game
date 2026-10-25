extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_abandon_analytics.json"

var _old_path: String
var _prev: AnalyticsProvider
var _fake: FakeAnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_prev = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)


func after_test() -> void:
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	Analytics.provider = _prev


func _app() -> App:
	var app: App = auto_free(App.new())
	app.clock = TestClock.fixed()
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	_fake.events.clear()
	return app


func _ids() -> Array[String]:
	var out: Array[String] = []
	for e in _fake.events:
		if e["type"] == "design":
			out.append(str(e["event_id"]))
	return out


func _value(id: String) -> float:
	for e in _fake.events:
		if e["type"] == "design" and e["event_id"] == id:
			return float(e["value"])
	return -1.0


func test_campaign_abandon_reports_bracket_and_attempt() -> void:
	var app := _app()
	app.state.round_in_progress = {"mode": "campaign", "level_no": 30, "round": {"restarts": 2}}
	app._discard_snapshot()
	assert_float(_value("level:fail:abandon:lv26_55")).is_equal(3.0)
	assert_int(_ids().count("level:fail:abandon")).is_equal(1)


func test_daily_abandon_has_no_bracket() -> void:
	var app := _app()
	app.state.round_in_progress = {
		"mode": "daily", "level_no": 30, "utc_day": 1, "round": {"restarts": 2}
	}
	app._discard_snapshot()
	assert_int(_ids().count("level:fail:abandon")).is_equal(1)
	for id in _ids():
		assert_bool(id.begins_with("level:fail:abandon:")).is_false()


func test_missing_or_corrupt_restarts_defaults_to_first_attempt() -> void:
	var app := _app()
	app.state.round_in_progress = {"mode": "campaign", "level_no": 3}
	app._discard_snapshot()
	assert_float(_value("level:fail:abandon:lv1_7")).is_equal(1.0)
	_fake.events.clear()
	app.state.round_in_progress = {"mode": "campaign", "level_no": 60, "round": {"restarts": "x"}}
	app._discard_snapshot()
	assert_float(_value("level:fail:abandon:lv56p")).is_equal(1.0)
