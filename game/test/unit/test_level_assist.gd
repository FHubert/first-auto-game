extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_level_assist.json"

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
	TestSaveCleanup.remove(SAVE_PATH)
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.state.coins = 500
	_level.state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	_level.clock = TestClock.fixed()
	_level.autoload_level = false
	add_child(_level)
	_level.size = Vector2(720, 1280)


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	Ads.interstitials_shown = _prev_shown
	Ads.reset_break()
	GameConfig.reset()


func _start_hard(level_no: int = 56) -> void:
	_level.load_level(level_no)
	_level.restart()
	_level.restart()


func _first_legal_move() -> Vector2i:
	var b: SortBoard = _level.round.board()
	for i in b.tube_count():
		for j in b.tube_count():
			if i != j and b.can_pour(i, j):
				return Vector2i(i, j)
	return Vector2i(-1, -1)


func test_bar_visible_on_third_attempt() -> void:
	_level.load_level(56)
	assert_bool(_level.assist_bar.visible).is_false()
	_level.restart()
	assert_bool(_level.assist_bar.visible).is_false()
	_level.restart()
	assert_bool(_level.assist_bar.visible).is_true()
	assert_bool(_level.assist_bar.coins_button.visible).is_true()


func test_first_move_hides_bar() -> void:
	_start_hard()
	var m: Vector2i = _first_legal_move()
	assert_bool(_level.round.try_move(m.x, m.y)).is_true()
	_level.board.refresh()
	_level.hud.refresh()
	_level._refresh_offers()
	assert_bool(_level.assist_bar.visible).is_false()


func test_coins_click_adds_tube_and_hides_bar() -> void:
	_start_hard()
	var before: int = _level.state.coins
	var cost: int = Economy.extra_tube_cost()
	_level.assist_bar.coins_button.pressed.emit()
	assert_int(int(_level.round.to_dict()["extra_tubes_added"])).is_equal(1)
	assert_int(_level.state.coins).is_equal(before - cost)
	assert_bool(_level.assist_bar.visible).is_false()


func test_daily_has_no_bar() -> void:
	_level.start_daily(20750)
	_level.restart()
	_level.restart()
	assert_bool(_level.assist_bar.visible).is_false()


func test_resumed_round_with_moves_has_no_bar() -> void:
	_start_hard()
	var m: Vector2i = _first_legal_move()
	_level.round.try_move(m.x, m.y)
	var snap: Dictionary = _level.snapshot()
	_level.state.level = 56
	assert_bool(_level.resume(snap, 0)).is_true()
	assert_bool(_level.assist_bar.visible).is_false()


func test_bar_does_not_overlap_tubes_on_level_56_with_extra_tube() -> void:
	_start_hard()
	assert_bool(_level.round.can_add_extra_tube()).is_true()
	_level.round.add_extra_tube()
	_level.board.setup(_level.round, "classic")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_level.assist_bar.visible).is_true()
	var bar := Rect2(_level.assist_bar.global_position, _level.assist_bar.size)
	for i in _level.round.board().tube_count():
		assert_bool(bar.intersects(_level.board.tube_rect(i))).is_false()
