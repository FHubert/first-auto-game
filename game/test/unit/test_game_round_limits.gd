extends GdUnitTestSuite
## Testy limitów GameRound (ACTION_BASE, dodatkowa probówka).


func before_test() -> void:
	GameConfig.reset()


func test_action_base_fits_max_tube_count() -> void:
	var d: Dictionary = GameConfig.DEFAULTS
	var total: int = (
		int(d["colors_max"]) + int(d["empty_tubes"]) + int(d["extra_tube_max_per_level"])
	)
	assert_int(total).is_less_equal(GameRound.ACTION_BASE)


func test_add_extra_tube_adds_one_empty_tube() -> void:
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(1, 1))
	var before: int = r.board().tube_count()
	assert_bool(r.add_extra_tube()).is_true()
	assert_int(r.board().tube_count()).is_equal(before + 1)
