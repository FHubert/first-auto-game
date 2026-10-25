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


func _labels(n: Node, out: Array[Label]) -> void:
	for c: Node in n.get_children():
		if c is Label and (c as Label).is_visible_in_tree():
			out.append(c as Label)
		_labels(c, out)


func _daily_no_overlap(locale: String) -> void:
	var prev: String = TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	var home := _home()
	home.state.daily_completed_total = 23
	home.state.streak_days = 5
	home.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var labels: Array[Label] = []
	_labels(home.daily_card, labels)
	assert_int(labels.size()).is_greater_equal(5)
	for i: int in labels.size():
		for j: int in range(i + 1, labels.size()):
			var a: Rect2 = labels[i].get_global_rect()
			var b: Rect2 = labels[j].get_global_rect()
			assert_bool(a.intersects(b)).is_false()
	TranslationServer.set_locale(prev)


func test_daily_labels_do_not_overlap_pl() -> void:
	await _daily_no_overlap("pl")


func test_daily_labels_do_not_overlap_de() -> void:
	await _daily_no_overlap("de")


func test_play_button_two_lines() -> void:
	var home := _home()
	assert_str(home.play_button.text).is_empty()
	assert_str(home.play_title_label.text).is_equal(tr("home_play_title"))
	assert_str(home.play_level_label.text).is_equal(tr("home_play_level") % home.state.level)


func test_tubes_mini_is_tall() -> void:
	var mini := Home.TubesMini.new([] as Array[Color])
	assert_int(int(mini.custom_minimum_size.y)).is_greater_equal(2 * 84)
	mini.free()


func test_streak_text_plural_forms() -> void:
	var prev: String = TranslationServer.get_locale()
	var one: Dictionary = {"en": "day", "pl": "dzień", "de": "Tag"}
	var many: Dictionary = {"en": "days", "pl": "dni", "de": "Tage"}
	for loc: String in ["en", "pl", "de"]:
		TranslationServer.set_locale(loc)
		var t1: String = Home.streak_text(1)
		var t5: String = Home.streak_text(5)
		assert_str(t1).is_equal("1 " + str(one[loc]))
		assert_str(t5).is_equal("5 " + str(many[loc]))
		assert_str(t1).is_not_equal("home_streak_one")
	TranslationServer.set_locale(prev)


func test_theme_bar_label_and_amount() -> void:
	var home := _home()
	var cost: int = ThemeCatalog.cost("pastel")
	home.state.coins = 350
	home.refresh()
	assert_str(ThemeCatalog.next_theme_id(home.state)).is_equal("pastel")
	assert_str(home.theme_label.text).is_equal(tr("home_theme_to") % tr("theme_name_pastel"))
	assert_str(home.theme_amount.text).is_equal("350 / %d" % cost)
	assert_that(home.theme_amount.get_theme_color("font_color")).is_equal(UiTokens.ACCENT)
	home.state.themes_owned = Array(ThemeCatalog.ids())
	home.refresh()
	assert_str(home.theme_label.text).is_equal(tr("home_all_themes"))
	assert_bool(home.theme_amount.visible).is_false()


func _de_geometry(h: int) -> void:
	var prev: String = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var home := _home(h)
	home.state.streak_days = 5
	home.state.streak_best = 12
	home.state.coins = 350
	home.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := Rect2(0, 0, W, h)
	var pill: Rect2 = home.streak_label.get_parent().get_parent().get_global_rect()
	var a: Rect2 = home.streak_label.get_global_rect()
	var b: Rect2 = home.streak_best_label.get_global_rect()
	assert_bool(pill.encloses(a)).is_true()
	assert_bool(pill.encloses(b)).is_true()
	assert_bool(a.intersects(b)).is_false()
	var t: Rect2 = home.theme_label.get_global_rect()
	var m: Rect2 = home.theme_amount.get_global_rect()
	assert_bool(t.intersects(m)).is_false()
	assert_bool(screen.encloses(t)).is_true()
	assert_bool(screen.encloses(m)).is_true()
	TranslationServer.set_locale(prev)


func test_de_streak_and_theme_geometry_1280() -> void:
	await _de_geometry(1280)


func test_de_streak_and_theme_geometry_1560() -> void:
	await _de_geometry(1560)
