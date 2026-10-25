extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_settings.json"

var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()
	SaveSystem.save_path = _old_path


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _settings() -> SettingsScreen:
	var s: SettingsScreen = auto_free(load("res://src/ui/settings_screen.tscn").instantiate())
	s.state = GameState.new()
	add_child(s)
	return s


func test_home_shows_state() -> void:
	var st := GameState.new()
	st.coins = 123
	st.level = 7
	st.streak_days = 3
	var home: Home = auto_free(load("res://src/ui/home.tscn").instantiate())
	home.clock = TestClock.fixed()
	home.state = st
	add_child(home)
	assert_str(home.play_level_label.text).contains("7")
	assert_str(home.coins_label.text).contains("123")
	assert_str(home.streak_label.text).contains("3")
	assert_float(home.theme_progress.max_value).is_equal(600.0)
	assert_float(home.theme_progress.value).is_equal(123.0)
	var count: Array[int] = [0]
	home.play_pressed.connect(func() -> void: count[0] += 1)
	home.play_button.pressed.emit()
	assert_int(count[0]).is_equal(1)


func test_music_toggle_persists() -> void:
	var s := _settings()
	s.music_toggle.button_pressed = false
	assert_bool(s.state.settings.music_on).is_false()
	assert_bool(SaveSystem.load().settings.music_on).is_false()


func test_locale_persists() -> void:
	var s := _settings()
	s.language_button.pressed.emit()
	assert_str(s.state.settings.locale).is_equal("en")
	assert_str(SaveSystem.load().settings.locale).is_equal("en")
	s.language_button.pressed.emit()
	assert_str(s.state.settings.locale).is_equal("pl")


func test_version_and_apply_from_state() -> void:
	var s := _settings()
	assert_str(s.version_label.text).contains(Version.VERSION)
	s.state.settings["sfx_on"] = false
	s.apply_from_state()
	assert_bool(s.sfx_toggle.button_pressed).is_false()
