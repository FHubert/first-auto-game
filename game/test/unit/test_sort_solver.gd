extends GdUnitTestSuite
## Testy SortSolver. Pojemność 4, indeks 0 = dół probówki.
## Minima policzone BFS-em niezależnym od solvera.

const BIG_LIMIT: int = 20000
const TINY_LIMIT: int = 5
const WEIGHTED: float = 3.0


func _check(tubes: Array, cap: int, expected: int) -> void:
	var b := SortBoard.new(tubes, cap)
	var r: Dictionary = SortSolver.solve(b, BIG_LIMIT)
	assert_int(r["moves"]).is_equal(expected)
	assert_bool(r["exact"]).is_true()
	assert_int((r["path"] as Array).size()).is_equal(expected)
	assert_bool(SortSolver.replay(b, r["path"])).is_true()
	assert_bool(r["expanded"] <= BIG_LIMIT).is_true()


func test_already_won() -> void:
	var r: Dictionary = SortSolver.solve(SortBoard.new([[0, 0, 0, 0], []]), BIG_LIMIT)
	assert_int(r["moves"]).is_equal(0)
	assert_array(r["path"]).is_empty()
	assert_bool(r["exact"]).is_true()


func test_one_move() -> void:
	_check([[0, 0, 0], [0], []], 4, 1)


func test_two_moves() -> void:
	# 0->1 (scala 1 do [1,1,1]), potem 2->0 ([0] na [0,0,0]). Jeden ruch nie wystarcza.
	_check([[0, 0, 0, 1], [1, 1, 1], [0]], 4, 2)


func test_four_moves() -> void:
	# Minimum 4 potwierdzone BFS-em.
	_check([[0, 1, 1, 0], [0, 0, 1, 1], []], 4, 4)


func test_unsolvable() -> void:
	var r: Dictionary = SortSolver.solve(SortBoard.new([[0, 1], [1, 0]], 2), BIG_LIMIT)
	assert_int(r["moves"]).is_equal(-1)
	assert_bool(r["exact"]).is_true()
	assert_array(r["path"]).is_empty()


func test_limit_reached() -> void:
	var tubes: Array = _scrambled(6)
	var r: Dictionary = SortSolver.solve(SortBoard.new(tubes, 4), TINY_LIMIT)
	assert_int(r["moves"]).is_equal(-1)
	assert_bool(r["exact"]).is_false()
	assert_bool(r["expanded"] <= TINY_LIMIT).is_true()


func test_heuristic_cases() -> void:
	assert_int(SortSolver.heuristic(SortBoard.new([[0, 0, 1, 1]]))).is_equal(1)
	assert_int(SortSolver.heuristic(SortBoard.new([[0, 1, 0, 1], [2, 2], []]))).is_equal(3)
	assert_int(SortSolver.heuristic(SortBoard.new([[0, 0, 0, 0], [], [1]]))).is_equal(0)


func test_weighted_is_not_exact() -> void:
	var b := SortBoard.new([[0, 0, 0, 1], [1, 1, 1], [0]])
	var r: Dictionary = SortSolver.solve(b, BIG_LIMIT, WEIGHTED)
	assert_bool(r["moves"] >= 2).is_true()
	assert_bool(r["exact"]).is_false()
	assert_bool(SortSolver.replay(b, r["path"])).is_true()


func test_deterministic() -> void:
	var b := SortBoard.new([[0, 1, 1, 0], [0, 0, 1, 1], []])
	var a: Dictionary = SortSolver.solve(b, BIG_LIMIT)
	var c: Dictionary = SortSolver.solve(b, BIG_LIMIT)
	assert_array(a["path"]).is_equal(c["path"])


func test_sanity_five_colors() -> void:
	var b := SortBoard.new(_scrambled(5), 4)
	var r: Dictionary = SortSolver.solve(b, BIG_LIMIT)
	print("SANITY expanded=%d moves=%d" % [r["expanded"], r["moves"]])
	assert_bool(r["moves"] > 0).is_true()
	assert_bool(SortSolver.replay(b, r["path"])).is_true()


## Pomieszana plansza: n kolorów x 4, rozłożone przesunięciem, + 2 puste probówki.
func _scrambled(colors: int) -> Array:
	var tubes: Array = []
	for i in colors:
		var t: Array = []
		for k in 4:
			t.append((i + k * 2 + (k / 2)) % colors)
		tubes.append(t)
	tubes.append([])
	tubes.append([])
	return tubes
