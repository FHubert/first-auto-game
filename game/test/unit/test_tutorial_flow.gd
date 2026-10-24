extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_tutorial.json"

var _level: Level
var _old_path: String
var _fake: FakeAnalyticsProvider
var _prev_analytics: AnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	_cleanup()
	SaveSystem.save_path = _old_path
	Analytics.provider = _prev_analytics
	GameConfig.reset()


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _make_level(done: bool) -> void:
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.clock = TestClock.fixed()
	_level.state = GameState.new()
	_level.state.settings["tutorial_done"] = done
	add_child(_level)


func test_state_machine_happy_path() -> void:
	var t := TutorialFlow.new()
	t.start(Vector2i(0, 2))
	assert_bool(t.on_tube_selected(1)).is_false()
	assert_int(t.step).is_equal(TutorialFlow.Step.PICK_SOURCE)
	assert_int(t.highlight()).is_equal(0)
	assert_bool(t.on_pour(0, 2, Vector2i(1, 3), false)).is_false()
	assert_bool(t.on_tube_selected(0)).is_true()
	assert_int(t.step).is_equal(TutorialFlow.Step.PICK_TARGET)
	assert_int(t.highlight()).is_equal(2)
	t.on_deselect()
	assert_int(t.step).is_equal(TutorialFlow.Step.PICK_SOURCE)
	t.on_tube_selected(0)
	assert_bool(t.on_pour(0, 1, Vector2i(1, 3), false)).is_false()
	assert_bool(t.on_pour(0, 2, Vector2i(1, 3), false)).is_true()
	assert_int(t.step).is_equal(TutorialFlow.Step.FINISH)
	assert_int(t.highlight()).is_equal(1)
	assert_bool(t.on_pour(1, 3, GameRound.NO_HINT, true)).is_true()
	assert_bool(t.is_done()).is_true()
	assert_int(t.highlight()).is_equal(-1)
	assert_str(t.message()).is_empty()


func test_win_on_expected_pour_finishes() -> void:
	var t := TutorialFlow.new()
	t.start(Vector2i(0, 1))
	t.on_tube_selected(0)
	assert_bool(t.on_pour(0, 1, GameRound.NO_HINT, true)).is_true()
	assert_bool(t.is_done()).is_true()


func test_level_one_is_two_colors_short() -> void:
	var seed_value: int = int(GameConfig.get_value("campaign_seed"))
	var payload: Dictionary = ContentGenerator.new().generate(seed_value, 1)["payload"]
	assert_int(int(payload["colors"])).is_equal(2)
	assert_int(int(payload["min_moves"])).is_less_equal(4)


func test_scene_runs_tutorial_to_completion() -> void:
	_make_level(false)
	assert_object(_level.tutorial).is_not_null()
	assert_bool(_level.tutorial_overlay.visible).is_true()
	assert_bool(_level.hud.hint_button.visible).is_false()
	var path: Array = SortSolver.solve(_level.round.board(), 20000, 1.0)["path"]
	for m: Vector2i in path:
		_level.board.tap(m.x)
		_level.board.tap(m.y)
	assert_bool(bool(_level.state.settings["tutorial_done"])).is_true()
	assert_object(_level.tutorial).is_null()
	assert_bool(_level.tutorial_overlay.visible).is_false()
	assert_bool(_level.hud.hint_button.visible).is_true()
	assert_bool(bool(SaveSystem.load().settings["tutorial_done"])).is_true()


func test_scene_illegal_target_restarts_step() -> void:
	_make_level(false)
	var m: Vector2i = _level.tutorial.expected
	_level.board.tap(m.x)
	assert_int(_level.tutorial.step).is_equal(TutorialFlow.Step.PICK_TARGET)
	var bad: int = m.x
	for i: int in _level.round.board().tube_count():
		if i != m.x and not _level.round.board().can_pour(m.x, i):
			bad = i
			break
	_level.board.tap(bad)
	assert_int(_level.board.selected_index()).is_equal(-1)
	assert_int(_level.tutorial.step).is_equal(TutorialFlow.Step.PICK_SOURCE)
	assert_int(_level.tutorial.highlight()).is_equal(m.x)
	assert_bool(_level.tutorial_overlay.visible).is_true()
	assert_str(_level.tutorial_overlay.label.text).is_equal(tr("tut_pick_source"))


func test_scene_skips_tutorial_when_done() -> void:
	_make_level(true)
	assert_object(_level.tutorial).is_null()
	assert_bool(_level.tutorial_overlay.visible).is_false()
	assert_bool(_level.hud.hint_button.visible).is_true()


func _count_design(id: String) -> int:
	var n: int = 0
	for e in _fake.events:
		if e["type"] == "design" and e["event_id"] == id:
			n += 1
	return n


func _design_index(id: String) -> int:
	for i in _fake.events.size():
		if _fake.events[i]["type"] == "design" and _fake.events[i]["event_id"] == id:
			return i
	return -1


func _design_value(id: String) -> float:
	return float(_fake.events[_design_index(id)]["value"])


func test_analytics_tutorial_steps_in_order() -> void:
	_make_level(false)
	var path: Array = SortSolver.solve(_level.round.board(), 20000, 1.0)["path"]
	for m: Vector2i in path:
		_level.board.tap(m.x)
		_level.board.tap(m.y)
	var ids: Array = ["tutorial:step:1", "tutorial:step:2", "tutorial:step:3", "tutorial:done"]
	var prev: int = -1
	for id: String in ids:
		assert_int(_count_design(id)).is_equal(1)
		var idx: int = _design_index(id)
		assert_bool(idx > prev).is_true()
		prev = idx
	assert_int(_count_design("tutorial:reset")).is_equal(0)


func test_analytics_tutorial_deselect_logs_reset_once() -> void:
	_make_level(false)
	var m: Vector2i = _level.tutorial.expected
	_level.board.tap(m.x)
	_level.board.tap(m.x)
	assert_int(_count_design("tutorial:reset")).is_equal(1)
	assert_float(_design_value("tutorial:reset")).is_equal(2.0)
	_level.board.tap(m.x)
	assert_int(_count_design("tutorial:step:1")).is_equal(1)
	assert_int(_count_design("tutorial:step:2")).is_equal(1)


func test_analytics_tutorial_wrong_target_logs_reset() -> void:
	_make_level(false)
	var m: Vector2i = _level.tutorial.expected
	_level.board.tap(m.x)
	for i: int in _level.round.board().tube_count():
		if i != m.x and not _level.round.board().can_pour(m.x, i):
			_level.board.tap(i)
			break
	assert_int(_count_design("tutorial:reset")).is_equal(1)
	assert_float(_design_value("tutorial:reset")).is_equal(2.0)
	assert_int(_count_design("tutorial:step:2")).is_equal(1)


func test_analytics_no_tutorial_events_when_done() -> void:
	_make_level(true)
	for e in _fake.events:
		assert_bool(str(e.get("event_id", "")).begins_with("tutorial:")).is_false()
