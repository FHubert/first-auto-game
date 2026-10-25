extends GdUnitTestSuite
## T-237: osobny budzet exact podpowiedzi (hint_exact_max_states) vs moves_to_goal().


func before_test() -> void:
	GameConfig.reset()


func after_test() -> void:
	GameConfig.reset()


func _play(r: GameRound, path: Array) -> void:
	for m: Vector2i in path:
		r.step(GameRound.encode_action(m.x, m.y))


func test_hint_leads_to_solution_on_t210_states() -> void:
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
			if r.moves_to_goal() <= 0:
				continue
			var h: Vector2i = r.hint()
			assert_bool(r.try_move(h.x, h.y)).is_true()
			assert_int(r.moves_to_goal()).is_greater_equal(0)
			checked += 1
	assert_bool(checked >= 20).is_true()


func test_moves_to_goal_independent_of_hint_exact_key() -> void:
	var data: Dictionary = ContentGenerator.new().generate(1, 6)
	var base := GameRound.new()
	base.start(data)
	var want: int = base.moves_to_goal()
	GameConfig.set_for_test("hint_exact_max_states", 250)
	var r := GameRound.new()
	r.start(data)
	assert_int(r.moves_to_goal()).is_equal(want)
	var h := GameRound.new()
	h.start(data)
	h.hint()
	assert_int(h.moves_to_goal()).is_equal(want)
	var key: String = SolverCache.key_of(h.board(), 250)
	h.solutions.put(key, 1, [Vector2i(0, 1)])
	assert_int(h.moves_to_goal()).is_equal(want)
