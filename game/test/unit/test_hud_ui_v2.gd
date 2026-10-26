extends GdUnitTestSuite

const LEVEL_SCENE: PackedScene = preload("res://src/levels/level.tscn")
const SAVE_PATH: String = "user://test_hud_ui_v2.json"

var _level: Level
var _old_path: String
var _prev_locale: String


func before_test() -> void:
	GameConfig.reset()
	_prev_locale = TranslationServer.get_locale()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)
	_level = LEVEL_SCENE.instantiate()
	_level.state = GameState.new()
	_level.clock = TestClock.fixed()
	UiTestFit.fit_root(_level, Vector2(720, 1280))
	add_child(_level)


func after_test() -> void:
	TranslationServer.set_locale(_prev_locale)
	if is_instance_valid(_level):
		_level.free()
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _buttons() -> Array[Button]:
	var h: Hud = _level.hud
	return [h.pause_button, h.undo_button, h.restart_button, h.hint_button, h.extra_tube_button]


func test_buttons_meet_touch_min() -> void:
	await _frames()
	for b: Button in _buttons():
		assert_float(b.size.x).is_greater_equal(UiTokens.TOUCH_MIN)
		assert_float(b.size.y).is_greater_equal(UiTokens.TOUCH_MIN)
		assert_str(b.text).is_equal("")


func _board_fits(h: int) -> void:
	UiTestFit.fit_root(_level, Vector2(720, h))
	_level.load_level(60)
	await _frames()
	var area := Rect2(0, UiTokens.HUD_TOP_H, 720, h - UiTokens.HUD_TOP_H - UiTokens.HUD_BOTTOM_H)
	for i in _level.round.board().tube_count():
		var r: Rect2 = _level.board.tube_rect(i)
		assert_bool(area.encloses(r)).override_failure_message("tube %d %s" % [i, r]).is_true()


func test_board_fits_720x1280() -> void:
	await _board_fits(1280)


func test_board_fits_720x1560() -> void:
	await _board_fits(1560)


func test_extra_tube_ad_routes_signal() -> void:
	var hud: Hud = _level.hud
	hud.set_boosters_visible(true)
	var ad: Array[int] = [0]
	var coin: Array[int] = [0]
	hud.extra_tube_ad_pressed.connect(func() -> void: ad[0] += 1)
	hud.extra_tube_pressed.connect(func() -> void: coin[0] += 1)
	hud.set_ad_offers(true, false)
	assert_bool(hud.extra_tube_ad_button.visible).is_true()
	assert_bool(hud.extra_tube_cost_label.visible).is_false()
	hud.extra_tube_button.pressed.emit()
	assert_int(ad[0]).is_equal(1)
	assert_int(coin[0]).is_equal(0)
	hud.set_ad_offers(false, false)
	assert_bool(hud.extra_tube_cost_label.visible).is_true()
	hud.extra_tube_button.pressed.emit()
	assert_int(ad[0]).is_equal(1)
	assert_int(coin[0]).is_equal(1)


func test_undo_refill_ad() -> void:
	var hud: Hud = _level.hud
	hud.set_boosters_visible(true)
	var ad: Array[int] = [0]
	hud.undo_refill_ad_pressed.connect(func() -> void: ad[0] += 1)
	_level.round.counters.undo_charges = 0
	hud.set_ad_offers(false, true)
	hud.refresh()
	assert_bool(hud.undo_button.disabled).is_false()
	hud.undo_button.pressed.emit()
	assert_int(ad[0]).is_equal(1)
	_level.round.counters.undo_charges = 0
	hud.set_ad_offers(false, false)
	assert_bool(hud.undo_button.disabled).is_true()


func test_labels_show_goal_and_coins() -> void:
	_level.state.coins = 123
	_level.hud.refresh()
	assert_str(_level.hud.moves_label.text).contains(str(_level.round.min_moves()))
	assert_str(_level.hud.coins_label.text).is_equal("123")
	assert_str(_level.hud.undo_badge.text).is_equal(str(_level.round.counters.undo_charges))


func test_german_captions_fit_columns() -> void:
	TranslationServer.set_locale("de")
	var level: Level = auto_free(LEVEL_SCENE.instantiate())
	level.state = GameState.new()
	level.clock = TestClock.fixed()
	UiTestFit.fit_root(level, Vector2(720, 1280))
	add_child(level)
	await _frames()
	for b: Button in [level.hud.undo_button, level.hud.restart_button]:
		var col: Control = b.get_parent()
		for c in col.get_children():
			if c is Label:
				assert_float((c as Label).get_minimum_size().x).is_less_equal(col.size.x)


func test_backdrop_follows_board_theme() -> void:
	_level.load_level(1)
	var bg: ColorRect = _level.hud.top_bar.get_child(0)
	var classic := Color(BoardView.load_theme(_level.board.theme_id)["background"])
	assert_object(bg.color).is_equal(classic)
	_level.apply_theme("neon")
	var neon := Color(BoardView.load_theme("neon")["background"])
	assert_object(bg.color).is_equal(neon)
	assert_object(_level.hud.bottom_bar.get_child(0).color).is_equal(neon)


func test_hud_hidden_on_win_and_restored_on_restart() -> void:
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	var sol: Array = ContentGenerator.new().generate(seed_value, 1)["payload"]["solution"]
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)
	assert_bool(_level.hud.visible).is_false()
	_level.restart()
	assert_bool(_level.hud.visible).is_true()


func test_backdrop_covers_level_with_theme_color() -> void:
	_level.load_level(1)
	await _frames()
	var want := Color(BoardView.load_theme(_level.board.theme_id)["background"])
	assert_that(_level.backdrop.color).is_equal(want)
	(
		assert_bool(_level.backdrop.get_global_rect().encloses(Rect2(Vector2.ZERO, _level.size)))
		. is_true()
	)


func test_tool_buttons_use_round_hud_variant() -> void:
	await _frames()
	var h: Hud = _level.hud
	for b: Button in [h.undo_button, h.restart_button, h.hint_button, h.extra_tube_button]:
		assert_str(str(b.theme_type_variation)).is_equal("ButtonHud")
		var sb: StyleBoxFlat = ScreenHeader.UI_THEME.get_stylebox("normal", b.theme_type_variation)
		assert_float(float(sb.corner_radius_top_left)).is_greater_equal(b.size.x / 2.0 - 1.0)
