extends GdUnitTestSuite
## UI v2 (T-234): Themes / Shop / Settings wg makiet 06-08.

const SIZES: Array[Vector2] = [Vector2(720, 1280), Vector2(720, 1560)]


func _make(kind: String, size: Vector2) -> Control:
	var s: Control
	match kind:
		"themes":
			s = ThemesScreen.new()
			(s as ThemesScreen).state = _state()
		"shop":
			s = load("res://src/ui/shop_screen.tscn").instantiate()
			(s as ShopScreen).state = _state()
		_:
			s = load("res://src/ui/settings_screen.tscn").instantiate()
			(s as SettingsScreen).state = _state()
	auto_free(s)
	UiTestFit.fit_root(s, size)
	add_child(s)
	return s


func _state() -> GameState:
	var st := GameState.new()
	st.level = 12
	st.coins = 350
	return st


func _back(s: Control) -> Button:
	return s.back_button


func test_back_button_is_icon_variation() -> void:
	for kind: String in ["themes", "shop", "settings"]:
		var b := _back(_make(kind, SIZES[0]))
		assert_str(str(b.theme_type_variation)).is_equal("ButtonIcon")
		assert_object(b.icon).is_not_null()


func test_all_buttons_touch_min() -> void:
	for kind: String in ["themes", "shop", "settings"]:
		var s := _make(kind, SIZES[0])
		await get_tree().process_frame
		for b: Node in s.find_children("*", "Button", true, false):
			var h: float = (b as Button).get_combined_minimum_size().y
			(
				assert_bool(h >= UiTokens.TOUCH_MIN)
				. override_failure_message("%s: %s h=%s" % [kind, b.name, h])
				. is_true()
			)


func test_container_fits_screen() -> void:
	for kind: String in ["themes", "shop", "settings"]:
		for size: Vector2 in SIZES:
			var s := _make(kind, size)
			await get_tree().process_frame
			var m: Control = s.find_children("*", "MarginContainer", false, false)[0]
			(
				assert_bool(m.get_combined_minimum_size().y <= size.y)
				. override_failure_message(
					"%s %s min=%s" % [kind, size, m.get_combined_minimum_size()]
				)
				. is_true()
			)
			assert_bool(m.get_combined_minimum_size().x <= size.x).is_true()


func test_themes_active_card_has_accent_border() -> void:
	var s := _make("themes", SIZES[0]) as ThemesScreen
	var panel: Control = s.cards[s.state.theme_active]["panel"]
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(sb).is_not_null()
	assert_that(sb.border_color).is_equal(UiTokens.ACCENT)
	for id: String in s.cards:
		if id != s.state.theme_active:
			var other := (
				(s.cards[id]["panel"] as Control).get_theme_stylebox("panel") as StyleBoxFlat
			)
			assert_that(other.border_color).is_not_equal(UiTokens.ACCENT)
	assert_int(s.cards.size()).is_equal(4)


func test_shop_price_buttons_accent() -> void:
	var s := _make("shop", SIZES[0]) as ShopScreen
	for sku: String in ["remove_ads", "coins_small", "coins_large"]:
		assert_str(str(s.card_button(sku).theme_type_variation)).is_equal("ButtonAccent")
	assert_str(str(s.card_button("starter_pack").theme_type_variation)).is_equal("ButtonPrimary")


func test_settings_toggles_in_card_rows() -> void:
	var s := _make("settings", SIZES[0])
	var toggles: Array[Node] = s.find_children("*", "CheckButton", true, false)
	assert_int(toggles.size()).is_greater_equal(1)
	for t: Node in toggles:
		var p: Node = t.get_parent()
		while p != null and not (p is PanelContainer and p.theme_type_variation == &"CardRow"):
			p = p.get_parent()
		assert_object(p).is_not_null()


func _row_buttons(s: Control) -> Array[Button]:
	var out: Array[Button] = []
	for n: Node in s.find_children("*", "Button", true, false):
		var b := n as Button
		if b != s.back_button and b.visible and b.get_child_count() > 0:
			out.append(b)
	return out


func test_settings_rows_tiles_switches_separators() -> void:
	var s := _make("settings", SIZES[0])
	var rows: Array[Button] = _row_buttons(s)
	assert_int(rows.size()).is_greater_equal(7)
	for b: Button in rows:
		var tile := b.get_child(0).get_child(0) as PanelContainer
		assert_vector(tile.custom_minimum_size).is_equal(Vector2(74, 74))
		assert_float(b.custom_minimum_size.y).is_greater_equal(UiTokens.TOUCH_MIN)
	for t: Node in s.find_children("*", "CheckButton", true, false):
		var tex: Texture2D = (t as CheckButton).get_theme_icon("checked")
		assert_int(tex.get_width()).is_greater_equal(112)
		assert_int(tex.get_height()).is_greater_equal(64)
	for n: Node in s.find_children("*", "PanelContainer", true, false):
		if n.theme_type_variation != &"CardRow":
			continue
		var col: Node = n.get_child(0)
		var seps: int = 0
		var btns: int = 0
		for c: Node in col.get_children():
			if c is ColorRect and (c as ColorRect).visible:
				seps += 1
			elif c is Button and (c as Button).visible:
				btns += 1
		assert_int(seps).is_equal(btns - 1)


func test_settings_language_cycle() -> void:
	var s := _make("settings", SIZES[0]) as SettingsScreen
	var codes: Array[String] = []
	for e: Array in SettingsScreen.LOCALES:
		codes.append(e[1])
	assert_str(s.language_value_label.text).is_equal(tr("set_lang_system"))
	s.language_button.pressed.emit()
	assert_str(str(s.state.settings["locale"])).is_equal(codes[1])
	for i in codes.size() - 1:
		s.language_button.pressed.emit()
	assert_str(str(s.state.settings["locale"])).is_equal(codes[0])


func test_settings_de_no_truncation() -> void:
	TranslationServer.set_locale("de")
	var s := _make("settings", SIZES[0])
	for text: String in ["Barrierefreiheit und Sprache", "Käufe wiederherst."]:
		var found: bool = false
		for n: Node in s.find_children("*", "Label", true, false):
			var l := n as Label
			if l.text.to_upper() == text.to_upper() or l.text == text:
				found = true
				assert_float(l.get_minimum_size().x).is_less_equal(l.size.x + 1.0)
		assert_bool(found).is_true()
	TranslationServer.set_locale("en")


func _themes(coins: int, locale: String = "en", size: Vector2 = SIZES[0]) -> ThemesScreen:
	TranslationServer.set_locale(locale)
	var st := GameState.new()
	st.level = 12
	st.coins = coins
	st.themes_owned = ["classic"]
	st.theme_active = "classic"
	var s := ThemesScreen.new()
	s.state = st
	auto_free(s)
	UiTestFit.fit_root(s, size)
	add_child(s)
	return s


func test_themes_locked_price_button() -> void:
	var s := _themes(350)
	for id: String in ["pastel", "neon", "ocean"]:
		var b := s.card_button(id)
		assert_str(b.text).is_equal(str(ThemeCatalog.cost(id)))
		assert_bool(b.disabled).is_true()
		assert_bool((s.cards[id]["coin"] as Control).visible).is_true()
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		assert_float(sb.border_color.r).is_equal_approx(UiTokens.ACCENT.r, 0.01)
		assert_float(sb.border_color.g).is_equal_approx(UiTokens.ACCENT.g, 0.01)
		assert_float(sb.border_color.a).is_equal_approx(0.5, 0.01)
		assert_that(b.get_theme_color("font_color")).is_equal(UiTokens.ACCENT)
		assert_that(b.get_theme_color("font_disabled_color")).is_equal(UiTokens.ACCENT)
	TranslationServer.set_locale("en")


func test_themes_active_check_marker() -> void:
	var s := _themes(350)
	assert_bool((s.cards["classic"]["check"] as Control).visible).is_true()
	var sb := (s.cards["classic"]["check"] as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(sb.bg_color).is_equal(UiTokens.ACCENT)
	assert_that((s.cards["classic"]["check_icon"] as Control).modulate).is_equal(UiTokens.ON_ACCENT)
	assert_bool((s.cards["pastel"]["check"] as Control).visible).is_false()


func test_themes_progress_hint() -> void:
	var s := _themes(350)
	assert_bool(s.progress_hint.visible).is_true()
	assert_str(s.progress_hint.text).is_equal(tr("themes_hint"))
	assert_str(s.progress_hint.text).is_not_equal("themes_hint")
	assert_str(s.progress_amount.text).is_equal("350 / %d" % ThemeCatalog.cost("pastel"))


func test_themes_geometry_fits_and_no_overlap() -> void:
	for locale: String in ["en", "de"]:
		for size: Vector2 in SIZES:
			var s := _themes(350, locale, size)
			await get_tree().process_frame
			await get_tree().process_frame
			assert_float(s.progress_panel.get_global_rect().end.y).is_less_equal(size.y)
			for pv: Control in s.previews:
				assert_float(pv.size.y).is_greater_equal(float(ThemesScreen.PREVIEW_MIN_H))
				for i: int in 4:
					var tr_rect: Rect2 = pv.call("tube_rect", i)
					assert_bool(Rect2(Vector2.ZERO, pv.size).encloses(tr_rect)).is_true()
			for id: String in s.cards:
				var nl := s.card_name_label(id)
				var chk := s.cards[id]["check"] as Control
				if chk.visible:
					assert_bool(nl.get_global_rect().intersects(chk.get_global_rect())).is_false()
	TranslationServer.set_locale("en")
