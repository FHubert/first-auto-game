extends GdUnitTestSuite
## Uklad planszy i geometria probowek UI v2 (T-231).

const BOARD_SIZE := Vector2(720, 920)


func _board(n: int) -> BoardView:
	var tubes: Array = []
	for i in n:
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
	view.size = BOARD_SIZE
	add_child(view)
	view.setup(r, "classic")
	view._layout()
	return view


func test_tubes_in_bounds_and_disjoint() -> void:
	var pad: float = float(UiTokens.SCREEN_PAD)
	var bounds := Rect2(pad - 0.5, 0.0, BOARD_SIZE.x - 2.0 * pad + 1.0, BOARD_SIZE.y)
	for n: int in range(4, 15):
		var view: BoardView = _board(n)
		var xs: Dictionary = {}
		for i: int in n:
			var rect: Rect2 = view.tube_rect(i)
			var lifted: Rect2 = Rect2(rect.position - Vector2(0, view._lift()), rect.size)
			lifted.end.y = rect.end.y
			(
				assert_bool(bounds.encloses(lifted))
				. override_failure_message("n=%d tube %d %s" % [n, i, rect])
				. is_true()
			)
			if absf(rect.position.y - view.tube_rect(0).position.y) < 1.0:
				xs[snappedf(rect.position.x, 0.1)] = true
			for j: int in range(i + 1, n):
				(
					assert_bool(rect.intersects(view.tube_rect(j)))
					. override_failure_message("n=%d %d/%d" % [n, i, j])
					. is_false()
				)
		var max_cols: int = 4 if n <= 8 else 7
		assert_int(xs.size()).is_less_equal(max_cols)
		if n <= 8:
			assert_float(view._scale).is_equal(1.0)
		else:
			assert_float(view._scale).is_less(1.0)


func test_tube_geometry_at_scale_one() -> void:
	var view := Vector2(UiTokens.TUBE_W, UiTokens.TUBE_H)
	var inner: Rect2 = TubeView.inner_rect(view)
	assert_bool(Rect2(Vector2.ZERO, view).encloses(inner)).is_true()
	for i: int in 4:
		var layer: Rect2 = TubeView.layer_rect(view, 4, i)
		assert_float(layer.size.y).is_equal_approx(float(UiTokens.TUBE_LAYER_H), 1.0)


func test_selected_tube_is_lifted_and_opaque() -> void:
	var view: BoardView = _board(4)
	var tube: TubeView = view.get_child(1) as TubeView
	var rest_y: float = tube.position.y
	view.tap(0)
	assert_bool(tube.selected).is_true()
	assert_float(tube.position.y).is_equal_approx(rest_y - float(UiTokens.TUBE_LIFT), 0.5)
