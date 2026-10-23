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


func test_level_params_gdd_table() -> void:
	var g := ContentGenerator.new()
	var levels: Array[int] = [1, 2, 5, 8, 19, 20, 40, 56]
	var colors: Array[int] = [2, 3, 3, 4, 5, 6, 9, 12]
	var tubes: Array[int] = [4, 5, 5, 6, 7, 8, 11, 14]
	var floors: Array[int] = [3, 4, 4, 6, 9, 9, 16, 24]
	var diffs: Array[float] = [0.15, 0.16, 0.12, 0.23, 0.52, 0.36, 0.62, 1.0]
	var breathers: Array[int] = [5, 20, 40]
	for i in levels.size():
		var p: Dictionary = g.level_params(levels[i])
		assert_int(p["level"]).is_equal(levels[i])
		assert_int(p["capacity"]).is_equal(4)
		assert_int(p["empty_tubes"]).is_equal(2)
		assert_int(p["colors"]).is_equal(colors[i])
		assert_int(p["tubes"]).is_equal(tubes[i])
		assert_int(p["min_moves_floor"]).is_equal(floors[i])
		assert_float(p["difficulty"]).is_equal_approx(diffs[i], 0.02)
		assert_bool(p["breather"]).is_equal(levels[i] in breathers)


func test_level_params_invariants() -> void:
	var g := ContentGenerator.new()
	var max_colors: int = int(GameConfig.get_value("colors_max"))
	var prev: int = 0
	for level in range(1, 201):
		var p: Dictionary = g.level_params(level)
		assert_bool(p["colors"] >= prev).is_true()
		assert_bool(p["colors"] <= max_colors).is_true()
		assert_bool(p["min_moves_floor"] >= p["colors"]).is_true()
		prev = p["colors"]


func test_level_params_follow_remote_config() -> void:
	GameConfig.apply_remote({"tube_capacity": 5})
	var capacity: int = ContentGenerator.new().level_params(3)["capacity"]
	GameConfig.reset()
	assert_int(capacity).is_equal(5)


func test_daily_params() -> void:
	var p: Dictionary = ContentGenerator.new().daily_params(20750)
	assert_int(p["utc_day"]).is_equal(20750)
	assert_int(p["level"]).is_equal(0)
	assert_int(p["colors"]).is_equal(8)
	assert_int(p["tubes"]).is_equal(10)
	assert_bool(p["breather"]).is_false()
	assert_int(p["min_moves_floor"]).is_equal(ceili(8 * 1.8))
