extends GdUnitTestSuite
## Rownowaznosc szybkiego klucza planszy (fast_key) ze starym kluczem tekstowym
## (canonical_key_string) oraz nowych wariantow legal_moves / clone_poured (T-134).

const PAIRS: int = 600
const CAPACITY: int = 4
const COLORS: int = 6


func _random_board(rng: RandomNumberGenerator) -> SortBoard:
	var tubes: Array = []
	for _i in COLORS + 2:
		var t: Array = []
		for _k in rng.randi_range(0, CAPACITY):
			t.append(rng.randi_range(0, COLORS - 1))
		tubes.append(t)
	return SortBoard.new(tubes, CAPACITY)


func _shuffled(b: SortBoard, rng: RandomNumberGenerator) -> SortBoard:
	var tubes: Array = b.to_tubes()
	for i in range(tubes.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Array = tubes[i]
		tubes[i] = tubes[j]
		tubes[j] = tmp
	return SortBoard.new(tubes, CAPACITY)


func _tweaked(b: SortBoard, rng: RandomNumberGenerator) -> SortBoard:
	var tubes: Array = b.to_tubes()
	var t: Array = tubes[rng.randi_range(0, tubes.size() - 1)]
	if t.is_empty():
		t.append(rng.randi_range(0, COLORS - 1))
	else:
		t[rng.randi_range(0, t.size() - 1)] = rng.randi_range(0, COLORS - 1)
	return SortBoard.new(tubes, CAPACITY)


func _assert_equivalent(a: SortBoard, b: SortBoard) -> bool:
	return (a.fast_key() == b.fast_key()) == (a.canonical_key_string() == b.canonical_key_string())


func test_fast_key_equivalent_to_string_key() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 134
	var equal_pairs: int = 0
	var different_pairs: int = 0
	for _n in PAIRS:
		var a: SortBoard = _random_board(rng)
		for b: SortBoard in [_shuffled(a, rng), _tweaked(a, rng), _random_board(rng)]:
			assert_bool(_assert_equivalent(a, b)).is_true()
			if a.canonical_key_string() == b.canonical_key_string():
				equal_pairs += 1
			else:
				different_pairs += 1
	assert_int(equal_pairs).is_greater_equal(PAIRS)
	assert_int(different_pairs).is_greater_equal(PAIRS)


func test_fast_key_works_as_dictionary_key() -> void:
	var a := SortBoard.new([[0, 1], [2], []], CAPACITY)
	var b := SortBoard.new([[], [2], [0, 1]], CAPACITY)
	var c := SortBoard.new([[0, 2], [1], []], CAPACITY)
	var seen: Dictionary = {a.fast_key(): 1}
	assert_bool(seen.has(b.fast_key())).is_true()
	assert_bool(seen.has(c.fast_key())).is_false()


func test_legal_moves_and_clone_poured_match_reference() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _n in 300:
		var b: SortBoard = _random_board(rng)
		var expected: Array[Vector2i] = []
		for f in b.tube_count():
			for t in b.tube_count():
				if b.can_pour(f, t):
					expected.append(Vector2i(f, t))
		var moves: Array[Vector2i] = b.legal_moves()
		assert_array(moves).is_equal(expected)
		for m in moves:
			var ref: SortBoard = b.clone()
			ref.pour(m.x, m.y)
			assert_array(b.clone_poured(m.x, m.y).tubes).is_equal(ref.tubes)
