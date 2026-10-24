extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_home_daily_badge.json"
const TEST_DAY: int = 20000
const TEST_NOW_UNIX: int = TEST_DAY * 86400 + 100

var _old_path: String
var _old_provider: AnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	_old_provider = Analytics.provider
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()
	SaveSystem.save_path = _old_path
	Analytics.provider = _old_provider


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _home(level: int, seen: bool, done_today: bool = false) -> Home:
	var st := GameState.new()
	st.level = level
	st.settings["daily_intro_seen"] = seen
	if done_today:
		st.daily_last_completed_day = TEST_DAY
	var home: Home = auto_free(load("res://src/ui/home.tscn").instantiate())
	home.state = st
	home.clock = func() -> int: return TEST_NOW_UNIX
	add_child(home)
	return home


func test_badge_hidden_when_locked() -> void:
	assert_bool(_home(2, false).daily_new_badge.visible).is_false()


func test_badge_visible_when_unlocked_and_unseen() -> void:
	var home := _home(int(GameConfig.get_value("daily_unlock_level")), false)
	assert_bool(home.daily_new_badge.visible).is_true()
	assert_str(home.daily_new_badge.text).is_not_empty()


func test_badge_hidden_when_seen() -> void:
	assert_bool(_home(5, true).daily_new_badge.visible).is_false()


func test_badge_hidden_when_completed_today() -> void:
	assert_bool(_home(5, false, true).daily_new_badge.visible).is_false()


func test_daily_pressed_sets_flag_saves_and_tracks_once() -> void:
	var fake := FakeAnalyticsProvider.new()
	Analytics.provider = fake
	var app: App = auto_free(App.new())
	app.clock = func() -> int: return TEST_NOW_UNIX
	app.state = GameState.new()
	app.state.level = 5
	app.state.settings["tutorial_done"] = true
	add_child(app)
	(app.current_screen() as Home).daily_pressed.emit()
	assert_bool(SaveSystem.load().settings["daily_intro_seen"]).is_true()
	var n: int = 0
	for e in fake.events:
		if e["type"] == "design" and str(e.get("event_id", "")) == "nav:daily":
			n += 1
	assert_int(n).is_equal(1)
	await get_tree().process_frame
