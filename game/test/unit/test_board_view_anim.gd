extends GdUnitTestSuite
## Animacja przelewu BoardView (animate=true, realny czas tweenow).

const DURATION: float = 0.3

var _runner: GdUnitSceneRunner
var _level: Level
var _count: Array = []


func before_test() -> void:
	GameConfig.reset()
	GameConfig.apply_remote({"pour_anim_seconds": DURATION})
	_level = auto_free(load("res://src/levels/level.tscn").instantiate())
	_level.clock = TestClock.fixed()
	_runner = scene_runner_for(_level)
	_level.load_level(2)
	_level.board.animate = true
	_count = []
	_level.board.pour_finished.connect(func(_f: int, _t: int) -> void: _count.append(1))


func after_test() -> void:
	GameConfig.reset()


func scene_runner_for(node: Node) -> GdUnitSceneRunner:
	add_child(node)
	return scene_runner(node)


func _views_match_board() -> bool:
	var board: SortBoard = _level.round.board()
	for i: int in board.tube_count():
		if _level.board.view_layers(i) != board.tubes[i]:
			return false
	return true


func _start_pour() -> Vector2i:
	var m: Vector2i = _level.round.board().legal_moves()[0]
	_level.board.tap(m.x)
	_level.board.tap(m.y)
	return m


func test_pour_finished_once_after_duration() -> void:
	var t0: int = Time.get_ticks_msec()
	_start_pour()
	await await_millis(int(DURATION * 1000) + 300)
	assert_array(_count).has_size(1)
	assert_int(Time.get_ticks_msec() - t0).is_greater_equal(int(DURATION * 1000) - 20)
	assert_int(_level.board.selected_index()).is_equal(-1)
	assert_bool(_level.board.is_busy()).is_false()
	assert_bool(_views_match_board()).is_true()


func test_tap_during_pour_ignored() -> void:
	var m: Vector2i = _start_pour()
	var selected: Array = []
	_level.board.tube_selected.connect(func(i: int) -> void: selected.append(i))
	await await_millis(50)
	assert_bool(_level.board.is_busy()).is_true()
	_level.board.tap((m.x + 2) % _level.round.board().tube_count())
	assert_int(_level.board.selected_index()).is_equal(-1)
	assert_array(selected).is_empty()
	await await_millis(int(DURATION * 1000) + 300)
	assert_array(_count).has_size(1)


func test_resize_mid_pour_finalizes() -> void:
	var m: Vector2i = _start_pour()
	await await_millis(50)
	assert_array(_count).is_empty()
	_level.board.size = _level.board.size + Vector2(10, 0)
	assert_array(_count).has_size(1)
	assert_bool(_level.board.is_busy()).is_false()
	assert_bool(_views_match_board()).is_true()
	assert_float(_level.board.view_rotation(m.x)).is_equal_approx(0.0, 0.001)
	await await_millis(int(DURATION * 1000) + 300)
	assert_array(_count).has_size(1)


func test_phase_ratios_sum_to_one() -> void:
	var sum: float = (
		BoardView.POUR_LIFT_RATIO + BoardView.POUR_TRANSFER_RATIO + BoardView.POUR_RETURN_RATIO
	)
	assert_float(sum).is_equal_approx(1.0, 0.0001)


func test_setup_during_pour_cancels_without_signal() -> void:
	_start_pour()
	await await_millis(50)
	_level.board.setup(_level.round, "classic")
	assert_array(_count).is_empty()
	assert_bool(_level.board.is_busy()).is_false()
	assert_bool(_views_match_board()).is_true()
	await await_millis(int(DURATION * 1000) + 300)
	assert_array(_count).is_empty()


func test_restart_during_pulse_resets_scale() -> void:
	# undo() uses the same path (_after_action -> board.refresh), so restart covers both.
	GameConfig.apply_remote({"tube_full_pulse_seconds": 0.3})
	_level.board.pulse_tube(0)
	await await_millis(60)
	assert_vector(_level.board.view_scale(0)).is_not_equal(Vector2.ONE)
	_level.restart()
	assert_vector(_level.board.view_scale(0)).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))
	await await_millis(400)
	assert_vector(_level.board.view_scale(0)).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))
