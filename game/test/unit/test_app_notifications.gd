extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_app_notifications.json"
const STREAK_DAYS: int = 3
const TZ_UTC: int = 0
const PREFIX: String = "notif:scheduled:"

var _old_path: String
var _prev_provider: AnalyticsProvider
var _fake_analytics: FakeAnalyticsProvider
var _fake: FakeNotificationProvider
var _t: Array[int] = [TestClock.FIXED_UNIX]


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()
	_prev_provider = Analytics.provider
	_fake_analytics = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_analytics
	_fake = FakeNotificationProvider.new()
	_t = [TestClock.FIXED_UNIX]


func after_test() -> void:
	Analytics.provider = _prev_provider
	_cleanup()
	SaveSystem.save_path = _old_path


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _app(streak: int, played_today: bool) -> App:
	var app: App = auto_free(App.new())
	app.clock = TestClock.ticking(_t)
	app.tz_offset = func() -> int: return TZ_UTC
	app.notifications = _fake
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	app.state.streak_days = streak
	if played_today:
		app.state.last_play_utc_day = TestClock.FIXED_DAY
	app.state.daily_reward_last_claim_day = TestClock.FIXED_DAY
	add_child(app)
	return app


func _count_events(event_id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_analytics.events:
		if e.get("event_id", "") == event_id:
			n += 1
	return n


func _count_scheduled_events() -> int:
	var n: int = 0
	for e: Dictionary in _fake_analytics.events:
		if str(e.get("event_id", "")).begins_with(PREFIX):
			n += 1
	return n


func _assert_streak_and_comeback(app: App) -> void:
	assert_int(_fake.scheduled.size()).is_equal(2)
	var plan: Array[Dictionary] = NotificationPlanner.plan(_t[0], TZ_UTC, app.state)
	assert_int(plan.size()).is_equal(2)
	var by_id: Dictionary = {}
	for e: Dictionary in _fake.scheduled:
		by_id[int(e["id"])] = e
	assert_array(by_id.keys()).contains_exactly_in_any_order([1, 3])
	for p: Dictionary in plan:
		var id: int = int(App.NOTIF_IDS[str(p["kind"])])
		assert_int(int((by_id[id] as Dictionary)["fire_unix"])).is_equal(int(p["fire_unix"]))
	var streak: Dictionary = by_id[1]
	assert_str(str(streak["title"])).is_equal(tr("notif_streak_title"))
	assert_str(str(streak["body"])).contains(str(STREAK_DAYS))


func test_focus_out_schedules_streak_and_comeback() -> void:
	var app := _app(STREAK_DAYS, true)
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_assert_streak_and_comeback(app)
	assert_int(_count_events(PREFIX + "streak")).is_equal(1)
	assert_int(_count_events(PREFIX + "comeback")).is_equal(1)


func test_wm_close_request_schedules() -> void:
	var app := _app(STREAK_DAYS, true)
	app._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	_assert_streak_and_comeback(app)


func test_focus_in_cancels() -> void:
	var app := _app(STREAK_DAYS, true)
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(_fake.scheduled.size()).is_equal(2)
	var calls: int = _fake.cancel_calls
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_array(_fake.scheduled).is_empty()
	assert_int(_fake.cancel_calls).is_equal(calls + 1)


func test_notifications_off_schedules_nothing() -> void:
	var app := _app(STREAK_DAYS, true)
	app.state.settings["notifications_on"] = false
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_array(_fake.scheduled).is_empty()
	assert_int(_count_scheduled_events()).is_equal(0)


func test_settings_toggle_saves_setting() -> void:
	var app := _app(STREAK_DAYS, true)
	app.show_settings()
	var toggle: CheckButton = (app.current_screen() as SettingsScreen).notifications_toggle
	assert_bool(toggle.button_pressed).is_true()
	var calls: int = _fake.cancel_calls
	toggle.button_pressed = false
	assert_bool(bool(app.state.settings["notifications_on"])).is_false()
	assert_bool(bool(SaveSystem.load().settings["notifications_on"])).is_false()
	assert_int(_fake.cancel_calls).is_greater(calls)
	toggle.button_pressed = true
	assert_bool(bool(app.state.settings["notifications_on"])).is_true()
	assert_bool(bool(SaveSystem.load().settings["notifications_on"])).is_true()


func test_unavailable_provider_makes_no_calls() -> void:
	var app := _app(STREAK_DAYS, true)
	app.notifications = NotificationProvider.new()
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_int(_count_scheduled_events()).is_equal(0)
