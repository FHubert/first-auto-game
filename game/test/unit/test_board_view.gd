extends GdUnitTestSuite
## Testy BoardView/Level (headless, bez tweenow).

var _level: Level


func before_test() -> void:
	GameConfig.reset()
	_level = auto_free(load("res://src/levels/level.tscn").instantiate())
	_level.clock = TestClock.fixed()
	add_child(_level)
	_level.load_level(2)
	await get_tree().process_frame


func _board() -> BoardView:
	return _level.board


func test_load_theme() -> void:
	assert_int(BoardView.load_theme("classic")["liquids"].size()).is_equal(12)
	var fallback: Dictionary = BoardView.load_theme("nie_ma")
	assert_str(fallback["id"]).is_equal("classic")


func test_tube_views_match_board() -> void:
	var views: int = (
		_board().get_children().filter(func(n: Node) -> bool: return n is TubeView).size()
	)
	assert_int(views).is_equal(_level.round.board().tube_count())
	assert_bool(_board().animate).is_false()


func test_legal_tap_pours() -> void:
	var move: Vector2i = _level.round.board().legal_moves()[0]
	var got: Array = []
	_board().pour_finished.connect(func(f: int, t: int) -> void: got.append(Vector2i(f, t)))
	_board().tap(move.x)
	assert_int(_board().selected_index()).is_equal(move.x)
	_board().tap(move.y)
	assert_int(_level.round.moves()).is_equal(1)
	assert_array(got).is_equal([move])
	assert_int(_board().selected_index()).is_equal(-1)


func test_illegal_tap_emits() -> void:
	var board: SortBoard = _level.round.board()
	var pair := Vector2i(-1, -1)
	for a: int in board.tube_count():
		for b: int in board.tube_count():
			if a != b and not board.can_pour(a, b):
				pair = Vector2i(a, b)
	assert_int(pair.x).is_greater_equal(0)
	var got: Array = []
	_board().illegal_move.connect(func(f: int, t: int) -> void: got.append(Vector2i(f, t)))
	_board().tap(pair.x)
	_board().tap(pair.y)
	assert_int(_level.round.moves()).is_equal(0)
	assert_array(got).is_equal([pair])
	assert_int(_board().selected_index()).is_equal(-1)


func test_same_tube_deselects() -> void:
	_board().tap(0)
	_board().tap(0)
	assert_int(_board().selected_index()).is_equal(-1)
	assert_int(_level.round.moves()).is_equal(0)


func test_pour_duration_from_config() -> void:
	GameConfig.apply_remote({"pour_anim_seconds": 0.123})
	assert_float(_board().pour_duration()).is_equal(0.123)


func _count_deselects() -> Array:
	var got: Array = []
	_board().tube_deselected.connect(func(i: int) -> void: got.append(i))
	return got


func test_select_then_deselect_emits_once() -> void:
	var got: Array = _count_deselects()
	monitor_signals(_board())
	_board().tap(1)
	_board().tap(1)
	await assert_signal(_board()).is_emitted("tube_deselected", [1])
	assert_array(got).is_equal([1])


func test_illegal_tap_deselects_once() -> void:
	var board: SortBoard = _level.round.board()
	var pair := Vector2i(-1, -1)
	for a: int in board.tube_count():
		for b: int in board.tube_count():
			if a != b and not board.can_pour(a, b):
				pair = Vector2i(a, b)
	(
		assert_bool(pair.x >= 0)
		. override_failure_message("brak nielegalnej pary na poziomie 2")
		. is_true()
	)
	var got: Array = _count_deselects()
	var illegal: Array = []
	_board().illegal_move.connect(func(_f: int, _t: int) -> void: illegal.append(1))
	_board().tap(pair.x)
	_board().tap(pair.y)
	assert_array(got).is_equal([pair.x])
	assert_array(illegal).has_size(1)


func test_legal_pour_does_not_deselect() -> void:
	var move: Vector2i = _level.round.board().legal_moves()[0]
	var got: Array = _count_deselects()
	_board().tap(move.x)
	_board().tap(move.y)
	assert_array(got).is_empty()


func test_rebuild_while_selected_emits_deselect() -> void:
	var got: Array = _count_deselects()
	_board().tap(1)
	assert_bool(_level.round.add_extra_tube()).is_true()
	_board().refresh()
	assert_array(got).is_equal([1])
	assert_int(_board().selected_index()).is_equal(-1)


func test_single_row_columns_and_scale() -> void:
	assert_int(BoardView.columns_for(8, true)).is_equal(8)
	assert_int(BoardView.columns_for(8)).is_equal(4)
	assert_float(BoardView.scale_for(8, Vector2(646, 600), true)).is_less(1.0)
