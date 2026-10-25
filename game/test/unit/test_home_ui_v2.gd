extends GdUnitTestSuite

const W: int = 720


func _home(h: int = 1280) -> Home:
	var home: Home = auto_free(load("res://src/ui/home.tscn").instantiate())
	home.clock = TestClock.fixed()
	home.state = GameState.new()
	var host: Control = auto_free(Control.new())
	host.size = Vector2(W, h)
	add_child(host)
	host.add_child(home)
	return home


func _buttons(home: Home) -> Array[Button]:
	return [
		home.play_button,
		home.daily_button,
		home.themes_button,
		home.shop_button,
		home.settings_button,
	]


func test_variations_and_icons() -> void:
	var home := _home()
	assert_str(str(home.play_button.theme_type_variation)).is_equal("ButtonPrimary")
	assert_str(str(home.daily_button.theme_type_variation)).is_equal("ButtonAccent")
	for b: Button in [home.themes_button, home.shop_button, home.settings_button]:
		assert_str(str(b.theme_type_variation)).is_equal("ButtonNav")
		assert_object(b.icon).is_not_null()


func test_button_sizes() -> void:
	var home := _home()
	assert_int(int(home.play_button.get_combined_minimum_size().y)).is_greater_equal(
		UiTokens.PLAY_BTN
	)
	for b: Button in _buttons(home):
		var m: Vector2 = b.get_combined_minimum_size()
		assert_int(int(m.y)).is_greater_equal(UiTokens.TOUCH_MIN)
		assert_int(int(m.x)).is_greater_equal(UiTokens.TOUCH_MIN)


func _fits(h: int) -> void:
	var home := _home(h)
	await get_tree().process_frame
	await get_tree().process_frame
	var r: Rect2 = home.root_margin.get_rect()
	assert_bool(Rect2(0, 0, W, h).encloses(r)).is_true()
	assert_int(int(home.root_margin.get_combined_minimum_size().y)).is_less_equal(h)
	for b: Button in _buttons(home):
		var g: Rect2 = b.get_global_rect()
		assert_bool(Rect2(0, 0, W, h).encloses(g)).is_true()


func test_layout_fits_720x1280() -> void:
	await _fits(1280)


func test_layout_fits_720x1560() -> void:
	await _fits(1560)


func test_german_texts_not_clipped() -> void:
	var prev: String = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var home := _home()
	assert_int(int(home.play_button.get_combined_minimum_size().x)).is_less_equal(
		W - 2 * UiTokens.SCREEN_PAD
	)
	TranslationServer.set_locale(prev)


func test_home_has_fullscreen_backdrop() -> void:
	var home: Home = _home(1920)
	home.size = Vector2(1080, 1920)
	await get_tree().process_frame
	await get_tree().process_frame
	var bg: ColorRect = home.get_child(0) as ColorRect
	assert_object(bg).is_not_null()
	assert_that(bg.color).is_equal(UiTokens.BG)
	assert_bool(bg.get_global_rect().encloses(Rect2(Vector2.ZERO, home.size))).is_true()
