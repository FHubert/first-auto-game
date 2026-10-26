extends GdUnitTestSuite

const THEME := preload("res://assets/fonts/ui_theme.tres")
const TAG_WGHT: int = 2003265652  # "wght" axis tag
const STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
const BUTTONS: Array[String] = [
	"ButtonPrimary", "ButtonAccent", "ButtonSecondary", "ButtonIcon", "ButtonNav", "ButtonHud"
]
const LABELS: Array[String] = ["LabelTitle", "LabelCaption", "LabelSection"]


func test_constants() -> void:
	assert_int(UiTokens.FONT_XS).is_equal(24)
	assert_int(UiTokens.BTN_H).is_equal(103)
	assert_int(UiTokens.HUD_BTN).is_equal(118)
	assert_int(UiTokens.TOUCH_MIN).is_equal(81)
	assert_int(UiTokens.SCREEN_PAD).is_equal(37)


func test_contrast_sanity() -> void:
	assert_float(UiTokens.contrast_ratio(Color.WHITE, Color.BLACK)).is_equal_approx(21.0, 0.01)


func test_default_button_has_all_states() -> void:
	for s in STATES:
		assert_bool(THEME.has_stylebox(s, "Button")).is_true()


func test_button_variants_structure() -> void:
	for v in BUTTONS:
		assert_str(str(THEME.get_type_variation_base(v))).is_equal("Button")
		assert_bool(THEME.has_color("font_color", v)).is_true()
		for s in STATES:
			assert_bool(THEME.has_stylebox(s, v)).is_true()


func test_button_close_variant() -> void:
	assert_str(str(THEME.get_type_variation_base("ButtonClose"))).is_equal("Button")
	for s in STATES:
		var sb: StyleBoxFlat = THEME.get_stylebox(s, "ButtonClose")
		assert_vector(sb.get_minimum_size()).is_equal(Vector2.ZERO)
	var n: StyleBoxFlat = THEME.get_stylebox("normal", "ButtonClose")
	assert_bool(n.bg_color.is_equal_approx(UiTokens.CARD_ROW)).is_true()
	assert_int(n.border_width_bottom).is_equal(0)


func test_label_and_panel_variants() -> void:
	for v in LABELS:
		assert_str(str(THEME.get_type_variation_base(v))).is_equal("Label")
		assert_bool(THEME.has_font_size("font_size", v)).is_true()
		var fg: Color = THEME.get_color("font_color", v)
		assert_float(UiTokens.contrast_ratio(fg, UiTokens.BG)).is_greater_equal(4.5)
	for v in ["Card", "CardRow"]:
		assert_str(str(THEME.get_type_variation_base(v))).is_equal("PanelContainer")
		assert_bool(THEME.has_stylebox("panel", v)).is_true()


func test_button_contrast_and_raised_effect() -> void:
	for v in BUTTONS:
		var n: StyleBoxFlat = THEME.get_stylebox("normal", v)
		var p: StyleBoxFlat = THEME.get_stylebox("pressed", v)
		var d: StyleBoxFlat = THEME.get_stylebox("disabled", v)
		var fg: Color = THEME.get_color("font_color", v)
		var fgd: Color = THEME.get_color("font_disabled_color", v)
		assert_float(UiTokens.contrast_ratio(fg, n.bg_color)).is_greater_equal(4.5)
		assert_float(UiTokens.contrast_ratio(fgd, d.bg_color)).is_greater_equal(4.5)
		assert_int(n.shadow_size).is_equal(0)
		assert_int(n.border_width_bottom).is_between(7, 13)
		assert_int(p.border_width_bottom).is_equal(0)
		assert_bool(n.border_color != n.bg_color).is_true()
		assert_float(p.content_margin_top).is_greater(n.content_margin_top)


func test_button_min_height() -> void:
	for v in BUTTONS:
		var b: Button = auto_free(Button.new())
		b.theme = THEME
		b.theme_type_variation = v
		b.text = "Graj"
		add_child(b)
		assert_float(b.get_combined_minimum_size().y).is_greater_equal(UiTokens.TOUCH_MIN)
		var n: StyleBoxFlat = THEME.get_stylebox("normal", v)
		var fs: int = THEME.get_font_size("font_size", v)
		assert_float(n.content_margin_top + n.content_margin_bottom + fs).is_greater_equal(
			UiTokens.TOUCH_MIN
		)


func test_variants_match_tokens() -> void:
	var cases: Array = [
		["ButtonPrimary", UiTokens.PRIMARY, UiTokens.ON_PRIMARY],
		["ButtonAccent", UiTokens.ACCENT, UiTokens.ON_ACCENT],
		["ButtonSecondary", UiTokens.CARD_ROW, UiTokens.TEXT],
	]
	for c in cases:
		var n: StyleBoxFlat = THEME.get_stylebox("normal", c[0])
		assert_bool(n.bg_color.is_equal_approx(c[1])).is_true()
		assert_bool(THEME.get_color("font_color", c[0]).is_equal_approx(c[2])).is_true()


func test_icons_load_96px() -> void:
	assert_int(UiTokens.ICON_NAMES.size()).is_equal(31)
	for n in UiTokens.ICON_NAMES:
		var tex: Texture2D = UiTokens.icon(n)
		assert_object(tex).is_not_null()
		assert_int(tex.get_width()).is_equal(96)


func test_font_weights() -> void:
	var expected: Dictionary = {"LabelTitle": 900, "ButtonPrimary": 900, "LabelCaption": 700}
	for type_name: String in expected:
		var f: Font = THEME.get_font("font", type_name)
		assert_bool(f is FontVariation).is_true()
		assert_float((f as FontVariation).variation_opentype[TAG_WGHT]).is_equal(
			float(expected[type_name])
		)
	assert_bool(THEME.default_font is FontVariation).is_true()
	assert_float((THEME.default_font as FontVariation).variation_opentype[TAG_WGHT]).is_equal(700.0)


func test_button_hud_is_circle_in_all_states() -> void:
	for st in STATES:
		var sb: StyleBoxFlat = THEME.get_stylebox(st, "ButtonHud")
		assert_int(sb.corner_radius_top_left).is_equal(UiTokens.HUD_BTN / 2)
		assert_int(sb.corner_radius_bottom_right).is_equal(UiTokens.HUD_BTN / 2)
		assert_int(sb.corner_radius_top_right).is_equal(UiTokens.HUD_BTN / 2)
		assert_int(sb.corner_radius_bottom_left).is_equal(UiTokens.HUD_BTN / 2)


func test_button_pill_flat_in_all_states() -> void:
	assert_str(str(THEME.get_type_variation_base("ButtonPill"))).is_equal("Button")
	var n: StyleBoxFlat = THEME.get_stylebox("normal", "ButtonPill")
	for st in STATES:
		var sb: StyleBoxFlat = THEME.get_stylebox(st, "ButtonPill")
		assert_int(sb.border_width_bottom).is_equal(0)
	var p: StyleBoxFlat = THEME.get_stylebox("pressed", "ButtonPill")
	assert_float(p.content_margin_top).is_equal(n.content_margin_top)
	assert_float(p.content_margin_bottom).is_equal(n.content_margin_bottom)


func test_button_pill_pressed_darker_t315() -> void:
	var n: StyleBoxFlat = THEME.get_stylebox("normal", "ButtonPill")
	var p: StyleBoxFlat = THEME.get_stylebox("pressed", "ButtonPill")
	assert_float(p.bg_color.get_luminance()).is_less(n.bg_color.get_luminance())
	assert_float(p.bg_color.a).is_equal(n.bg_color.a)
	var fg: Color = THEME.get_color("font_pressed_color", "ButtonPill")
	assert_float(UiTokens.contrast_ratio(fg, p.bg_color)).is_greater_equal(4.5)


func test_new_variants_contrast_and_touch_height() -> void:
	for v in ["ButtonHud", "ButtonPill"]:
		var n: StyleBoxFlat = THEME.get_stylebox("normal", v)
		var fg: Color = THEME.get_color("font_color", v)
		assert_float(UiTokens.contrast_ratio(fg, n.bg_color)).is_greater_equal(4.5)
		var b: Button = auto_free(Button.new())
		b.theme = THEME
		b.theme_type_variation = v
		b.text = "Graj"
		add_child(b)
		assert_float(b.get_combined_minimum_size().y).is_greater_equal(UiTokens.TOUCH_MIN)
