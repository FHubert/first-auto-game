extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_hint_job.json"
const WAIT_FRAMES: int = 600

var _level: Level
var _old_path: String
var _release: bool = false
var _seen_cancel: SolverCancel
var _calls: int = 0


func before_test() -> void:
	GameConfig.reset()
	_release = false
	_seen_cancel = null
	_calls = 0
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)


func after_test() -> void:
	_release = true
	if is_instance_valid(_level):
		_level.free()
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _board_of(level_no: int) -> GameRound:
	var seed_value: int = int(GameConfig.get_value("campaign_seed"))
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(seed_value, level_no))
	return r


func _make_level() -> void:
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.state.coins = 500
	_level.state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	_level.clock = TestClock.fixed()
	_level.autoload_level = false
	add_child(_level)
	_level.size = Vector2(720, 1280)
	_level.hint_job.solve_fn = _held_solve
	_level.load_level(8)


## Solver trzymany do `_release` albo anulowania (bez Semaphore: cancel() nie moze sie zakleszczyc).
func _held_solve(board: SortBoard, limit: int, weight: float, cancel: SolverCancel) -> Dictionary:
	_calls += 1
	_seen_cancel = cancel
	while not _release and not cancel.cancelled:
		OS.delay_msec(1)
	return SortSolver.solve(board, limit, weight, cancel)


func _wait_job() -> void:
	for _i in WAIT_FRAMES:
		if not _level.hint_job.is_busy():
			return
		await get_tree().process_frame


func _first_move() -> Vector2i:
	return _level.round.board().legal_moves()[0]


func test_async_result_equals_sync_for_three_states() -> void:
	GameConfig.set_for_test("hint_solver_max_states", 2000)
	for level_no in [8, 26, 40]:
		var sync_round: GameRound = _board_of(level_no)
		var job := HintJob.new()
		job.request(sync_round.board(), 2000, float(GameConfig.get_value("solver_fallback_weight")))
		assert_str(job.key()).is_equal(SolverCache.key_of(sync_round.board()))
		var r: Dictionary = {}
		for _i in WAIT_FRAMES:
			r = job.poll()
			if not r.is_empty():
				break
			OS.delay_msec(5)
		assert_bool(job.is_busy()).is_false()
		assert_int(r["moves"]).is_equal(sync_round.moves_to_goal())
		var fed: GameRound = _board_of(level_no)
		fed.solutions.put(job.key(), r["moves"], r["path"])
		assert_bool(fed.solutions.has_key(job.key())).is_true()
		assert_that(fed.hint()).is_equal(sync_round.hint())
		assert_int(fed.moves_to_goal()).is_equal(sync_round.moves_to_goal())
		assert_bool(SortSolver.replay(sync_round.board(), r["path"])).is_true()


func test_hint_pending_then_move_discards_result() -> void:
	_make_level()
	var coins: int = _level.state.coins
	_level.hud.hint_pressed.emit()
	assert_bool(_level.hud.hint_button.disabled).is_true()
	assert_str(_level.hud.hint_button.text).is_equal("…")
	assert_int(_level.state.coins).is_equal(coins)
	var m: Vector2i = _first_move()
	assert_bool(_level.round.try_move(m.x, m.y)).is_true()
	_release = true
	await _wait_job()
	assert_bool(_level.hud.hint_button.disabled).is_false()
	assert_str(_level.hud.hint_button.text).is_equal(tr("btn_hint") % Economy.hint_cost())
	assert_int(_level.state.coins).is_equal(coins)
	assert_int(_level.round.result()["boosters_used"]).is_equal(0)
	assert_bool(_level.round.solutions.has_key(SolverCache.key_of(_level.round.board()))).is_false()


func test_hint_result_on_same_board_charges_coins_after_result() -> void:
	_make_level()
	var coins: int = _level.state.coins
	_level.hud.hint_pressed.emit()
	await get_tree().process_frame
	assert_int(_level.state.coins).is_equal(coins)
	_release = true
	await _wait_job()
	assert_int(_level.state.coins).is_equal(coins - Economy.hint_cost())
	assert_int(_level.round.result()["boosters_used"]).is_equal(1)
	assert_int(_level.board.selected_index()).is_not_equal(-1)
	assert_bool(_level.hud.hint_button.disabled).is_false()
	assert_int(_calls).is_equal(1)


func test_second_press_while_pending_is_ignored() -> void:
	_make_level()
	_level.hud.hint_pressed.emit()
	_level.hud.hint_pressed.emit()
	_release = true
	await _wait_job()
	assert_int(_calls).is_equal(1)
	assert_int(_level.state.coins).is_equal(500 - Economy.hint_cost())


func test_action_cancels_pending_hint_immediately() -> void:
	_make_level()
	_level.hud.hint_pressed.emit()
	await get_tree().process_frame
	_level.restart()
	assert_bool(_level.hint_job.is_busy()).is_false()
	assert_bool(_level.hud.hint_button.disabled).is_false()
	assert_bool(_seen_cancel.cancelled).is_true()
	assert_int(_level.state.coins).is_equal(500)


func test_leaving_level_cancels_job() -> void:
	_make_level()
	_level.hud.hint_pressed.emit()
	await get_tree().process_frame
	var job: HintJob = _level.hint_job
	_level.free()
	assert_bool(job.is_busy()).is_false()
	assert_bool(_seen_cancel.cancelled).is_true()
	assert_int(_calls).is_equal(1)


func test_solver_cancel_token() -> void:
	var board: SortBoard = _board_of(40).board()
	var token := SolverCancel.new()
	token.cancelled = true
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = SortSolver.solve(board, 20000, SortSolver.EXACT_WEIGHT, token)
	assert_int(r["moves"]).is_equal(SortSolver.NO_SOLUTION)
	assert_int(r["expanded"]).is_less_equal(256)
	assert_int(Time.get_ticks_msec() - t0).is_less(500)
	var plain: Dictionary = SortSolver.solve(board, 300, SortSolver.EXACT_WEIGHT)
	var open_token: Dictionary = SortSolver.solve(
		board, 300, SortSolver.EXACT_WEIGHT, SolverCancel.new()
	)
	assert_int(open_token["moves"]).is_equal(plain["moves"])
	assert_int(open_token["expanded"]).is_equal(plain["expanded"])


func test_stuck_board_solves_in_one_expansion() -> void:
	var payload: Dictionary = {
		"capacity": 4,
		"colors": 2,
		"tubes": [[0, 1, 0, 1], [1, 0, 1, 0]],
		"min_moves": 1,
		"min_moves_exact": true,
		"solution": [],
	}
	var r := GameRound.new()
	r.start({"seed": 1, "level": 1, "difficulty": 0.0, "payload": payload})
	assert_bool(r.is_stuck()).is_true()
	var t0: int = Time.get_ticks_msec()
	var res: Dictionary = SortSolver.solve(r.board(), 20000, SortSolver.EXACT_WEIGHT)
	assert_int(res["expanded"]).is_less_equal(2)
	assert_int(r.moves_to_goal()).is_equal(-1)
	assert_int(Time.get_ticks_msec() - t0).is_less(50)
