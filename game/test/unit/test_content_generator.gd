extends GdUnitTestSuite

## Odcisk determinizmu (nie jest poprawnym FNV-1a): pierwotny literał 0xCBF29CE484222325
## nie mieści się w int64 i Godot przycinał go do INT64_MAX; golden hashe policzono z tą wartością.
const FNV_OFFSET: int = 9223372036854775807
const FNV_PRIME: int = 0x100000001B3
const SLOW_REPORTED: int = 5
const MAX_MS_PER_LEVEL: int = 500
const MAX_MS_HARD: int = 2000
const P95_INDEX: int = 9
## baza 17154 (seed campaign_seed, 2026-10-24) × 1,10
const EXPANDED_BUDGET: int = 18900
const MIN_FLOOR_RATIO: float = 0.95
const LEVELS_TOTAL: int = 200
## Golden hashes of `tubes` (campaign_seed). Change = conscious decision, ADR-009.
const GOLDEN: Dictionary = {
	1: -4751766699485149607,
	2: -5848858387169416426,
	10: -1683731330142263527,
	50: -4356125187416833428,
}


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


func _hash_tubes(tubes: Array) -> int:
	var h: int = FNV_OFFSET
	for t in tubes:
		for c in t:
			h = ((h ^ int(c)) * FNV_PRIME)
		h = ((h ^ 0xFF) * FNV_PRIME)
	return h


func test_generate_is_deterministic_tubes() -> void:
	var g := ContentGenerator.new()
	var a: Dictionary = g.generate(1, 7)["payload"]
	var b: Dictionary = g.generate(1, 7)["payload"]
	assert_array(a["tubes"]).is_equal(b["tubes"])
	assert_array(a["solution"]).is_equal(b["solution"])


func test_golden_hashes() -> void:
	var g := ContentGenerator.new()
	var seed_value: int = int(GameConfig.get_value("campaign_seed"))
	for level in GOLDEN:
		var h: int = _hash_tubes(g.generate(seed_value, level)["payload"]["tubes"])
		print("GOLDEN level=%d hash=%d" % [level, h])
		assert_int(h).is_equal(GOLDEN[level])


func test_levels_1_to_200_solvable_and_fast() -> void:
	var g := ContentGenerator.new()
	var seed_value: int = int(GameConfig.get_value("campaign_seed"))
	var max_attempts: int = int(GameConfig.get_value("gen_max_attempts"))
	var timings: Array = []
	var at_floor: int = 0
	var total_ms: int = 0
	var expanded_total: int = 0
	for level in range(1, LEVELS_TOTAL + 1):
		var t0: int = Time.get_ticks_msec()
		var data: Dictionary = g.generate(seed_value, level)
		var ms: int = Time.get_ticks_msec() - t0
		total_ms += ms
		var p: Dictionary = data["payload"]
		expanded_total += int(p["expanded"])
		timings.append([ms, level, int(p["expanded"]), int(p["attempt"]), p["min_moves_exact"]])
		assert_int(p["min_moves"]).is_greater(0)
		assert_int((p["solution"] as Array).size()).is_equal(p["min_moves"])
		assert_bool(g.is_solvable(data)).is_true()
		assert_int(p["attempt"]).is_less(max_attempts)
		assert_bool(p.get("fallback", false)).is_false()
		assert_int((p["tubes"] as Array).size()).is_equal(p["colors"] + 2)
		for t in p["tubes"]:
			assert_int((t as Array).size()).is_less_equal(p["capacity"])
		if p["min_moves"] >= p["min_moves_floor"]:
			at_floor += 1
	var ratio: float = float(at_floor) / float(LEVELS_TOTAL)
	print("FLOOR ratio=%.3f (%d/%d)" % [ratio, at_floor, LEVELS_TOTAL])
	assert_float(ratio).is_greater_equal(MIN_FLOOR_RATIO)
	timings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in SLOW_REPORTED:
		var r: Array = timings[i]
		print("GEN level=%d ms=%d expanded=%d attempt=%d exact=%s" % [r[1], r[0], r[2], r[3], r[4]])
	print(
		(
			"GEN avg_ms=%.1f p95_ms=%d max_ms=%d expanded_total=%d"
			% [float(total_ms) / LEVELS_TOTAL, timings[P95_INDEX][0], timings[0][0], expanded_total]
		)
	)
	assert_int(timings[P95_INDEX][0]).is_less_equal(MAX_MS_PER_LEVEL)
	assert_int(timings[0][0]).is_less_equal(MAX_MS_HARD)
	assert_int(expanded_total).is_less_equal(EXPANDED_BUDGET)


func test_generate_daily() -> void:
	var g := ContentGenerator.new()
	var a: Dictionary = g.generate_daily(20750)
	var b: Dictionary = g.generate_daily(20751)
	assert_int(a["utc_day"]).is_equal(20750)
	assert_int(a["level"]).is_equal(0)
	assert_int(a["payload"]["colors"]).is_equal(int(GameConfig.get_value("daily_colors")))
	assert_bool(a["payload"]["tubes"] == b["payload"]["tubes"]).is_false()
	assert_bool(g.is_solvable(a)).is_true()
	assert_bool(g.is_solvable(b)).is_true()


func test_is_solvable_generated_and_rejects_bad() -> void:
	var g := ContentGenerator.new()
	assert_bool(g.is_solvable(g.generate(1, 3))).is_true()
	assert_bool(g.is_solvable({"payload": {"min_moves": 0}})).is_false()
