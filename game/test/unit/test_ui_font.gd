extends GdUnitTestSuite

const FONT_PATH: String = "res://assets/fonts/nunito.ttf"
const THEME_PATH: String = "res://assets/fonts/ui_theme.tres"
const CSV_PATH: String = "res://locale/strings.csv"
const DIACRITICS: String = "ąćęłńóśźżĄĆĘŁŃÓŚŹŻäöüßÄÖÜ"


func test_font_loads() -> void:
	assert_object(load(FONT_PATH) as Font).is_not_null()


func test_theme_has_default_font() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_object(theme).is_not_null()
	assert_object(theme.default_font).is_not_null()


func test_font_has_diacritics() -> void:
	var font := load(FONT_PATH) as Font
	for ch in DIACRITICS:
		(
			assert_bool(font.has_char(ch.unicode_at(0)))
			. override_failure_message("brak glifu '%s'" % ch)
			. is_true()
		)


func test_font_covers_all_strings() -> void:
	var font := load(FONT_PATH) as Font
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 4:
			continue
		for col in range(1, 4):
			for ch in row[col]:
				if ch.strip_edges().is_empty():
					continue
				(
					assert_bool(font.has_char(ch.unicode_at(0)))
					. override_failure_message(
						"brak glifu '%s' (U+%04X) w kluczu %s" % [ch, ch.unicode_at(0), row[0]]
					)
					. is_true()
				)


func test_settings_language_row() -> void:
	var s: SettingsScreen = auto_free(load("res://src/ui/settings_screen.tscn").instantiate())
	s.state = GameState.new()
	add_child(s)
	assert_object(s.language_label).is_not_null()
	assert_str(s.language_label.text).is_equal(tr("set_language"))
	assert_object(s.language_button).is_not_null()
	assert_bool(s.language_button.is_ancestor_of(s.language_label)).is_true()
	assert_bool(s.language_button.is_ancestor_of(s.language_value_label)).is_true()


func test_theme_panel_is_opaque() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_bool(theme.has_stylebox("panel", "PanelContainer")).is_true()
	var sb := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_object(sb).is_not_null()
	assert_float(sb.bg_color.a).is_equal(1.0)


func test_level_complete_panel_inherits_opaque_style() -> void:
	var root: Control = auto_free(Control.new())
	root.theme = load(THEME_PATH) as Theme
	add_child(root)
	var lc: Control = auto_free(
		(load("res://src/ui/level_complete.tscn") as PackedScene).instantiate()
	)
	root.add_child(lc)
	var sb := lc.get_node("Panel").get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(sb).is_not_null()
	assert_float(sb.bg_color.a).is_equal(1.0)


func test_daily_popup_panel_inherits_opaque_style() -> void:
	var root: Control = auto_free(Control.new())
	root.theme = load(THEME_PATH) as Theme
	add_child(root)
	var popup: Control = auto_free(DailyRewardPopup.new())
	root.add_child(popup)
	popup.show_sample()
	var found: PanelContainer = null
	for c in popup.find_children("*", "PanelContainer", true, false):
		found = c
		break
	assert_object(found).is_not_null()
	var sb := found.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(sb).is_not_null()
	assert_float(sb.bg_color.a).is_equal(1.0)
