extends GdUnitTestSuite
## Straznik end-to-end pomocy na plateau przez App: restart, pasek, zakup, zapis (T-181).

const SAVE_PATH: String = "user://test_plateau_assist_flow.json"
const EV_OFFERED: String = "level:assist:offered"

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


func _level_of(app: App) -> Level:
	app.current_screen().play_pressed.emit()
	return app.current_screen() as Level


func _new_level(level_no: int, coins: int) -> Level:
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
	return _level_of(app)


func _app_of(level: Level) -> App:
	return level.get_parent() as App


func _count(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake.events:
		if str(e.get("event_id", "")) == id:
			n += 1
	return n


func _min_level() -> int:
	return int(GameConfig.get_value("plateau_assist_min_level"))


func _from() -> int:
	return int(GameConfig.get_value("plateau_assist_from_attempt"))


func _cost() -> int:
	return int(GameConfig.get_value("extra_tube_cost_coins"))


func _restart_until_attempt(level: Level, attempt: int) -> void:
	for n in range(1, attempt):
		assert_bool(level.assist_bar.visible).is_false()
		level.restart()


func test_coins_scenario_bar_purchase_events() -> void:
	var level := _new_level(_min_level(), _cost() + 40)
	_restart_until_attempt(level, _from())
	assert_int(level.round.counters.restarts + 1).is_equal(_from())
	assert_bool(level.assist_bar.visible).is_true()
	assert_int(_count(EV_OFFERED)).is_equal(1)
	level.assist_bar.coins_pressed.emit()
	assert_int(level.round.to_dict()["extra_tubes_added"]).is_equal(1)
	assert_int(_app_of(level).state.coins).is_equal(40)
	assert_int(_count("level:assist:coins")).is_equal(1)
	assert_int(_count("booster:extra_tube:coins")).is_equal(1)
	assert_bool(level.assist_bar.visible).is_false()


func test_save_and_resume_keeps_extra_tube_without_bar() -> void:
	var level := _new_level(_min_level(), _cost())
	_restart_until_attempt(level, _from())
	level.assist_bar.coins_pressed.emit()
	_app_of(level).notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var app2: App = auto_free(App.new())
	app2.clock = TestClock.ticking(_t)
	app2.effects_enabled = false
	app2.notifications = _notif
	add_child(app2)
	var resumed := _level_of(app2)
	assert_int(resumed.round.to_dict()["extra_tubes_added"]).is_equal(1)
	assert_bool(resumed.assist_bar.visible).is_false()


func test_rewarded_scenario_only_ad_button() -> void:
	var level := _new_level(_min_level(), 0)
	_restart_until_attempt(level, _from())
	assert_bool(level.assist_bar.visible).is_true()
	assert_bool(level.assist_bar.ad_button.visible).is_true()
	assert_bool(level.assist_bar.coins_button.visible).is_false()
	level.assist_bar.ad_pressed.emit()
	assert_int(level.round.to_dict()["extra_tubes_added"]).is_equal(1)
	assert_int(_count("level:assist:rewarded")).is_equal(1)
	assert_int(_app_of(level).state.coins).is_equal(0)


func test_no_offer_below_threshold_and_in_daily() -> void:
	var low := _new_level(_min_level() - 1, _cost())
	for i in _from():
		low.restart()
	assert_int(_count(EV_OFFERED)).is_equal(0)
	var app := _app_of(low)
	app.state.level = _min_level()
	app.show_home()
	app.show_daily_level()
	var daily := app.current_screen() as Level
	for i in _from():
		daily.restart()
	assert_bool(daily.assist_bar.visible).is_false()
	assert_int(_count(EV_OFFERED)).is_equal(0)


func test_attempt_threshold_comes_from_config() -> void:
	GameConfig.set_for_test("plateau_assist_from_attempt", 2)
	var level := _new_level(_min_level(), _cost())
	assert_bool(level.assist_bar.visible).is_false()
	level.restart()
	assert_bool(level.assist_bar.visible).is_true()
	assert_int(_count(EV_OFFERED)).is_equal(1)
