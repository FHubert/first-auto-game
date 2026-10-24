extends GdUnitTestSuite
## Symbole kolorow (T-115): ksztalty, flaga w TubeView, helper ustawien, przelacznik.

const SAVE_PATH: String = "user://test_color_symbols.json"
const RECT := Rect2(10, 20, 65, 60)

var _old_path: String


func before_test() -> void:
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH


func after_test() -> void:
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path


func _key(poly: PackedVector2Array) -> String:
	var parts: PackedStringArray = []
	for p: Vector2 in poly:
		parts.append("%.1f,%.1f" % [p.x, p.y])
	return ";".join(parts)


func test_twelve_distinct_deterministic_shapes() -> void:
	var seen: Dictionary = {}
	for i: int in ColorSymbols.SHAPES:
		var poly: PackedVector2Array = ColorSymbols.polygon(i, RECT)
		assert_int(poly.size()).is_greater_equal(3)
		assert_str(_key(poly)).is_equal(_key(ColorSymbols.polygon(i, RECT)))
		seen[_key(poly)] = true
	assert_int(seen.size()).is_equal(ColorSymbols.SHAPES)


func test_index_wraps_and_fits_rect() -> void:
	assert_str(_key(ColorSymbols.polygon(12, RECT))).is_equal(_key(ColorSymbols.polygon(0, RECT)))
	var limit: Rect2 = Rect2(RECT.get_center(), Vector2.ZERO).grow(
		minf(RECT.size.x, RECT.size.y) * ColorSymbols.SYMBOL_SCALE * 0.5 + 0.01
	)
	for i: int in ColorSymbols.SHAPES:
		for p: Vector2 in ColorSymbols.polygon(i, RECT):
			assert_bool(limit.has_point(p)).is_true()


func _tube(flag: bool) -> TubeView:
	var v: TubeView = auto_free(TubeView.new())
	v.size = Vector2(BoardView.TUBE_WIDTH, BoardView.TUBE_HEIGHT)
	v.liquids = [Color("#FF0000"), Color("#FFFF00"), Color("#0000FF")]
	v.layers = [0, 1, 2]
	v.show_symbols = flag
	add_child(v)
	return v


func test_tube_view_draws_symbol_per_layer() -> void:
	var v := _tube(true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(v.symbols_drawn).is_equal(3)
	v.set_symbols(false)
	await get_tree().process_frame
	assert_int(v.symbols_drawn).is_equal(0)


func test_tube_view_without_flag_draws_none() -> void:
	var v := _tube(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(v.symbols_drawn).is_equal(0)


func test_enabled_helper() -> void:
	assert_bool(ColorSymbols.enabled({})).is_false()
	assert_bool(ColorSymbols.enabled({"colorblind_symbols": "yes"})).is_false()
	assert_bool(ColorSymbols.enabled({"colorblind_symbols": 1})).is_false()
	assert_bool(ColorSymbols.enabled({"colorblind_symbols": false})).is_false()
	assert_bool(ColorSymbols.enabled({"colorblind_symbols": true})).is_true()


func test_settings_toggle_persists() -> void:
	var s: SettingsScreen = auto_free(load("res://src/ui/settings_screen.tscn").instantiate())
	s.state = GameState.new()
	add_child(s)
	assert_bool(s.symbols_toggle.button_pressed).is_false()
	s.symbols_toggle.button_pressed = true
	assert_bool(s.state.settings["colorblind_symbols"]).is_true()
	assert_bool(SaveSystem.load().settings["colorblind_symbols"]).is_true()
	s.state.settings["colorblind_symbols"] = false
	s.apply_from_state()
	assert_bool(s.symbols_toggle.button_pressed).is_false()


func test_symbol_contrast_at_least_3_to_1_for_all_theme_liquids() -> void:
	var worst: float = 99.0
	var best: float = 0.0
	for t: Variant in ThemeCatalog.all():
		var liquids: Array = (t as Dictionary)["liquids"]
		for i: int in liquids.size():
			var liquid := Color(str(liquids[i]))
			var sym: Color = ColorSymbols.symbol_color(liquid)
			var mixed: Color = liquid.lerp(sym, ColorSymbols.SYMBOL_ALPHA)
			var ratio: float = ColorSymbols.contrast_ratio(mixed, liquid)
			print("symbol_contrast %s/%d %.2f" % [(t as Dictionary)["id"], i, ratio])
			worst = minf(worst, ratio)
			best = maxf(best, ratio)
			assert_float(ratio).is_greater_equal(3.0)
	print("symbol_contrast min=%.2f max=%.2f" % [worst, best])


func test_symbol_color_deterministic_and_extremes() -> void:
	var c := Color("#ADB5BD")
	assert_that(ColorSymbols.symbol_color(c)).is_equal(ColorSymbols.symbol_color(c))
	assert_that(ColorSymbols.symbol_color(Color.WHITE)).is_equal(ColorSymbols.SYMBOL_DARK)
	assert_that(ColorSymbols.symbol_color(Color.BLACK)).is_equal(ColorSymbols.SYMBOL_LIGHT)
