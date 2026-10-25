extends GdUnitTestSuite
## T-211: strukturalna walidacja round_in_progress w GameState.from_dict.

const SAVE_PATH: String = "user://test_round_snapshot_validation.json"

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


func _good() -> Dictionary:
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(7, 3))
	return GameState.round_snapshot("campaign", 3, 20750, r)


func _save_with(rip: Variant) -> Dictionary:
	var s := GameState.new()
	s.level = 4
	s.coins = 77
	var d: Dictionary = s.to_dict()
	d["round_in_progress"] = rip
	return d


func _bad_shapes() -> Array:
	var no_mode: Dictionary = _good()
	no_mode.erase("mode")
	var bad_mode: Dictionary = _good()
	bad_mode["mode"] = "x"
	var str_level: Dictionary = _good()
	str_level["level_no"] = "3"
	var zero_level: Dictionary = _good()
	zero_level["level_no"] = 0
	var list_round: Dictionary = _good()
	list_round["round"] = [1, 2]
	return [no_mode, bad_mode, str_level, zero_level, list_round, 5]


func test_bad_shapes_reset_only_snapshot() -> void:
	for bad: Variant in _bad_shapes():
		var s: GameState = GameState.from_dict(_save_with(bad))
		assert_object(s).is_not_null()
		assert_dict(s.round_in_progress).is_empty()
		assert_bool(s.round_snapshot_rejected).is_true()
		assert_int(s.level).is_equal(4)
		assert_int(s.coins).is_equal(77)


func test_valid_snapshot_round_trips_and_json_floats_pass() -> void:
	var s := GameState.new()
	s.round_in_progress = _good()
	var copy: GameState = GameState.from_dict(s.to_dict())
	assert_bool(copy.round_snapshot_rejected).is_false()
	assert_dict(copy.round_in_progress).is_equal(s.round_in_progress)
	var via_json: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	assert_bool(GameState.from_dict(via_json).round_snapshot_rejected).is_false()
	assert_bool(GameState.from_dict(GameState.new().to_dict()).round_snapshot_rejected).is_false()


func test_flag_is_not_serialized() -> void:
	var s: GameState = GameState.from_dict(_save_with(5))
	assert_bool(s.to_dict().has("round_snapshot_rejected")).is_false()


func test_app_reports_abandon_once_for_rejected_snapshot() -> void:
	var bad: Dictionary = _good()
	bad["mode"] = "x"
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var d: Dictionary = _save_with(bad)
	d["settings"]["tutorial_done"] = true
	f.store_string(JSON.stringify(d))
	f.close()
	var app: App = auto_free(App.new())
	app.clock = TestClock.fixed()
	add_child(app)
	var n: int = 0
	for e in _fake.events:
		if e["type"] == "design" and e["event_id"] == "level:fail:abandon":
			n += 1
	assert_int(n).is_equal(1)
	assert_dict(app.state.round_in_progress).is_empty()
