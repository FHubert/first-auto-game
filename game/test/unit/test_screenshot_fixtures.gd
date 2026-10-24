extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_screenshot_fixtures.json"

var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH


func after_test() -> void:
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func test_every_fixture_is_valid_and_round_trips() -> void:
	for name in ScreenshotArgs.KNOWN_FIXTURES:
		var state: GameState = ScreenshotFixtures.make(name)
		assert_object(state).is_not_null()
		var copy: GameState = GameState.from_dict(state.to_dict())
		assert_int(copy.level).is_equal(state.level)
		assert_int(copy.coins).is_equal(state.coins)


func test_unknown_fixture_is_null() -> void:
	assert_object(ScreenshotFixtures.make("zzz")).is_null()


func test_midgame_values() -> void:
	var state: GameState = ScreenshotFixtures.make("midgame")
	assert_bool(bool(state.settings["tutorial_done"])).is_true()
	assert_int(state.coins).is_equal(ScreenshotFixtures.MIDGAME_COINS)
	assert_int(state.levels_completed).is_equal(19)
	assert_array(state.themes_owned).contains(["classic", "neon"])


func test_aso_daily_previews_cycle_day_five() -> void:
	var today: int = 20000
	var state: GameState = ScreenshotFixtures.make("aso_daily", today)
	var preview: Dictionary = DailyRewards.preview(state, today)
	assert_int(int(preview["cycle_day"])).is_equal(5)
	assert_bool(bool(preview["can_claim"])).is_true()


func test_aso_themes_owns_all_four() -> void:
	var state: GameState = ScreenshotFixtures.make("aso_themes")
	assert_int(state.themes_owned.size()).is_equal(4)
	assert_bool(state.themes_owned.has(state.theme_active)).is_true()


func test_win_result_matches_economy() -> void:
	var result: Dictionary = ScreenshotFixtures.win_result()
	var expected: int = Economy.win_reward({"won": true, "perfect": true})
	assert_int(int(result["coins"])).is_equal(expected)
	assert_int(expected).is_greater(0)


func test_apply_win_shows_real_coins_and_perfect() -> void:
	var level: Level = load("res://src/levels/level.tscn").instantiate()
	level.clock = TestClock.fixed()
	level.state = ScreenshotFixtures.make("aso_win")
	add_child(level)
	ScreenshotFixtures.apply_win(level)
	var expected: int = Economy.win_reward({"won": true, "perfect": true})
	var coins_label: Label = level.level_complete.coins_label
	assert_str(coins_label.text).is_not_equal(tr("lc_coins") % 0)
	assert_str(coins_label.text).is_equal(tr("lc_coins") % expected)
	assert_bool(level.level_complete.perfect_label.visible).is_true()
	level.free()
