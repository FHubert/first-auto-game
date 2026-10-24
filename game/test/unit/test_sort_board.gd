extends GdUnitTestSuite
## Testy SortBoard. Plansza w testach: pojemność 4, indeks 0 = dół probówki.


func test_pour_table() -> void:
	# [nazwa, plansza, from, to, oczekiwany wynik, stan po]
	var cases: Array = [
		["mieszana do pustej", [[0, 1, 1], []], 0, 1, true, [[0], [1, 1]]],
		["ten sam kolor", [[0, 1], [2, 1]], 0, 1, true, [[0], [2, 1, 1]]],
		["inny kolor", [[0, 1], [1, 2]], 0, 1, false, [[0, 1], [1, 2]]],
		["cel pelny", [[0, 1], [2, 2, 1, 1]], 0, 1, false, [[0, 1], [2, 2, 1, 1]]],
		["czesciowy przelew", [[0, 1, 1, 1], [2, 2, 1]], 0, 1, true, [[0, 1, 1], [2, 2, 1, 1]]],
		["from == to", [[0, 1], []], 0, 0, false, [[0, 1], []]],
		["zrodlo puste", [[], [0]], 0, 1, false, [[], [0]]],
		["uniform do pustej (no-op)", [[0, 0], []], 0, 1, false, [[0, 0], []]],
		["uniform niepelna scala", [[1, 1], [0, 1]], 0, 1, true, [[], [0, 1, 1, 1]]],
		["rozwiazana jako zrodlo", [[1, 1, 1, 1], [1]], 0, 1, false, [[1, 1, 1, 1], [1]]],
		["indeks poza zakresem", [[0, 1], []], 0, 5, false, [[0, 1], []]],
		["indeks ujemny", [[0, 1], []], -1, 1, false, [[0, 1], []]],
	]
	for c in cases:
		var b := SortBoard.new(c[1])
		var ok: bool = b.pour(c[2], c[3])
		assert_bool(ok).override_failure_message("wynik: %s" % c[0]).is_equal(c[4])
		assert_array(b.to_tubes()).override_failure_message("stan: %s" % c[0]).is_equal(c[5])


func test_last_pour_amount() -> void:
	var b := SortBoard.new([[0, 1, 1, 1], [2, 2, 1]])
	assert_bool(b.pour(0, 1)).is_true()
	assert_int(b.last_pour_amount).is_equal(1)
	assert_bool(b.pour(0, 1)).is_false()
	assert_int(b.last_pour_amount).is_equal(0)


func test_is_won_solved() -> void:
	assert_bool(SortBoard.new([[0, 0, 0, 0], [1, 1, 1, 1], []]).is_won()).is_true()


func test_is_won_two_plus_two_monochrome_is_not_won() -> void:
	assert_bool(SortBoard.new([[0, 0], [0, 0], []]).is_won()).is_false()


func test_is_won_mixed_is_not_won() -> void:
	assert_bool(SortBoard.new([[0, 1, 0, 1], [1, 0, 1, 0]]).is_won()).is_false()


func test_is_won_empty_board_is_trivially_won() -> void:
	assert_bool(SortBoard.new([]).is_won()).is_true()


func test_legal_moves_exact_list() -> void:
	# 0->1 i 1->0 scalaja kolor 1, 0->2 mieszana do pustej; 1->2 to no-op (wykluczony)
	var b := SortBoard.new([[0, 1], [1], []])
	assert_array(b.legal_moves()).contains_exactly([Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0)])


func test_legal_moves_exclude_noops() -> void:
	var b := SortBoard.new([[0, 0], [], [1, 1, 1, 1]])
	assert_array(b.legal_moves()).is_empty()


func test_canonical_key_permutation_invariant() -> void:
	var a := SortBoard.new([[0, 1], [2], []])
	var b := SortBoard.new([[], [0, 1], [2]])
	assert_str(a.canonical_key()).is_equal(b.canonical_key())


func test_canonical_key_differs_for_other_state() -> void:
	var a := SortBoard.new([[0, 1], [2], []])
	var b := SortBoard.new([[1, 0], [2], []])
	assert_str(a.canonical_key()).is_not_equal(b.canonical_key())


func test_clone_is_independent() -> void:
	var a := SortBoard.new([[0, 1], []])
	var b: SortBoard = a.clone()
	assert_bool(b.pour(0, 1)).is_true()
	assert_array(a.to_tubes()).is_equal([[0, 1], []])
	assert_array(b.to_tubes()).is_equal([[0], [1]])


func test_from_payload_round_trip() -> void:
	var payload: Dictionary = {"capacity": 3, "tubes": [[0, 1], [1, 0], []]}
	var b := SortBoard.from_payload(payload)
	assert_int(b.capacity).is_equal(3)
	assert_array(b.to_tubes()).is_equal([[0, 1], [1, 0], []])
	b.pour(0, 2)
	assert_array(payload["tubes"]).is_equal([[0, 1], [1, 0], []])


func test_helpers() -> void:
	var b := SortBoard.new([[0, 1, 1], [], [2, 2, 2, 2]])
	assert_int(b.tube_count()).is_equal(3)
	assert_int(b.top_color(0)).is_equal(1)
	assert_int(b.top_color(1)).is_equal(-1)
	assert_int(b.top_run(0)).is_equal(2)
	assert_int(b.top_run(1)).is_equal(0)
	assert_int(b.free_space(0)).is_equal(1)
	assert_bool(b.is_uniform(0)).is_false()
	assert_bool(b.is_uniform(1)).is_false()
	assert_bool(b.is_full(2)).is_true()
	assert_int(b.color_count()).is_equal(3)
	assert_bool(b.is_valid()).is_true()
	assert_bool(SortBoard.new([[0, 0, 0, 0, 0]]).is_valid()).is_false()
	assert_bool(SortBoard.new([[-1]]).is_valid()).is_false()


func test_add_empty_tube_appends_empty_and_keeps_won_state() -> void:
	for tubes: Array in [[[0, 0, 0, 0], [1, 1, 1, 1]], [[0, 1], [1, 0]]]:
		var b := SortBoard.new(tubes)
		var won: bool = b.is_won()
		var n: int = b.tube_count()
		b.add_empty_tube()
		assert_int(b.tube_count()).is_equal(n + 1)
		assert_bool(b.is_empty(n)).is_true()
		assert_bool(b.is_won()).is_equal(won)
