extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_level_fit.json"
## Szerokosc probowki (px) po apply_win zmierzona na main PRZED T-302 (720x1280 i 720x1560 -
## identyczna, skala ograniczona szerokoscia): poziom 8 (6 probowek) i 56 (14 probowek).
const BASE_TUBE_W_LV8: float = 55.18593
const BASE_TUBE_W_LV56: float = 22.4031

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
	UiTestFit.fit_root(_level, Vector2(720, 1280))
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
	assert_float(_level.board.offset_top).is_equal(float(UiTokens.HUD_TOP_H))
	assert_float(_level.board.offset_bottom).is_equal(float(-UiTokens.HUD_BOTTOM_H))


func test_hud_height_matches_bar_height_in_scene() -> void:
	await get_tree().process_frame
	assert_float(_level.hud.top_bar.size.y).is_equal(float(UiTokens.HUD_TOP_H))
	assert_float(_level.hud.bottom_bar.size.y).is_equal(float(UiTokens.HUD_BOTTOM_H))
	_level.load_level(1)
	assert_float(_level.board.offset_top).is_equal(float(UiTokens.HUD_TOP_H))
	assert_float(_level.board.offset_bottom).is_equal(float(-UiTokens.HUD_BOTTOM_H))


func _assert_win_single_row(screen: Vector2) -> void:
	UiTestFit.fit_root(_level, screen)
	var tubes: Array = []
	for i in 8:
		tubes.append([i % 2, i % 2])
	var payload: Dictionary = {
		"capacity": 4,
		"colors": 2,
		"tubes": tubes,
		"min_moves": 1,
		"min_moves_exact": true,
		"solution": [],
	}
	_level.start_round({"seed": 1, "level": 1, "difficulty": 0.0, "payload": payload}, "classic")
	ScreenshotFixtures.apply_win(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	var lc: LevelComplete = _level.level_complete
	var n: int = _level.round.board().tube_count()
	var y0: float = _level.board.tube_rect(0).position.y
	for i in n:
		var r: Rect2 = _level.board.tube_rect(i)
		assert_bool(r.intersects(lc.header_rect())).is_false()
		assert_bool(r.intersects(lc.panel_rect())).is_false()
		assert_float(r.position.y).is_equal_approx(y0, 0.01)
	assert_int(_level.board.columns_for(n, true)).is_equal(n)


func test_win_single_row_720x1280() -> void:
	await _assert_win_single_row(Vector2(720, 1280))


func test_win_single_row_720x1560() -> void:
	await _assert_win_single_row(Vector2(720, 1560))


func test_stuck_board_not_under_panel_720x1280() -> void:
	UiTestFit.fit_root(_level, Vector2(720, 1280))
	_level.load_level(1)
	_level.stuck_panel.show_for(_level.round, true, _level.offers.ad_offers())
	_level.stuck_panel.show_sample_rows()
	await get_tree().process_frame
	await get_tree().process_frame
	_level.fit_board_above_stuck()
	await get_tree().process_frame
	var panel: Rect2 = _level.stuck_panel.panel_rect()
	for i in _level.round.board().tube_count():
		assert_bool(panel.intersects(_level.board.tube_rect(i))).is_false()


func _win_tubes_gap(screen: Vector2, level_no: int) -> Array:
	UiTestFit.fit_root(_level, screen)
	_level.load_level(level_no)
	ScreenshotFixtures.apply_win(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Rect2 = _level.level_complete.panel_rect()
	var min_gap: float = INF
	for i in _level.round.board().tube_count():
		min_gap = minf(min_gap, panel.position.y - _level.board.tube_rect(i).end.y)
	return [min_gap, _level.board.tube_rect(0).size.x]


func test_win_tubes_pad_from_card_and_not_smaller() -> void:
	var pad: float = float(UiTokens.SCREEN_PAD)
	for screen: Vector2 in [Vector2(720, 1280), Vector2(720, 1560)]:
		var r8: Array = await _win_tubes_gap(screen, 8)
		assert_float(r8[0]).is_greater_equal(pad)
		assert_float(r8[1]).is_greater_equal(BASE_TUBE_W_LV8 - 0.01)
		var r56: Array = await _win_tubes_gap(screen, 56)
		assert_float(r56[0]).is_greater_equal(pad)
		assert_float(r56[1]).is_greater_equal(BASE_TUBE_W_LV56 - 0.01)


func test_win_dim_is_transparent_over_tubes() -> void:
	var dim: ColorRect = _level.level_complete.get_node("Dim")
	assert_float(dim.color.a).is_equal(0.0)
