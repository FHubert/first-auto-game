extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_app.json"

const TEST_DAY: int = 20000
const TEST_NOW_UNIX: int = TEST_DAY * 86400 + 100

var _old_path: String
var _t: Array[int] = [TEST_NOW_UNIX]


func before_test() -> void:
	GameConfig.reset()
	_t[0] = TEST_NOW_UNIX
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()
	SaveSystem.save_path = _old_path


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _app(tutorial_done: bool) -> App:
	var app: App = auto_free(App.new())
	app.clock = func() -> int: return _t[0]
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = tutorial_done
	add_child(app)
	return app


func test_first_run_opens_level_one() -> void:
	var app := _app(false)
	assert_bool(app.current_screen() is Level).is_true()
	assert_int((app.current_screen() as Level).level_no).is_equal(1)


func test_navigation() -> void:
	var app := _app(true)
	assert_bool(app.current_screen() is Home).is_true()
	app.show_settings()
	assert_bool(app.current_screen() is SettingsScreen).is_true()
	(app.current_screen() as SettingsScreen).back_pressed.emit()
	assert_bool(app.current_screen() is Home).is_true()
	app.state.level = 4
	(app.current_screen() as Home).play_pressed.emit()
	assert_bool(app.current_screen() is Level).is_true()
	assert_int((app.current_screen() as Level).level_no).is_equal(4)
	(app.current_screen() as Level).pause_requested.emit()
	assert_bool(app.current_screen() is Home).is_true()
	await get_tree().process_frame


func test_shop_navigation() -> void:
	var app := _app(true)
	app.show_shop()
	assert_str(app.current_screen_name()).is_equal("shop")
	(app.current_screen() as ShopScreen).back_pressed.emit()
	assert_str(app.current_screen_name()).is_equal("home")
	app.show_shop("extra_tube", true)
	(app.current_screen() as ShopScreen).back_pressed.emit()
	assert_str(app.current_screen_name()).is_equal("level")
	await get_tree().process_frame


func _check_level_shop_overlay(app: App, expected_mode: String) -> void:
	var level := app.current_screen() as Level
	var from_to: Vector2i = level.round.hint()
	assert_bool(level.round.try_move(from_to.x, from_to.y)).is_true()
	var moves_before: int = level.round.moves()
	level.shop_requested.emit("hint")
	assert_bool(app.shop_overlay_visible()).is_true()
	assert_object(app.current_screen()).is_same(level)
	assert_str(app.current_screen_name()).is_equal("level")
	app.shop_overlay.back_pressed.emit()
	assert_bool(app.shop_overlay_visible()).is_false()
	assert_bool(is_instance_valid(level)).is_true()
	assert_object(app.current_screen()).is_same(level)
	assert_str(level.mode).is_equal(expected_mode)
	assert_int(level.round.moves()).is_equal(moves_before)


func test_shop_overlay_daily() -> void:
	var app := _app(true)
	app.show_daily_level()
	_check_level_shop_overlay(app, Level.MODE_DAILY)
	await get_tree().process_frame


func test_shop_overlay_campaign() -> void:
	var app := _app(true)
	app.show_level()
	_check_level_shop_overlay(app, Level.MODE_CAMPAIGN)
	await get_tree().process_frame


func test_shop_from_home_is_full_screen() -> void:
	var app := _app(true)
	app.show_home()
	app.show_shop()
	assert_str(app.current_screen_name()).is_equal("shop")
	assert_bool(app.shop_overlay_visible()).is_false()
	(app.current_screen() as ShopScreen).back_pressed.emit()
	assert_str(app.current_screen_name()).is_equal("home")
	await get_tree().process_frame


func test_shop_overlay_opens_once() -> void:
	var app := _app(true)
	app.show_level()
	app.show_shop("hint", true)
	app.show_shop("hint", true)
	var count: int = 0
	for c in app.get_children():
		if c is ShopScreen:
			count += 1
	assert_int(count).is_equal(1)
	await get_tree().process_frame


func test_daily_popup_hides_daily_card() -> void:
	var app := _app(true)
	var home := app.current_screen() as Home
	assert_bool(app.popup_visible()).is_true()
	assert_bool(home.daily_card.visible).is_false()
	app._popup.closed.emit()
	await get_tree().process_frame
	assert_bool(app.popup_visible()).is_false()
	assert_bool(home.daily_card.visible).is_true()


func test_session_start_and_end_events() -> void:
	var prev: AnalyticsProvider = Analytics.provider
	var fake := FakeAnalyticsProvider.new()
	Analytics.provider = fake
	var t: Array[int] = [1000]
	var app := _app(true)
	app.clock = func() -> int: return t[0]
	app.track_session_end()
	app.track_session_start()
	t[0] = 1030
	app.track_session_end()
	Analytics.provider = prev
	var ids: Array[String] = []
	for e in fake.events:
		ids.append(str(e["event_id"]))
	assert_array(ids).contains(["session:start", "session:end"])
	assert_float(fake.events[fake.events.size() - 1]["value"]).is_equal(30.0)


func _app_from_save() -> App:
	var app: App = auto_free(App.new())
	app.clock = func() -> int: return _t[0]
	app.state = SaveSystem.load()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	return app


func _play_moves(app: App, count: int) -> Level:
	var level := app.current_screen() as Level
	level.board.animate = false
	for i in count:
		var m: Vector2i = level.round.board().legal_moves()[0]
		level.board.tap(m.x)
		level.board.tap(m.y)
	return level


func test_focus_out_saves_and_new_app_resumes() -> void:
	var app := _app(true)
	app.show_level()
	var level := _play_moves(app, 3)
	var tubes: Array = level.round.board().tubes.duplicate(true)
	assert_int(level.round.moves()).is_equal(3)
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_str(SaveSystem.load().round_in_progress["mode"]).is_equal("campaign")
	remove_child(app)
	var app2 := _app_from_save()
	app2.show_level()
	var level2 := app2.current_screen() as Level
	assert_int(level2.round.moves()).is_equal(3)
	assert_array(level2.round.board().tubes).is_equal(tubes)
	assert_str(level2.hud.moves_label.text).contains("3")
	level2.round._done = true
	assert_dict(level2.snapshot()).is_empty()


func test_daily_from_yesterday_starts_fresh() -> void:
	var t: Array[int] = [86400 * 20000 + 100]
	var app := _app(true)
	app.clock = func() -> int: return t[0]
	app.show_daily_level()
	_play_moves(app, 1)
	app._save_round()
	assert_int(int(app.state.round_in_progress["utc_day"])).is_equal(20000)
	remove_child(app)
	t[0] += 86400
	var app2 := _app_from_save()
	app2.clock = func() -> int: return t[0]
	app2.show_daily_level()
	var level := app2.current_screen() as Level
	assert_int(level.round.moves()).is_equal(0)
	assert_int(level.utc_day).is_equal(20001)
	assert_dict(app2.state.round_in_progress).is_empty()


func test_resume_does_not_emit_level_start() -> void:
	var prev: AnalyticsProvider = Analytics.provider
	var fake := FakeAnalyticsProvider.new()
	Analytics.provider = fake
	var app := _app(true)
	app.show_level()
	_play_moves(app, 2)
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	remove_child(app)
	fake.events.clear()
	var app2 := _app_from_save()
	app2.show_level()
	Analytics.provider = prev
	var ids: Array[String] = []
	for e in fake.events:
		ids.append(str(e["event_id"]))
	assert_array(ids).not_contains(["level:start"])
	assert_array(ids).contains(["level:resume"])


func test_ad_about_to_show_saves_round() -> void:
	var app := _app(true)
	app.show_level()
	_play_moves(app, 1)
	Ads.ad_about_to_show.emit("interstitial")
	var snap: Dictionary = SaveSystem.load().round_in_progress
	assert_int(GameRound.from_dict(snap["round"]).moves()).is_equal(1)


func test_leaving_level_to_home_saves_and_play_resumes() -> void:
	var app := _app(true)
	app.show_level()
	_play_moves(app, 2)
	app.show_home()
	app.show_level()
	assert_int((app.current_screen() as Level).round.moves()).is_equal(2)
	await get_tree().process_frame


func _count(fake: FakeAnalyticsProvider, type: String, key: String, value: String) -> int:
	var n: int = 0
	for e in fake.events:
		if e["type"] == type and str(e.get(key, "")) == value:
			n += 1
	return n


func _with_fake() -> FakeAnalyticsProvider:
	var fake := FakeAnalyticsProvider.new()
	Analytics.provider = fake
	return fake


func test_pause_resume_win_has_single_start_no_fail() -> void:
	var prev: AnalyticsProvider = Analytics.provider
	var fake := _with_fake()
	var app := _app(true)
	app.show_level()
	_play_moves(app, 3)
	app.show_home()
	app.show_level()
	var level := app.current_screen() as Level
	assert_int(level.round.moves()).is_equal(3)
	var sol: Array = (
		ContentGenerator
		. new()
		. generate(int(GameConfig.get_value("campaign_seed", 1)), level.level_no)["payload"]["solution"]
	)
	level.board.animate = false
	level.round.restart()
	for m in sol:
		level.round.try_move(m.x, m.y)
	level._on_round_won()
	Analytics.provider = prev
	assert_int(_count(fake, "progression", "status", "Start")).is_equal(1)
	assert_int(_count(fake, "progression", "status", "Fail")).is_equal(0)
	assert_int(_count(fake, "progression", "status", "Complete")).is_equal(1)
	assert_dict(app.state.round_in_progress).is_empty()
	await get_tree().process_frame


func test_stale_daily_snapshot_is_abandoned_once() -> void:
	var prev: AnalyticsProvider = Analytics.provider
	var t: Array[int] = [86400 * 20000 + 100]
	var app := _app(true)
	app.clock = func() -> int: return t[0]
	app.show_daily_level()
	_play_moves(app, 1)
	app._save_round()
	remove_child(app)
	t[0] += 86400
	var app2 := _app_from_save()
	app2.clock = func() -> int: return t[0]
	var fake := _with_fake()
	app2.show_daily_level()
	Analytics.provider = prev
	assert_int(_count(fake, "design", "event_id", "level:fail:abandon")).is_equal(1)
	assert_int(_count(fake, "progression", "status", "Fail")).is_equal(1)
	assert_int(_count(fake, "progression", "l2", "daily_20000")).is_equal(1)
	assert_dict(app2.state.round_in_progress).is_empty()
	await get_tree().process_frame


func test_campaign_snapshot_abandoned_by_daily() -> void:
	var prev: AnalyticsProvider = Analytics.provider
	var app := _app(true)
	app.show_level()
	_play_moves(app, 1)
	app._save_round()
	var fake := _with_fake()
	app.show_daily_level()
	Analytics.provider = prev
	assert_int(_count(fake, "design", "event_id", "level:fail:abandon")).is_equal(1)
	assert_int(_count(fake, "progression", "l2", "level_0001")).is_equal(1)
	await get_tree().process_frame


func test_daily_snapshot_abandoned_by_campaign_and_empty_is_silent() -> void:
	var prev: AnalyticsProvider = Analytics.provider
	var app := _app(true)
	var fake := _with_fake()
	app._discard_snapshot()
	assert_int(fake.events.size()).is_equal(0)
	app.state.round_in_progress = {"mode": "daily", "level_no": "x", "utc_day": 5}
	app.show_level()
	Analytics.provider = prev
	assert_int(_count(fake, "design", "event_id", "level:fail:abandon")).is_equal(1)
	assert_int(_count(fake, "progression", "l2", "daily_5")).is_equal(1)
	assert_dict(app.state.round_in_progress).is_empty()
	await get_tree().process_frame
