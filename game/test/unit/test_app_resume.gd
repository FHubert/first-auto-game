extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_app_resume.json"
const TEST_DAY: int = 20000
const TEST_NOW_UNIX: int = TEST_DAY * 86400 + 100

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


func _app(state: GameState) -> App:
	var app: App = auto_free(App.new())
	app.clock = func() -> int: return TEST_NOW_UNIX
	app.state = state
	app.state.settings["tutorial_done"] = true
	add_child(app)
	return app


func _count(fake: FakeAnalyticsProvider, event_id: String) -> int:
	var n: int = 0
	for e in fake.events:
		if str(e.get("event_id", "")) == event_id:
			n += 1
	return n


func test_play_resumes_snapshot_without_loading_level() -> void:
	var prev: AnalyticsProvider = Analytics.provider
	var app := _app(GameState.new())
	app.show_level()
	var level := app.current_screen() as Level
	level.board.animate = false
	for i in 2:
		var m: Vector2i = level.round.board().legal_moves()[0]
		level.board.tap(m.x)
		level.board.tap(m.y)
	app._save_round()
	remove_child(app)
	var fake := FakeAnalyticsProvider.new()
	Analytics.provider = fake
	var app2 := _app(SaveSystem.load())
	app2.show_level()
	Analytics.provider = prev
	assert_int((app2.current_screen() as Level).round.moves()).is_equal(2)
	assert_int(_count(fake, "level:start")).is_equal(0)
	assert_int(_count(fake, "level:resume")).is_equal(1)
	await get_tree().process_frame


func test_home_popup_depends_on_claim_day() -> void:
	var fresh := _app(GameState.new())
	assert_bool(fresh.popup_visible()).is_true()
	var claimed_state := GameState.new()
	claimed_state.daily_reward_last_claim_day = TEST_DAY
	var claimed := _app(claimed_state)
	assert_bool(claimed.popup_visible()).is_false()
	await get_tree().process_frame
