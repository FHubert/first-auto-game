extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_daily_share.json"

var _copied: Array[String] = []
var _prev_analytics: AnalyticsProvider
var _fake: FakeAnalyticsProvider
var _old_path: String


func before_test() -> void:
	TranslationServer.set_locale("en")
	GameConfig.reset()
	_copied.clear()
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH


func after_test() -> void:
	Analytics.provider = _prev_analytics
	SaveSystem.save_path = _old_path
	GameConfig.reset()
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _lc() -> LevelComplete:
	var lc: LevelComplete = load("res://src/ui/level_complete.tscn").instantiate()
	add_child(lc)
	lc.clipboard_setter = func(t: String) -> void: _copied.append(t)
	return lc


func test_text_with_star() -> void:
	assert_str(DailyShare.text(20750, 7, 7, 3)).is_equal(
		"Vialo Daily #1\n7 moves (min 7) ★\nStreak: 3"
	)


func test_text_without_star() -> void:
	var m: int = 7 + int(GameConfig.get_value("par_slack_moves")) + 1
	assert_str(DailyShare.text(20751, m, 7, 1)).is_equal(
		"Vialo Daily #2\n%d moves (min 7)\nStreak: 1" % m
	)


func test_button_visibility() -> void:
	var lc := _lc()
	assert_bool(lc.btn_copy_result.visible).is_false()
	lc.set_share("x")
	assert_bool(lc.btn_copy_result.visible).is_true()
	lc.show_result(5, false, 1)
	assert_bool(lc.btn_copy_result.visible).is_false()


func test_click_copies_once() -> void:
	var lc := _lc()
	lc.set_share("hello")
	lc.btn_copy_result.pressed.emit()
	assert_array(_copied).contains_exactly(["hello"])
	assert_bool(lc.btn_copy_result.disabled).is_true()
	assert_str(lc.btn_copy_result.text).is_equal("Copied!")
	var n: int = 0
	for e in _fake.events:
		if e.get("event_id", "") == "daily:share":
			n += 1
	assert_int(n).is_equal(1)


func test_level_daily_win_shows_share() -> void:
	var level: Level = load("res://src/levels/level.tscn").instantiate()
	level.state = GameState.new()
	level.clock = func() -> int: return 20750 * 86400 + 100
	add_child(level)
	level.start_daily(20750)
	level._on_round_won()
	assert_bool(level.level_complete.btn_copy_result.visible).is_true()
	assert_bool(level.level_complete._share_text.begins_with("Vialo Daily #1")).is_true()
	level.free()
