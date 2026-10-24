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


func test_settings_language_label_above_option() -> void:
	var s: SettingsScreen = auto_free(load("res://src/ui/settings_screen.tscn").instantiate())
	s.state = GameState.new()
	add_child(s)
	assert_object(s.language_label).is_not_null()
	assert_str(s.language_label.text).is_equal(tr("set_language"))
	assert_bool(s.language_label.get_index() < s.locale_option.get_index()).is_true()
