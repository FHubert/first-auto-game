extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_daily_ui.json"
const DAY: int = 20750

var _old_path: String
var _now: Array[int] = [DAY * 86400 + 3600]


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()
	_now[0] = DAY * 86400 + 3600


func after_test() -> void:
	_cleanup()
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _cleanup() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _app(state: GameState = null) -> App:
	var app: App = auto_free(App.new())
	app.state = state if state != null else GameState.new()
	app.state.settings["tutorial_done"] = true
	app.clock = func() -> int: return _now[0]
	add_child(app)
	return app


func _popup(app: App) -> DailyRewardPopup:
	for c in app.get_children():
		if c is DailyRewardPopup:
			return c
	return null


func test_popup_claim_once_per_day() -> void:
	var app := _app()
	assert_bool(app.popup_visible()).is_true()
	var popup := _popup(app)
	popup.claim_button.pressed.emit()
	assert_int(app.state.coins).is_equal(DailyRewards.reward_for_cycle_day(1))
	assert_int(app.state.streak_days).is_equal(1)
	assert_bool(app.popup_visible()).is_false()
	app.show_home()
	assert_bool(app.popup_visible()).is_false()


func test_next_day_shows_day_two() -> void:
	var state := GameState.new()
	var app := _app(state)
	_popup(app).claim_button.pressed.emit()
	var app2 := _app(state)
	assert_bool(app2.popup_visible()).is_false()
	_now[0] += 86400
	var app3 := _app(state)
	assert_bool(app3.popup_visible()).is_true()
	assert_int(DailyRewards.preview(state, DAY + 1)["cycle_day"]).is_equal(2)


func test_grace_offers_save_streak() -> void:
	var state := GameState.new()
	state.streak_days = 3
	state.last_play_utc_day = DAY - 2
	state.daily_reward_last_claim_day = DAY - 2
	var app := _app(state)
	var popup := _popup(app)
	assert_bool(popup.save_streak_button.visible).is_true()
	popup.save_streak_button.pressed.emit()
	assert_bool(DailyRewards.can_save_streak(state, DAY)).is_false()
	assert_bool(popup.save_streak_button.visible).is_false()
	popup.claim_button.pressed.emit()
	assert_int(state.streak_days).is_equal(4)


func test_home_daily_card() -> void:
	var state := GameState.new()
	state.level = 1
	var app := _app(state)
	app._close_popup()
	var home := app.current_screen() as Home
	assert_bool(home.daily_button.disabled).is_true()
	assert_str(home.daily_status_label.text).contains("3")
	assert_str(home.daily_timer_label.text).contains(":")
	state.level = 5
	home.refresh()
	assert_bool(home.daily_button.disabled).is_false()
	DailyChallenge.complete(state, DAY, {"won": true})
	home.refresh()
	assert_bool(home.daily_button.disabled).is_true()
	assert_str(home.daily_status_label.text).is_equal(tr("daily_done"))


func test_home_daily_card_spacing() -> void:
	var app := _app()
	app._close_popup()
	var home := app.current_screen() as Home
	await get_tree().process_frame
	await get_tree().process_frame
	var btn_y: float = home.daily_button.global_position.y
	var timer_bottom: float = (
		home.daily_timer_label.global_position.y + home.daily_timer_label.size.y
	)
	var status_bottom: float = (
		home.daily_status_label.global_position.y + home.daily_status_label.size.y
	)
	assert_float(btn_y - timer_bottom).is_greater_equal(float(Home.CARD_SEPARATION))
	assert_float(btn_y - status_bottom).is_greater_equal(float(Home.CARD_SEPARATION))


func test_daily_level_flow() -> void:
	var state := GameState.new()
	state.level = 5
	var app := _app(state)
	app._close_popup()
	app.show_daily_level()
	var level := app.current_screen() as Level
	assert_bool(level != null).is_true()
	assert_str(level.mode).is_equal("daily")
	var sol: Array = DailyChallenge.level_for_day(DAY)["payload"]["solution"]
	for i in sol.size() - 1:
		level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	level.board.tap(last.x)
	level.board.tap(last.y)
	assert_int(state.coins).is_equal(DailyChallenge.reward_amount())
	assert_int(state.level).is_equal(5)
	assert_int(state.daily_completed_total).is_equal(1)
	level.stuck_panel.show_for(level.round, false)
	assert_bool(level.stuck_panel.skip_button.visible).is_false()
	level.on_next_pressed()
	assert_bool(app.current_screen() is Home).is_true()


func test_claim_x2_doubles_once() -> void:
	var app := _app()
	var popup := _popup(app)
	var expected: int = popup.preview_x2_amount()
	assert_int(expected).is_equal(DailyRewards.reward_for_cycle_day(1) * 2)
	assert_bool(popup.claim_x2()).is_true()
	assert_int(app.state.coins).is_equal(expected)
	assert_int(app.state.daily_reward_last_claim_day).is_equal(DAY)
	assert_bool(popup.claim_x2()).is_false()
	assert_int(app.state.coins).is_equal(expected)


func test_claim_x2_button_visibility() -> void:
	var prev: AdProvider = Ads.provider
	var app := _app()
	var popup := _popup(app)
	assert_bool(popup.claim_x2_button.visible).is_true()
	assert_str(popup.claim_x2_button.text).contains(str(popup.preview_x2_amount()))
	var fake := FakeAdProvider.new()
	fake.always_ready = false
	Ads.provider = fake
	popup.show_for(app.state, DAY)
	Ads.provider = prev
	assert_bool(popup.claim_x2_button.visible).is_false()
