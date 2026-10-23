extends GdUnitTestSuite
## Testy BoardView/Level (headless, bez tweenow).

var _level: Level


func before_test() -> void:
	GameConfig.reset()
	_level = auto_free(load("res://src/levels/level.tscn").instantiate())
	_level.level = 2
	add_child(_level)


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
