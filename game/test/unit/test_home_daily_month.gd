extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_home_daily_month.json"
const LOCALES: Array = ["en", "pl", "de"]
const HOME_SIZE: Vector2 = Vector2(720, 1280)

var _old_path: String
var _old_locale: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	_old_locale = TranslationServer.get_locale()
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()
	GameConfig.reset()
	SaveSystem.save_path = _old_path
	TranslationServer.set_locale(_old_locale)


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _home(level: int, count: int) -> Home:
	var st := GameState.new()
	st.level = level
	st.daily_month_id = DailyChallenge.month_id(TestClock.FIXED_DAY)
	st.daily_month_count = count
	var home: Home = auto_free(load("res://src/ui/home.tscn").instantiate())
	home.state = st
	home.clock = TestClock.fixed()
	add_child(home)
	return home


func _unlock() -> int:
	return int(GameConfig.get_value("daily_unlock_level"))


func test_hidden_at_zero() -> void:
	assert_bool(_home(_unlock(), 0).daily_month_label.visible).is_false()


func test_visible_with_progress() -> void:
	var home := _home(_unlock(), 5)
	assert_bool(home.daily_month_label.visible).is_true()
	assert_str(home.daily_month_label.text).is_equal(
		tr("home_daily_month") % [5, DailyChallenge.month_goal()]
	)


func test_custom_goal_from_config() -> void:
	GameConfig.set_for_test("daily_month_goal", 3)
	var home := _home(_unlock(), 1)
	assert_str(home.daily_month_label.text).is_equal(tr("home_daily_month") % [1, 3])
	assert_str(home.daily_month_label.text).contains("1/3")


func test_done_text_at_goal() -> void:
	var home := _home(_unlock(), DailyChallenge.month_goal())
	assert_bool(home.daily_month_label.visible).is_true()
	assert_str(home.daily_month_label.text).is_equal(tr("home_daily_month_done"))


func test_hidden_when_locked() -> void:
	assert_bool(_home(2, 5).daily_month_label.visible).is_false()


func test_label_fits_card_in_all_locales() -> void:
	var goal: int = DailyChallenge.month_goal()
	for loc: String in LOCALES:
		TranslationServer.set_locale(loc)
		for count: int in [goal - 1, goal]:
			var home := _home(_unlock(), count)
			home.size = HOME_SIZE
			await get_tree().process_frame
			await get_tree().process_frame
			assert_float(home.daily_month_label.get_combined_minimum_size().x).is_less_equal(
				home.daily_card.size.x
			)
