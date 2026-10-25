extends GdUnitTestSuite
## T-207: numer proby i flaga "probowka w tej probie" per przedzial poziomow.

const SAVE_PATH: String = "user://test_level_attempt_events.json"
const LEVEL_NO: int = 30
const BRACKET: String = "lv26_55"

var _old_path: String
var _prev_analytics: AnalyticsProvider
var _prev_ads: AdProvider
var _fake: FakeAnalyticsProvider
var _notif: FakeNotificationProvider
var _t: Array[int] = [TestClock.FIXED_UNIX]


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	_prev_ads = Ads.provider
	Ads.provider = FakeAdProvider.new()
	_notif = FakeNotificationProvider.new()
	_t = [TestClock.FIXED_UNIX]


func after_test() -> void:
	Analytics.provider = _prev_analytics
	Ads.provider = _prev_ads
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _new_app(level_no: int, coins: int) -> App:
	var state := SaveSystem.fresh_state()
	state.level = level_no
	state.coins = coins
	state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	var app: App = auto_free(App.new())
	app.clock = TestClock.ticking(_t)
	app.effects_enabled = false
	app.notifications = _notif
	app.state = state
	add_child(app)
	return app


func _level_of(app: App) -> Level:
	app.current_screen().play_pressed.emit()
	return app.current_screen() as Level


func _values(id: String) -> Array:
	var out: Array = []
	for e: Dictionary in _fake.events:
		if str(e.get("event_id", "")) == id:
			out.append(int(e["value"]))
	return out


func _solve(level: Level, no: int) -> void:
	var seed_value: int = int(GameConfig.get_value("campaign_seed"))
	var sol: Array = ContentGenerator.new().generate(seed_value, no)["payload"]["solution"]
	for i in sol.size() - 1:
		level.round.try_move(sol[i].x, sol[i].y)
	level.board.tap(sol[sol.size() - 1].x)
	level.board.tap(sol[sol.size() - 1].y)


func test_first_attempt_win_has_attempt_1_and_no_tube() -> void:
	var level := _level_of(_new_app(LEVEL_NO, 0))
	_solve(level, LEVEL_NO)
	assert_array(_values("level:complete:attempt:" + BRACKET)).contains_exactly([1])
	assert_array(_values("level:complete:tube:" + BRACKET)).contains_exactly([0])
	assert_array(_values("level:fail:attempt:" + BRACKET)).is_empty()


func test_two_restarts_and_bar_tube_report_attempts_and_tube() -> void:
	var cost: int = int(GameConfig.get_value("extra_tube_cost_coins"))
	var level := _level_of(_new_app(LEVEL_NO, cost))
	level.restart()
	level.restart()
	assert_bool(level.offers.assist_buy_extra_tube()).is_true()
	_solve(level, LEVEL_NO)
	assert_array(_values("level:fail:attempt:" + BRACKET)).contains_exactly([1, 2])
	assert_array(_values("level:complete:attempt:" + BRACKET)).contains_exactly([3])
	assert_array(_values("level:complete:tube:" + BRACKET)).contains_exactly([1])


func test_resume_after_focus_out_keeps_attempt_number() -> void:
	var cost: int = int(GameConfig.get_value("extra_tube_cost_coins"))
	var level := _level_of(_new_app(LEVEL_NO, cost))
	level.restart()
	level.restart()
	assert_bool(level.offers.assist_buy_extra_tube()).is_true()
	(level.get_parent() as App).notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var app2: App = auto_free(App.new())
	app2.clock = TestClock.ticking(_t)
	app2.effects_enabled = false
	app2.notifications = _notif
	add_child(app2)
	var resumed := _level_of(app2)
	assert_int(resumed.round.counters.restarts + 1).is_equal(3)
	_solve(resumed, LEVEL_NO)
	assert_array(_values("level:complete:attempt:" + BRACKET)).contains_exactly([3])
	assert_array(_values("level:complete:tube:" + BRACKET)).contains_exactly([1])


func test_daily_emits_no_attempt_events() -> void:
	var app := _new_app(LEVEL_NO, 0)
	var level := _level_of(app)
	level.start_daily(DailyRewards.utc_day_from_unix(TestClock.FIXED_UNIX))
	level.restart()
	var seed_day: Dictionary = level.round.to_dict()
	assert_int(int(seed_day["restarts"])).is_equal(1)
	for e: Dictionary in _fake.events:
		assert_bool(str(e.get("event_id", "")).contains(":attempt:")).is_false()
		assert_bool(str(e.get("event_id", "")).contains("complete:tube:")).is_false()


func test_brackets_ids_match_ranges() -> void:
	assert_str(LevelBrackets.id_for(1)).is_equal("lv1_7")
	assert_str(LevelBrackets.id_for(8)).is_equal("lv8_25")
	assert_str(LevelBrackets.id_for(55)).is_equal("lv26_55")
	assert_str(LevelBrackets.id_for(56)).is_equal("lv56p")
	assert_int(LevelBrackets.IDS.size()).is_equal(LevelBrackets.RANGES.size())
