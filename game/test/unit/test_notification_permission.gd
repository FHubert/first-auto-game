extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_notification_permission.json"
const ND: String = NotificationProvider.PERMISSION_NOT_DETERMINED

var _old_path: String
var _prev_provider: AnalyticsProvider
var _fake_analytics: FakeAnalyticsProvider
var _fake: FakeNotificationProvider
var _t: Array[int] = [TestClock.FIXED_UNIX]


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)
	_prev_provider = Analytics.provider
	_fake_analytics = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_analytics
	_fake = FakeNotificationProvider.new()
	_fake.permission = ND
	_t = [TestClock.FIXED_UNIX]


func after_test() -> void:
	Analytics.provider = _prev_provider
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path


func _state(daily: int = 1, tutorial: bool = true, notif_on: bool = true) -> GameState:
	var s := GameState.new()
	s.settings[GameState.SETTING_TUTORIAL_DONE] = tutorial
	s.settings[GameState.SETTING_NOTIFICATIONS_ON] = notif_on
	s.daily_completed_total = daily
	s.daily_reward_last_claim_day = TestClock.FIXED_DAY
	return s


func _app(state: GameState) -> App:
	var app: App = auto_free(App.new())
	app.clock = TestClock.ticking(_t)
	app.tz_offset = func() -> int: return 0
	app.notifications = _fake
	app.state = state
	add_child(app)
	return app


func _count(event_id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_analytics.events:
		if e.get("event_id", "") == event_id:
			n += 1
	return n


func _count_scheduled_events() -> int:
	var n: int = 0
	for e: Dictionary in _fake_analytics.events:
		if str(e.get("event_id", "")).begins_with("notif:scheduled:"):
			n += 1
	return n


func test_asks_once_after_first_daily_level() -> void:
	var app: App = _app(_state())
	assert_int(_fake.permission_requests).is_equal(1)
	app.show_level()
	app.show_home()
	assert_int(_fake.permission_requests).is_equal(1)


func test_no_ask_before_first_daily_level() -> void:
	_app(_state(0))
	assert_int(_fake.permission_requests).is_equal(0)


func test_no_ask_before_tutorial_done() -> void:
	var app: App = _app(_state(1, false))
	app.show_home()
	assert_int(_fake.permission_requests).is_equal(0)


func test_no_ask_when_notifications_off() -> void:
	_app(_state(1, true, false))
	assert_int(_fake.permission_requests).is_equal(0)


func test_not_required_never_asks() -> void:
	_fake.permission = NotificationProvider.PERMISSION_NOT_REQUIRED
	_app(_state())
	assert_int(_fake.permission_requests).is_equal(0)


func test_flag_saved_before_answer() -> void:
	_fake.hold_permission = true
	var app: App = _app(_state())
	assert_int(_fake.permission_requests).is_equal(1)
	var loaded: GameState = SaveSystem.load()
	assert_bool(bool(loaded.settings[GameState.SETTING_NOTIF_PERMISSION_ASKED])).is_true()
	app.show_home()
	assert_int(_fake.permission_requests).is_equal(1)
	assert_int(_count("notif:permission:granted")).is_equal(0)
	_fake.release_permission(NotificationProvider.PERMISSION_GRANTED)
	assert_int(_count("notif:permission:granted")).is_equal(1)


func test_denied_next_start_neither_asks_nor_schedules() -> void:
	_fake.permission_answer = NotificationProvider.PERMISSION_DENIED
	var app: App = _app(_state())
	assert_int(_count("notif:permission:denied")).is_equal(1)
	app.free()
	var app2: App = _app(SaveSystem.load())
	app2._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(_fake.permission_requests).is_equal(1)
	assert_int(_fake.scheduled.size()).is_equal(0)
	assert_int(_count_scheduled_events()).is_equal(0)


func test_granted_schedules_on_focus_out() -> void:
	var app: App = _app(_state())
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(_count("notif:permission:granted")).is_equal(1)
	assert_int(_fake.scheduled.size()).is_greater(0)
	assert_int(_count_scheduled_events()).is_equal(_fake.scheduled.size())


func test_should_ask_table() -> void:
	assert_bool(NotificationPermission.should_ask(_state(), ND)).is_true()
	assert_bool(NotificationPermission.should_ask(_state(0), ND)).is_false()
	assert_bool(NotificationPermission.should_ask(_state(1, false), ND)).is_false()
	assert_bool(NotificationPermission.should_ask(_state(1, true, false), ND)).is_false()
	for st: String in ["granted", "denied", "not_required"]:
		assert_bool(NotificationPermission.should_ask(_state(), st)).is_false()
	var asked: GameState = _state()
	asked.settings[GameState.SETTING_NOTIF_PERMISSION_ASKED] = true
	assert_bool(NotificationPermission.should_ask(asked, ND)).is_false()
