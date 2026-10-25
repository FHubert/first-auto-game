extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_screenshot_fixtures.json"

var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH


func after_test() -> void:
	SaveSystem.save_path = _old_path
	TestSaveCleanup.remove(SAVE_PATH)
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


func test_aso_themes_has_priced_locked_theme_unaffordable() -> void:
	var state: GameState = ScreenshotFixtures.make("aso_themes")
	assert_bool(state.themes_owned.has(state.theme_active)).is_true()
	var next_id: String = ThemeCatalog.next_theme_id(state)
	assert_str(next_id).is_not_equal("")
	assert_int(ThemeCatalog.cost(next_id)).is_greater(0)
	assert_bool(ThemeCatalog.can_buy(state, next_id)).is_false()


func test_aso_shop_shows_starter_offer_with_eleven_hours_left() -> void:
	var today: int = 20000
	var now: int = today * ScreenshotFixtures.SECONDS_PER_DAY
	var state: GameState = ScreenshotFixtures.make("aso_shop", today)
	var purchases: Node = auto_free(load("res://src/systems/purchases.gd").new())
	purchases.state = state
	assert_bool(purchases.starter_offer_visible(state.level, now)).is_true()
	var window_s: int = int(GameConfig.get_value("starter_offer_hours")) * 3600
	var left_s: int = state.starter_offer_start_day + window_s - now
	assert_int(left_s).is_equal(ScreenshotFixtures.SHOP_OFFER_HOURS_LEFT * 3600)
	assert_int(state.coins).is_equal(ScreenshotFixtures.ASO_COINS)


func test_daily_shows_three_claimed_days() -> void:
	var today: int = 20000
	var state: GameState = ScreenshotFixtures.make("daily", today)
	assert_int(state.streak_days).is_equal(3)
	assert_bool(DailyRewards.preview(state, today)["can_claim"]).is_true()
	var popup: DailyRewardPopup = load("res://src/ui/daily_reward_popup.tscn").instantiate()
	add_child(popup)
	popup.show_for(state, today)
	var checked: int = 0
	for c in popup.checks:
		if c.visible:
			checked += 1
	assert_int(checked).is_equal(3)
	popup.free()


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


func test_symbols_neon_uses_neon_theme_with_symbols() -> void:
	var state: GameState = ScreenshotFixtures.make("symbols_neon")
	assert_str(state.theme_active).is_equal(ScreenshotFixtures.MIDGAME_EXTRA_THEME)
	assert_array(state.themes_owned).contains([ScreenshotFixtures.MIDGAME_EXTRA_THEME])
	assert_bool(bool(state.settings[ColorSymbols.SETTING_KEY])).is_true()
