extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_level_complete_month.json"
const WIN_COINS_WITH_BONUS: int = 350

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
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


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


func test_goal_day_shows_message_and_bonus_coins() -> void:
	await _start(int(GameConfig.get_value("daily_month_goal")) - 1)
	var lc: LevelComplete = _level.level_complete
	assert_bool(lc.progress_label.visible).is_true()
	var bonus: int = int(GameConfig.get_value("daily_month_goal_coins"))
	assert_str(lc.progress_label.text).is_equal(tr("lc_month_goal") % bonus)
	assert_str(lc.coins_label.text).is_equal(tr("lc_coins") % WIN_COINS_WITH_BONUS)
	var tubes: Rect2 = _level.board.tube_rect(0)
	for i in _level.round.board().tube_count():
		tubes = tubes.merge(_level.board.tube_rect(i))
	assert_bool(lc.panel_rect().intersects(tubes)).is_false()


func test_normal_day_has_no_message() -> void:
	await _start(3)
	assert_bool(_level.level_complete.progress_label.visible).is_false()
