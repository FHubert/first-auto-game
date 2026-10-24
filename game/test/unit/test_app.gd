extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_app.json"

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
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _app(tutorial_done: bool) -> App:
	var app: App = auto_free(App.new())
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
