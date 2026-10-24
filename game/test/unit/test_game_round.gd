extends GdUnitTestSuite
## Testy GameRound (ruchy, undo, restart, boostery, podpowiedź, wynik).


func before_test() -> void:
	GameConfig.reset()


func _round_for(level: int) -> GameRound:
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(1, level))
	return r


func _round_from_tubes(tubes: Array, min_moves: int = 1) -> GameRound:
	var payload: Dictionary = {
		"capacity": 4,
		"colors": 2,
		"tubes": tubes,
		"min_moves": min_moves,
		"min_moves_exact": true,
		"solution": [],
	}
	var r := GameRound.new()
	r.start({"seed": 1, "level": 1, "difficulty": 0.0, "payload": payload})
	return r


func _play(r: GameRound, path: Array) -> void:
	for m: Vector2i in path:
		r.step(GameRound.encode_action(m.x, m.y))


func test_encode_decode_action() -> void:
	for p: Vector2i in [Vector2i(0, 0), Vector2i(1, 2), Vector2i(0, 15), Vector2i(15, 0)]:
		var a: int = GameRound.encode_action(p.x, p.y)
		assert_int(a).is_equal(p.x * 16 + p.y)
		assert_that(GameRound.decode_action(a)).is_equal(p)


func test_step_legal_and_illegal() -> void:
	var r := _round_from_tubes([[0, 1], [1], [0]])
	assert_bool(r.try_move(2, 1)).is_false()
	assert_bool(r.try_move(0, 0)).is_false()
	assert_int(r.moves()).is_equal(0)
	assert_array(r.board().to_tubes()).is_equal([[0, 1], [1], [0]])
	assert_bool(r.step(GameRound.encode_action(0, 1))).is_false()
	assert_int(r.moves()).is_equal(1)
	assert_array(r.board().to_tubes()).is_equal([[0], [1, 1], [0]])
	assert_bool(r.step(GameRound.encode_action(2, 1))).is_false()
	assert_int(r.moves()).is_equal(1)


func test_solution_path_wins_perfect() -> void:
	for level in [1, 2, 5, 10]:
		var data: Dictionary = ContentGenerator.new().generate(1, level)
		var r := GameRound.new()
		r.start(data)
		_play(r, data["payload"]["solution"])
		var res: Dictionary = r.result()
		assert_bool(r.is_done()).is_true()
		assert_bool(res["won"]).is_true()
		assert_int(res["moves"]).is_equal(r.min_moves())
		assert_bool(res["perfect"]).is_true()


func test_perfect_false_when_over_slack() -> void:
	var tubes: Array = [[0, 1, 0, 1], [1, 0, 1, 0], []]
	var board := SortBoard.new(tubes, 4)
	var sol: Dictionary = SortSolver.solve(board, 20000)
	var n: int = sol["moves"]
	assert_bool(n > 0).is_true()
	var slack: int = int(GameConfig.get_value("par_slack_moves"))
	var bad := _round_from_tubes(tubes, n - slack - 1)
	_play(bad, sol["path"])
	assert_bool(bad.result()["won"]).is_true()
	assert_bool(bad.result()["perfect"]).is_false()
	var ok := _round_from_tubes(tubes, n - slack)
	_play(ok, sol["path"])
	assert_bool(ok.result()["perfect"]).is_true()


func test_undo_restores_state_and_charges() -> void:
	var free: int = int(GameConfig.get_value("undo_free_per_level"))
	var r := _round_from_tubes([[0, 1], [1], []])
	assert_bool(r.undo()).is_false()
	r.try_move(0, 1)
	assert_bool(r.undo()).is_true()
	assert_array(r.board().to_tubes()).is_equal([[0, 1], [1], []])
	assert_int(r.moves()).is_equal(0)
	assert_int(r.result()["undos_used"]).is_equal(1)
	assert_int(r.undo_charges()).is_equal(free - 1)
	for i in free - 1:
		r.try_move(0, 1)
		assert_bool(r.undo()).is_true()
	r.try_move(0, 1)
	assert_bool(r.undo()).is_false()
	assert_int(r.moves()).is_equal(1)
	r.add_undo_charges(3)
	assert_int(r.result()["boosters_used"]).is_equal(1)
	assert_bool(r.undo()).is_true()


func test_restart_resets() -> void:
	var r := _round_from_tubes([[0, 1], [1], []])
	r.try_move(0, 1)
	r.add_extra_tube()
	r.restart()
	assert_array(r.board().to_tubes()).is_equal([[0, 1], [1], []])
	assert_int(r.moves()).is_equal(0)
	assert_int(r.undo_charges()).is_equal(int(GameConfig.get_value("undo_free_per_level")))
	assert_int(r.restarts()).is_equal(1)
	assert_bool(r.can_skip()).is_false()
	assert_bool(r.add_extra_tube()).is_true()
	for i in int(GameConfig.get_value("skip_unlock_restarts")) - 1:
		r.restart()
	assert_bool(r.can_skip()).is_true()


func test_extra_tube() -> void:
	var r := _round_from_tubes([[0, 0, 0, 1], [1, 1, 1, 0]])
	assert_bool(r.is_stuck()).is_true()
	assert_bool(r.add_extra_tube()).is_true()
	assert_int(r.board().tube_count()).is_equal(3)
	assert_bool(r.add_extra_tube()).is_false()
	assert_int(r.result()["boosters_used"]).is_equal(1)
	assert_bool(r.is_stuck()).is_false()
	r.try_move(0, 2)
	assert_bool(r.undo()).is_true()
	assert_int(r.board().tube_count()).is_equal(3)
	# prawie wygrana + dodatkowa probówka
	var w := _round_from_tubes([[0, 0, 0], [0]])
	w.add_extra_tube()
	assert_bool(w.step(GameRound.encode_action(1, 0))).is_true()
	assert_bool(w.result()["won"]).is_true()


func test_is_stuck() -> void:
	assert_bool(_round_from_tubes([[0, 1, 0, 1], [1, 0, 1, 0]]).is_stuck()).is_true()
	assert_bool(_round_from_tubes([[0, 1], [1], []]).is_stuck()).is_false()
	var w := _round_from_tubes([[0, 0, 0], [0]])
	w.try_move(1, 0)
	assert_bool(w.is_stuck()).is_false()


func test_hint_reduces_moves_to_goal() -> void:
	var checked: int = 0
	for level in range(2, 7):
		var data: Dictionary = ContentGenerator.new().generate(1, level)
		var sol: Array = data["payload"]["solution"]
		for k in [0, 1, 2, 3, sol.size() / 2, sol.size() - 2]:
			if k < 0 or k >= sol.size():
				continue
			var r := GameRound.new()
			r.start(data)
			_play(r, sol.slice(0, k))
			var before: int = r.moves_to_goal()
			if before <= 0:
				continue
			var h: Vector2i = r.hint()
			assert_bool(r.try_move(h.x, h.y)).is_true()
			assert_int(r.moves_to_goal()).is_equal(before - 1)
			checked += 1
	assert_bool(checked >= 20).is_true()


func test_hint_after_win_is_invalid() -> void:
	var w := _round_from_tubes([[0, 0, 0], [0]])
	w.try_move(1, 0)
	assert_that(w.hint()).is_equal(Vector2i(-1, -1))
	assert_bool(w.step(GameRound.encode_action(0, 1))).is_true()
	assert_int(w.moves()).is_equal(1)
	assert_int(w.moves_to_goal()).is_equal(0)


func test_result_keys() -> void:
	var res: Dictionary = _round_for(1).result()
	for k in ["won", "perfect", "min_moves_exact"]:
		assert_int(typeof(res[k])).is_equal(TYPE_BOOL)
	for k in ["moves", "min_moves", "undos_used", "boosters_used", "restarts", "steps"]:
		assert_int(typeof(res[k])).is_equal(TYPE_INT)


func test_config_keys_present() -> void:
	var want: Dictionary = {
		"undo_free_per_level": 3,
		"undo_refill_amount": 3,
		"extra_tube_max_per_level": 1,
		"skip_unlock_restarts": 2,
		"par_slack_moves": 2,
		"hint_solver_max_states": 20000,
	}
	for k: String in want:
		assert_bool(GameConfig.DEFAULTS.has(k)).is_true()
		assert_int(GameConfig.DEFAULTS[k]).is_equal(want[k])


func _three_moves_one_undo() -> GameRound:
	var r := _round_for(3)
	for i in 3:
		var m: Vector2i = r.board().legal_moves()[0]
		r.try_move(m.x, m.y)
	r.undo()
	return r


func _same_state(a: GameRound, b: GameRound) -> void:
	assert_array(b.board().tubes).is_equal(a.board().tubes)
	assert_int(b.moves()).is_equal(a.moves())
	assert_int(b.undo_charges()).is_equal(a.undo_charges())
	assert_dict(b.result()).is_equal(a.result())
	assert_int(b.min_moves()).is_equal(a.min_moves())


func test_to_from_dict_round_trip_then_undo() -> void:
	var r := _three_moves_one_undo()
	var c: GameRound = GameRound.from_dict(r.to_dict())
	assert_object(c).is_not_null()
	_same_state(r, c)
	assert_bool(c.undo()).is_true()
	assert_bool(r.undo()).is_true()
	_same_state(r, c)


func test_to_from_dict_keeps_extra_tube() -> void:
	var r := _three_moves_one_undo()
	assert_bool(r.add_extra_tube()).is_true()
	var c: GameRound = GameRound.from_dict(r.to_dict())
	assert_object(c).is_not_null()
	_same_state(r, c)
	assert_int(c.board().tube_count()).is_equal(r.board().tube_count())
	assert_bool(c.can_add_extra_tube()).is_equal(r.can_add_extra_tube())


func test_from_dict_json_round_trip() -> void:
	var r := _three_moves_one_undo()
	var parsed: Variant = JSON.parse_string(JSON.stringify(r.to_dict()))
	var c: GameRound = GameRound.from_dict(parsed)
	assert_object(c).is_not_null()
	_same_state(r, c)
	assert_bool(c.undo()).is_true()


func test_from_dict_corrupt_returns_null(
	field: String,
	value: Variant,
	test_parameters := [
		["level_data", "x"],
		["payload.tubes", "x"],
		["payload.capacity", "abc"],
		["capacity", 3],
		["tubes", "abc"],
		["tubes", [[99, 0, 0, 0]]],
		["tubes", [[0, 0, 0, 0, 0]]],
		["moves", 5],
		["history", "x"],
		["undo_charges", -1],
	]
) -> void:
	var d: Dictionary = _three_moves_one_undo().to_dict()
	if field.begins_with("payload."):
		d["level_data"]["payload"][field.substr(8)] = value
	else:
		d[field] = value
	assert_object(GameRound.from_dict(d)).is_null()
	assert_object(GameRound.from_dict({})).is_null()
	assert_that(test_parameters).is_not_null()


func test_elapsed_s_round_trips_and_is_in_result() -> void:
	var r := _round_for(3)
	r.elapsed_s = 12.5
	var c: GameRound = GameRound.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_float(c.elapsed_s).is_equal_approx(12.5, 0.001)
	assert_float(c.result()["elapsed_s"]).is_equal_approx(12.5, 0.001)


func test_elapsed_s_missing_negative_or_wrong_type_is_zero() -> void:
	var r := _round_for(3)
	var d: Dictionary = r.to_dict()
	d.erase("elapsed_s")
	assert_float(GameRound.from_dict(d).elapsed_s).is_zero()
	# Ujemna lub nie-liczba: runda nadal poprawna, czas 0 (jak brak klucza).
	for bad: Variant in [-3, "abc", null]:
		d["elapsed_s"] = bad
		var c: GameRound = GameRound.from_dict(d)
		assert_object(c).is_not_null()
		assert_float(c.elapsed_s).is_zero()


func test_restart_keeps_elapsed_start_resets() -> void:
	var r := _round_for(3)
	r.elapsed_s = 5.0
	r.restart()
	assert_float(r.elapsed_s).is_equal_approx(5.0, 0.001)
	r.start(r._level_data)
	assert_float(r.elapsed_s).is_zero()
