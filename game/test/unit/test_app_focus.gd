extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_app_focus.json"
const T109_DAY: int = 20000
const T109_DAY_S: int = 86400

var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()
	SaveSystem.save_path = _old_path


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _play_moves(app: App, count: int) -> Level:
	var level := app.current_screen() as Level
	level.board.animate = false
	for i in count:
		var m: Vector2i = level.round.board().legal_moves()[0]
		level.board.tap(m.x)
		level.board.tap(m.y)
	return level


func _app_with_clock(t: Array[int], home: bool) -> App:
	var app: App = auto_free(App.new())
	app.clock = func() -> int: return t[0]
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = home
	app.state.daily_reward_last_claim_day = T109_DAY
	add_child(app)
	return app


func test_focus_in_excludes_background_time_from_elapsed() -> void:
	var t: Array[int] = [T109_DAY * T109_DAY_S + 100]
	var app := _app_with_clock(t, false)
	var level := app.current_screen() as Level
	t[0] += 10
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	t[0] += 3600
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	t[0] += 5
	var elapsed: float = float(level.snapshot()["round"]["elapsed_s"])
	assert_float(elapsed).is_between(15.0, 16.0)


func test_focus_in_home_next_day_shows_popup() -> void:
	var t: Array[int] = [T109_DAY * T109_DAY_S + 100]
	var app := _app_with_clock(t, true)
	assert_bool(app.current_screen() is Home).is_true()
	assert_bool(app.popup_visible()).is_false()
	t[0] += T109_DAY_S
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_bool(app.popup_visible()).is_true()


func test_focus_in_home_same_day_no_popup() -> void:
	var t: Array[int] = [T109_DAY * T109_DAY_S + 100]
	var app := _app_with_clock(t, true)
	t[0] += 600
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_bool(app.popup_visible()).is_false()


func test_focus_in_level_next_day_no_popup_and_round_untouched() -> void:
	var t: Array[int] = [T109_DAY * T109_DAY_S + 100]
	var app := _app_with_clock(t, false)
	var level := _play_moves(app, 2)
	var tubes: Array = level.round.board().tubes.duplicate(true)
	t[0] += T109_DAY_S
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_bool(app.popup_visible()).is_false()
	assert_int(level.round.moves()).is_equal(2)
	assert_array(level.round.board().tubes).is_equal(tubes)
