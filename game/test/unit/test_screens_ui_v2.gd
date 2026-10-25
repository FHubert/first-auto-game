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
	s.size = size
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
