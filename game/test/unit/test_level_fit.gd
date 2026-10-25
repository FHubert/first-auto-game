extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_level_fit.json"

var _level: Level
var _old_path: String
var _coins_before: int
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
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.clock = TestClock.fixed()
	_coins_before = _level.state.coins
	add_child(_level)


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


func _win() -> void:
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	var sol: Array = ContentGenerator.new().generate(seed_value, 1)["payload"]["solution"]
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func test_win_panel_grows_with_long_progress_message() -> void:
	_level.size = Vector2(720, 1280)
	_level.load_level(1)
	ScreenshotFixtures.apply_win(_level)
	_level.level_complete.progress_label.visible = true
	_level.level_complete.progress_label.text = "Dluga wiadomosc ".repeat(13).substr(0, 200)
	await get_tree().process_frame
	await get_tree().process_frame
	_level.fit_board_above_panel()
	await get_tree().process_frame
	var lc: LevelComplete = _level.level_complete
	var panel: Rect2 = lc.panel_rect()
	var margin: float = -lc.get_node("Panel").offset_bottom
	assert_float(panel.size.y).is_equal_approx(lc.panel_height() - margin, 0.5)
	var tubes: Rect2 = _level.board.tube_rect(0)
	for i in _level.round.board().tube_count():
		tubes = tubes.merge(_level.board.tube_rect(i))
	assert_bool(panel.intersects(tubes)).is_false()


func _board_height_for(tube_count: int) -> float:
	var tubes: Array = []
	for i in tube_count:
		tubes.append([i % 2, i % 2])
	var r := GameRound.new()
	var payload: Dictionary = {
		"capacity": 4,
		"colors": 2,
		"tubes": tubes,
		"min_moves": 1,
		"min_moves_exact": true,
		"solution": [],
	}
	r.start({"seed": 1, "level": 1, "difficulty": 0.0, "payload": payload})
	var view: BoardView = auto_free(BoardView.new())
	add_child(view)
	view.setup(r, "classic")
	return view.content_height()


func test_board_content_height_grows_with_rows() -> void:
	var one: float = _board_height_for(4)
	var two: float = _board_height_for(14)
	assert_float(one).is_greater(0.0)
	assert_float(two).is_greater(one)


func test_restart_after_win_resets_board_fit() -> void:
	_win()
	_level.restart()
	assert_float(_level.board.offset_top).is_equal(0.0)
	assert_float(_level.board.offset_bottom).is_equal(0.0)


func test_hud_height_matches_bar_height_in_scene() -> void:
	assert_float(_level.hud.offset_bottom).is_equal(Hud.BAR_HEIGHT)
