extends GdUnitTestSuite


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
