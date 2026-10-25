extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_level_complete_month.json"

var _level: Level
var _old_path: String
var _prev_provider: AdProvider
var _prev_clock: Callable
var _prev_shown: int


func before_test() -> void:
	_prev_provider = Ads.provider
	_prev_clock = Ads.clock
	_prev_shown = Ads.interstitials_shown
	Ads.reset_break()
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	_cleanup()
	SaveSystem.save_path = _old_path
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	Ads.interstitials_shown = _prev_shown
	Ads.reset_break()
	GameConfig.reset()


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _bonus() -> int:
	return int(GameConfig.get_value("daily_month_goal_coins"))


## Wygrana Poziomu dnia w dniu osiagniecia celu: nagroda dnia + premia miesiaca.
func _win_coins_with_bonus() -> int:
	return DailyChallenge.reward_amount() + _bonus()


func _start(month_count: int) -> void:
	var st := GameState.new()
	st.level = int(GameConfig.get_value("daily_unlock_level"))
	st.daily_month_id = DailyChallenge.month_id(TestClock.FIXED_DAY)
	st.daily_month_count = month_count
	st.daily_last_completed_day = TestClock.FIXED_DAY - 1
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = st
	_level.clock = TestClock.fixed()
	_level.autoload_level = false
	_level.size = Vector2(720, 1280)
	add_child(_level)
	_level.start_daily(TestClock.FIXED_DAY)
	var sol: Array = (
		ContentGenerator.new().generate_daily(TestClock.FIXED_DAY)["payload"]["solution"]
	)
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)
	await get_tree().process_frame
	await get_tree().process_frame


func _assert_panel_fits(lc: LevelComplete) -> void:
	assert_bool(lc.btn_copy_result.visible).is_true()
	var expected_tubes: int = (
		int(GameConfig.get_value("daily_colors")) + int(GameConfig.get_value("empty_tubes"))
	)
	assert_int(_level.round.board().tube_count()).is_equal(expected_tubes)
	var margin: float = -lc.get_node("Panel").offset_bottom
	assert_float(lc.panel_rect().size.y).is_equal_approx(lc.panel_height() - margin, 0.5)
	var tubes: Rect2 = _level.board.tube_rect(0)
	for i in _level.round.board().tube_count():
		tubes = tubes.merge(_level.board.tube_rect(i))
	assert_bool(lc.panel_rect().intersects(tubes)).is_false()


func test_goal_day_shows_message_and_bonus_coins() -> void:
	await _start(DailyChallenge.month_goal() - 1)
	var lc: LevelComplete = _level.level_complete
	assert_bool(lc.progress_label.visible).is_true()
	assert_str(lc.progress_label.text).is_equal(tr("lc_month_goal") % _bonus())
	assert_str(lc.coins_label.text).is_equal(tr("lc_coins") % _win_coins_with_bonus())
	_assert_panel_fits(lc)


func test_goal_message_stays_after_double_coins() -> void:
	await _start(DailyChallenge.month_goal() - 1)
	_level._on_double_coins_granted(_win_coins_with_bonus())
	var lc: LevelComplete = _level.level_complete
	assert_bool(lc.progress_label.visible).is_true()
	assert_str(lc.progress_label.text).is_equal(tr("lc_month_goal") % _bonus())


func test_custom_goal_from_config_gives_bonus() -> void:
	GameConfig.set_for_test("daily_month_goal", 3)
	await _start(2)
	assert_str(_level.level_complete.progress_label.text).is_equal(tr("lc_month_goal") % _bonus())
	assert_str(_level.level_complete.coins_label.text).is_equal(
		tr("lc_coins") % _win_coins_with_bonus()
	)


func test_normal_day_has_no_message() -> void:
	await _start(3)
	assert_bool(_level.level_complete.progress_label.visible).is_false()
	_assert_panel_fits(_level.level_complete)


func test_daily_win_hides_theme_bar_and_breakdown() -> void:
	await _start(3)
	assert_bool(_level.level_complete.theme_row.visible).is_false()
	assert_bool(_level.level_complete.breakdown_label.visible).is_false()
