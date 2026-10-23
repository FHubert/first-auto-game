extends GdUnitTestSuite


func test_same_seed_is_deterministic() -> void:
	var g := ContentGenerator.new()
	assert_dict(g.generate(123, 5)).is_equal(g.generate(123, 5))


func test_output_shape() -> void:
	var data: Dictionary = ContentGenerator.new().generate(9, 4)
	assert_int(data["seed"]).is_equal(9)
	assert_int(data["level"]).is_equal(4)
	assert_float(data["difficulty"]).is_between(0.0, 1.0)
	assert_bool(data["payload"] is Dictionary).is_true()


func test_difficulty_curve_is_monotonic() -> void:
	var g := ContentGenerator.new()
	var prev: float = g.difficulty_curve(1)
	for level in range(2, 101):
		var cur: float = g.difficulty_curve(level)
		assert_bool(cur >= prev).is_true()
		prev = cur


func test_difficulty_within_config_bounds() -> void:
	var g := ContentGenerator.new()
	var lo: float = float(GameConfig.get_value("difficulty_min"))
	var hi: float = float(GameConfig.get_value("difficulty_max"))
	for level in [1, 20, 500]:
		assert_float(g.difficulty_curve(level)).is_between(lo, hi)


func test_is_solvable_placeholder() -> void:
	var g := ContentGenerator.new()
	assert_bool(g.is_solvable(g.generate(1, 1))).is_true()
