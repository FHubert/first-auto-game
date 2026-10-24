extends GdUnitTestSuite
## Testy geometrii warstw plynu w TubeView (czyste funkcje, bez sceny).

const VIEW := Vector2(BoardView.TUBE_WIDTH, BoardView.TUBE_HEIGHT)


func test_inner_rect() -> void:
	assert_that(TubeView.inner_rect(Vector2(90, 300))).is_equal(Rect2(12, 40, 65, 247))


func test_bottom_layer_inside_inner_rect() -> void:
	for shape: String in ["tube", "flask"]:
		var inner: Rect2 = TubeView.inner_rect(VIEW).grow(1.0)
		var poly: PackedVector2Array = TubeView.layer_polygon(
			TubeView.layer_rect(VIEW, 4, 0), true, TubeView.BOTTOM_RADIUS
		)
		for p: Vector2 in poly:
			assert_bool(inner.has_point(p)).override_failure_message(shape + str(p)).is_true()


func test_bottom_corners_are_cut() -> void:
	for shape: String in ["tube", "flask"]:
		var rect: Rect2 = TubeView.layer_rect(VIEW, 4, 0)
		# Luk kola mija naroze o ok. 0.4*r (r ogr. do pol szer.: 32.5), prog 0.35.
		var min_d: float = TubeView.BOTTOM_RADIUS * 0.35
		var poly: PackedVector2Array = TubeView.layer_polygon(rect, true, TubeView.BOTTOM_RADIUS)
		for p: Vector2 in poly:
			(
				assert_bool(p.distance_to(Vector2(rect.position.x, rect.end.y)) >= min_d)
				. override_failure_message(shape)
				. is_true()
			)
			assert_bool(p.distance_to(rect.end) >= min_d).override_failure_message(shape).is_true()


func test_upper_layers_are_rects_and_sum_to_inner() -> void:
	var inner: Rect2 = TubeView.inner_rect(VIEW)
	var total: float = 0.0
	for i: int in 4:
		var rect: Rect2 = TubeView.layer_rect(VIEW, 4, i)
		total += rect.size.y
		if i > 0:
			assert_int(TubeView.layer_polygon(rect, false, TubeView.BOTTOM_RADIUS).size()).is_equal(
				4
			)
		assert_bool(inner.grow(0.01).encloses(rect)).is_true()
	assert_float(total).is_equal_approx(inner.size.y, 0.01)
