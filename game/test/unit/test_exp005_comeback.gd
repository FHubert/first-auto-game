extends GdUnitTestSuite
## EXP-005: paczka h5_comeback_2, mechanizm grace/reset i event opt-outu powiadomien.

const SAVE_PATH: String = "user://test_exp005.json"
const DAY: int = 20750

var _old_path: String
var _prev_provider: AnalyticsProvider
var _fake: FakeAnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)
	_prev_provider = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake


func after_test() -> void:
	GameConfig.reset()
	Analytics.provider = _prev_provider
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path


func _package() -> Dictionary:
	var path: String = (
		ProjectSettings
		. globalize_path("res://")
		. path_join("../docs/remote_config/h5_comeback_2.json")
		. simplify_path()
	)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	return JSON.parse_string(file.get_as_text())


func _state() -> GameState:
	var s := GameState.new()
	s.settings["tutorial_done"] = true
	s.level = 1
	s.streak_days = 3
	s.last_play_utc_day = DAY
	return s


func test_h5_comeback_in_local_day_plus_2() -> void:
	assert_int(GameConfig.apply_remote(_package())).is_equal(2)
	var hour: int = int(GameConfig.get_value("notif_local_hour"))
	for tz: int in [0, 120]:
		var st := _state()
		st.streak_days = 0
		var plan: Array[Dictionary] = NotificationPlanner.plan(TestClock.FIXED_UNIX, tz, st)
		assert_int(plan.size()).is_equal(1)
		assert_str(plan[0].kind).is_equal("comeback")
		assert_int(plan[0].fire_unix).is_equal((DAY + 2) * 86400 + hour * 3600 - tz * 60)


func test_return_on_day_2_is_grace_day_3_is_reset() -> void:
	var s := _state()
	assert_str(DailyRewards.streak_status(s, DAY + 2)).is_equal("grace")
	assert_bool(DailyRewards.can_save_streak(s, DAY + 2)).is_true()
	assert_str(DailyRewards.streak_status(s, DAY + 3)).is_equal("reset")
	assert_bool(DailyRewards.can_save_streak(s, DAY + 3)).is_false()


func test_notifications_toggle_tracks_once_per_change() -> void:
	var sc: SettingsScreen = auto_free(load("res://src/ui/settings_screen.tscn").instantiate())
	sc.state = GameState.new()
	add_child(sc)
	sc.apply_from_state()
	assert_int(_count("settings:notifications:off") + _count("settings:notifications:on")).is_zero()
	sc.notifications_toggle.button_pressed = false
	assert_int(_count("settings:notifications:off")).is_equal(1)
	sc.apply_from_state()
	assert_int(_count("settings:notifications:off")).is_equal(1)
	sc.notifications_toggle.button_pressed = true
	assert_int(_count("settings:notifications:on")).is_equal(1)


func _count(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake.events:
		if e.get("event_id", "") == id:
			n += 1
	return n
