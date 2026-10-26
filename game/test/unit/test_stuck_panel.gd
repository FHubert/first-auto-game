extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_stuck_panel.json"
const DEADLOCK: Dictionary = {
	"payload": {"tubes": [[0, 1, 0, 1], [1, 0, 1, 0]], "capacity": 4, "colors": 2, "min_moves": 1}
}

var _level: Level
var _old_path: String
var _shop_reasons: Array[String] = []


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()
	_shop_reasons.clear()
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.clock = TestClock.fixed()
	_level.state = GameState.new()
	add_child(_level)
	_level.shop_requested.connect(func(r: String) -> void: _shop_reasons.append(r))


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	_cleanup()
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _views() -> int:
	var n: int = 0
	for c in _level.board.get_children():
		if c is TubeView and not c.is_queued_for_deletion():
			n += 1
	return n


func test_panel_shows_on_deadlock() -> void:
	assert_bool(_level.stuck_panel.visible).is_false()
	_level.start_round(DEADLOCK)
	_level._check_stuck()
	assert_bool(_level.stuck_panel.visible).is_true()
	assert_str(_level.stuck_panel.distance_label.text).is_not_empty()


func test_buy_extra_tube_resolves_deadlock() -> void:
	_level.state.coins = 100
	_level.start_round(DEADLOCK)
	_level._check_stuck()
	assert_bool(_level.offers.buy_extra_tube()).is_true()
	assert_int(_level.state.coins).is_equal(100 - Economy.extra_tube_cost())
	assert_int(_level.round.board().tube_count()).is_equal(3)
	assert_int(_views()).is_equal(3)
	assert_bool(_level.stuck_panel.visible).is_false()


func test_no_coins_requests_shop() -> void:
	_level.state.coins = 0
	_level.start_round(DEADLOCK)
	assert_bool(_level.offers.buy_extra_tube()).is_false()
	assert_array(_shop_reasons).contains_exactly(["extra_tube"])
	assert_int(_level.state.coins).is_equal(0)
	assert_int(_level.round.board().tube_count()).is_equal(2)


func test_skip_unlocks_after_restarts_and_advances() -> void:
	_level.stuck_panel.show_for(_level.round, true, _level.offers.ad_offers())
	assert_bool(_level.stuck_panel.skip_button.visible).is_false()
	var lvl: int = _level.state.level
	_level.offers.skip_level()
	assert_int(_level.state.level).is_equal(lvl)
	for i in int(GameConfig.get_value("skip_unlock_restarts")):
		_level.restart()
	_level.stuck_panel.show_for(_level.round, true, _level.offers.ad_offers())
	assert_bool(_level.stuck_panel.skip_button.visible).is_true()
	_level.offers.skip_level()
	assert_int(_level.state.level).is_equal(lvl + 1)
	assert_int(SaveSystem.load().level).is_equal(lvl + 1)


func test_show_for_respects_offers() -> void:
	var panel: StuckPanel = _level.stuck_panel
	panel.show_for(_level.round, true, {"extra_tube": true, "undo_refill": false, "skip": false})
	assert_bool(panel.extra_tube_ad_button.visible).is_true()
	assert_bool(panel.undo_refill_ad_button.visible).is_false()
	assert_bool(panel.skip_button.visible).is_false()
	panel.show_for(_level.round)
	assert_bool(panel.extra_tube_ad_button.visible).is_false()


func _assert_tubes_clear_of_panel() -> void:
	var panel: Rect2 = _level.stuck_panel.panel_rect()
	for i in _level.round.board().tube_count():
		assert_bool(panel.intersects(_level.board.tube_rect(i))).is_false()


func test_board_fits_above_panel_on_every_stuck() -> void:
	UiTestFit.fit_root(_level, Vector2(720, 1280))
	_level.start_round(DEADLOCK)
	_level._check_stuck()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_level.stuck_panel.visible).is_true()
	_assert_tubes_clear_of_panel()
	_level.stuck_panel.close_button.pressed.emit()
	assert_float(_level.board.offset_bottom).is_equal(float(-UiTokens.HUD_BOTTOM_H))
	_level._check_stuck()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_tubes_clear_of_panel()


func test_hint_row_closes_panel_and_resets_board() -> void:
	_level.state.coins = 500
	UiTestFit.fit_root(_level, Vector2(720, 1280))
	_level.start_round(DEADLOCK)
	_level._check_stuck()
	_level.stuck_panel.hint_button.visible = true
	_level.stuck_panel.hint_button.pressed.emit()
	assert_bool(_level.stuck_panel.visible).is_false()
	assert_float(_level.board.offset_bottom).is_equal(float(-UiTokens.HUD_BOTTOM_H))
