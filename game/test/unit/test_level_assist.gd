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


func test_bar_visible_on_second_attempt() -> void:
	_level.load_level(56)
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


func _attempt_from() -> int:
	return int(GameConfig.get_value("plateau_assist_from_attempt"))


func _rows() -> int:
	return ceili(float(_level.round.board().tube_count()) / float(BoardView.COLUMNS_PER_ROW))


func _assert_bar_clear(info: String) -> void:
	var bar: Rect2 = _level.assist_bar.get_global_rect()
	var view := Rect2(Vector2.ZERO, _level.size)
	(
		assert_bool(view.encloses(bar))
		. override_failure_message("bar poza viewportem " + info)
		. is_true()
	)
	(
		assert_bool(bar.intersects(_level.hud.get_global_rect()))
		. override_failure_message("bar na HUD " + info)
		. is_false()
	)
	for i in _level.round.board().tube_count():
		(
			assert_bool(bar.intersects(_level.board.tube_rect(i)))
			. override_failure_message("bar na probowce %d %s" % [i, info])
			. is_false()
		)


func test_bar_geometry_per_level_and_viewport(
	level_no: int,
	rows_expected: int,
	view_size: Vector2,
	test_parameters := [
		[26, 2, Vector2(1080, 1920)],
		[26, 2, Vector2(1080, 2400)],
		[38, 3, Vector2(1080, 1920)],
		[55, 3, Vector2(1080, 1920)],
		[55, 3, Vector2(1080, 2400)],
	]
) -> void:
	assert_that(test_parameters).is_not_null()
	_level.size = view_size
	_level.load_level(level_no)
	for _i in _attempt_from() - 1:
		_level.restart()
	await get_tree().process_frame
	await get_tree().process_frame
	var info := "poziom %d rzedy %d viewport %s" % [level_no, _rows(), view_size]
	assert_int(_rows()).override_failure_message(info).is_equal(rows_expected)
	assert_bool(_level.assist_bar.visible).override_failure_message(info).is_true()
	_assert_bar_clear(info)
	_level.round.add_extra_tube()
	_level.board.setup(_level.round, "classic")
	await get_tree().process_frame
	_assert_bar_clear(info + " po dodaniu")


func _rewarded_events() -> int:
	var n: int = 0
	for e: Dictionary in (Analytics.provider as FakeAnalyticsProvider).events:
		if str(e.get("event_id", "")) == "level:assist:rewarded":
			n += 1
	return n


func _ad_click(granted: bool) -> void:
	var fake := FakeAdProvider.new()
	fake.reward_on_show = granted
	Ads.provider = fake
	var prev: AnalyticsProvider = Analytics.provider
	Analytics.provider = FakeAnalyticsProvider.new()
	_start_hard()
	var tubes: int = _level.round.board().tube_count()
	_level.assist_bar.ad_button.pressed.emit()
	var added: int = _level.round.board().tube_count() - tubes
	assert_int(added).is_equal(1 if granted else 0)
	assert_bool(_level.assist_bar.visible).is_equal(not granted)
	assert_int(_rewarded_events()).is_equal(1 if granted else 0)
	Analytics.provider = prev


func test_ad_click_granted_hides_bar_and_adds_tube() -> void:
	_ad_click(true)


func test_ad_click_not_granted_keeps_bar() -> void:
	_ad_click(false)


func test_stuck_panel_and_pause_hide_bar() -> void:
	_start_hard()
	assert_bool(_level.assist_bar.visible).is_true()
	_level.stuck_panel.show_for(_level.round)
	_level._check_stuck()
	_level.pause()
	assert_bool(_level.assist_bar.visible).is_false()
