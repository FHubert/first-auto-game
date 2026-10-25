extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_ui_fx.json"

var _level: Level
var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.clock = TestClock.fixed()
	_level.effects_enabled = true
	add_child(_level)


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func test_pop_and_kill_all() -> void:
	var hud: Hud = _level.hud
	hud.effects_enabled = true
	hud.undo_badge.text = "99"
	hud.refresh()
	assert_int(UiFx.active_count(hud.undo_badge)).is_equal(1)
	UiFx.kill_all(hud.undo_badge)
	assert_int(UiFx.active_count(hud.undo_badge)).is_equal(0)


func test_pop_disabled() -> void:
	var hud: Hud = _level.hud
	UiFx.kill_all(hud.undo_badge)
	hud.effects_enabled = false
	hud.undo_badge.text = "99"
	hud.refresh()
	assert_int(UiFx.active_count(hud.undo_badge)).is_equal(0)


func test_count_up_ends_with_exact_amount() -> void:
	var label := Label.new()
	add_child(label)
	var tw: Tween = UiFx.count_up(label, 37, 0.1, "+%d", true, true)
	assert_object(tw).is_not_null()
	await tw.finished
	assert_str(label.text).is_equal("+37")
	label.free()


func test_count_up_disabled_sets_final() -> void:
	var label := Label.new()
	add_child(label)
	assert_object(UiFx.count_up(label, 15, 0.6, "+%d", false)).is_null()
	assert_str(label.text).is_equal("+15")
	label.free()


func test_press_disabled_returns_null() -> void:
	assert_object(UiFx.press(_level.hud.undo_button, false)).is_null()
	assert_object(UiFx.press(_level.hud.undo_button, true)).is_not_null()
	UiFx.kill_all(_level.hud.undo_button)
	assert_int(UiFx.active_count(_level.hud.undo_button)).is_equal(0)


func test_nudge_appears_after_delay_and_stops_on_action() -> void:
	_level.hud.set_boosters_visible(true)  # poziom 1 ma tutorial (ukryte boostery)
	var t: Array = [0.0]
	_level.nudge_clock = TestClock.ticking_float(t)
	_level._reset_nudge()
	await get_tree().process_frame
	assert_int(UiFx.active_count(_level.hud.hint_button)).is_equal(0)
	t[0] = float(GameConfig.get_value("hint_nudge_seconds"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(UiFx.active_count(_level.hud.hint_button)).is_greater_equal(1)
	_level._after_action()
	assert_int(UiFx.active_count(_level.hud.hint_button)).is_equal(0)
