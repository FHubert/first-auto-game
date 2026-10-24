extends GdUnitTestSuite
## Testy NotificationPlanner (czysta logika, czas wstrzykiwany).

const DAY: int = 20750
const NOW: int = TestClock.FIXED_UNIX


func before_test() -> void:
	GameConfig.reset()


func after_test() -> void:
	GameConfig.reset()


func _state(level: int = 5, streak: int = 0) -> GameState:
	var s := GameState.new()
	s.settings["tutorial_done"] = true
	s.level = level
	s.streak_days = streak
	s.last_play_utc_day = DAY
	return s


func _tomorrow(tz: int, now_day: int = DAY) -> int:
	return (now_day + 1) * 86400 + 19 * 3600 - tz * 60


func test_disabled_returns_empty() -> void:
	var s := _state()
	s.settings["notifications_on"] = false
	assert_array(NotificationPlanner.plan(NOW, 0, s)).is_empty()


func test_tutorial_not_done_returns_empty() -> void:
	var s := _state()
	s.settings["tutorial_done"] = false
	assert_array(NotificationPlanner.plan(NOW, 0, s)).is_empty()


func test_streak_entry_tomorrow_local(tz: int, test_parameters := [[0], [120], [-300]]) -> void:
	assert_that(test_parameters).is_not_null()
	var plan: Array[Dictionary] = NotificationPlanner.plan(NOW, tz, _state(5, 5))
	assert_int(plan.size()).is_equal(2)
	assert_str(plan[0].kind).is_equal("streak")
	assert_int(plan[0].fire_unix).is_equal(_tomorrow(tz))
	assert_str(plan[0].title_key).is_equal("notif_streak_title")
	assert_str(plan[0].body_key).is_equal("notif_streak_body")


func test_low_streak_gives_daily() -> void:
	var plan: Array[Dictionary] = NotificationPlanner.plan(NOW, 0, _state(5, 1))
	assert_str(plan[0].kind).is_equal("daily")
	assert_str(plan[0].title_key).is_equal("notif_daily_title")


func test_streak_not_played_today_gives_daily() -> void:
	var s := _state(5, 5)
	s.last_play_utc_day = DAY - 1
	assert_str(NotificationPlanner.plan(NOW, 0, s)[0].kind).is_equal("daily")


func test_daily_locked_only_comeback() -> void:
	var plan: Array[Dictionary] = NotificationPlanner.plan(NOW, 0, _state(1, 1))
	assert_int(plan.size()).is_equal(1)
	assert_str(plan[0].kind).is_equal("comeback")


func test_comeback_fire_time() -> void:
	var plan: Array[Dictionary] = NotificationPlanner.plan(NOW, 120, _state(1, 0))
	assert_int(plan[0].fire_unix).is_equal((DAY + 3) * 86400 + 19 * 3600 - 120 * 60)


func test_late_evening_schedules_tomorrow() -> void:
	var now: int = DAY * 86400 + 23 * 3600 + 1800
	var plan: Array[Dictionary] = NotificationPlanner.plan(now, 0, _state(5, 5))
	assert_int(plan[0].fire_unix).is_equal(20751 * 86400 + 19 * 3600)


func test_sorted_ascending() -> void:
	var plan: Array[Dictionary] = NotificationPlanner.plan(NOW, -300, _state(5, 5))
	assert_bool(plan[0].fire_unix < plan[1].fire_unix).is_true()


func test_default_notifications_on() -> void:
	var s := GameState.from_dict({})
	assert_bool(bool(s.settings["notifications_on"])).is_true()


func test_fake_provider_records() -> void:
	var p := FakeNotificationProvider.new()
	p.schedule(1, 100, "t", "b")
	assert_int(p.scheduled.size()).is_equal(1)
	p.cancel_all()
	assert_int(p.scheduled.size()).is_equal(0)
	assert_int(p.cancel_calls).is_equal(1)
	assert_bool(NotificationProvider.new().is_available()).is_false()
