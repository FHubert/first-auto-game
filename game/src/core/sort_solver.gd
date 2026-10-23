class_name SortSolver
extends RefCounted
## Solver water sort: A* z heurystyką granic kolorów i limitem rozwijanych stanów.
## Czysta logika (bez Node). Wynik: {moves, path, exact, expanded}.

const NO_SOLUTION: int = -1
const EXACT_WEIGHT: float = 1.0
# Indeksy pól węzła kolejki (Array, żeby uniknąć kosztu Dictionary w gorącej pętli).
const N_F: int = 0
const N_H: int = 1
const N_G: int = 2
const N_BOARD: int = 3
const N_PATH: int = 4
const N_KEY: int = 5


## Szuka najkrótszego (weight == 1.0) lub szybkiego (weight > 1.0) rozwiązania.
## `moves` = -1 gdy brak rozwiązania; wtedy `exact` = true oznacza dowód braku
## rozwiązania, a `exact` = false przerwanie na limicie `max_states`.
## `expanded` = liczba rozwiniętych stanów (zawsze <= max_states).
## `path` = ruchy (from, to) od stanu startowego do wygranej.
static func solve(board: SortBoard, max_states: int, weight: float = EXACT_WEIGHT) -> Dictionary:
	var exact_mode: bool = is_equal_approx(weight, EXACT_WEIGHT)
	if board.is_won():
		var none: Array[Vector2i] = []
		return _result(0, none, true, 0)

	var heap: Array = []
	var best_g: Dictionary = {}
	var start_h: int = heuristic(board)
	var start_key: String = board.canonical_key()
	best_g[start_key] = 0
	_push(heap, _node(0, start_h, board, [] as Array[Vector2i], start_key, weight))
	var expanded: int = 0

	while not heap.is_empty():
		var node: Array = _pop(heap)
		var key: String = node[N_KEY]
		var g: int = node[N_G]
		if g > int(best_g.get(key, g)):
			continue  # nieaktualny wpis (znaleziono lepsze g)
		var cur: SortBoard = node[N_BOARD]
		var cur_path: Array[Vector2i] = node[N_PATH]
		if cur.is_won():
			return _result(g, cur_path, exact_mode, expanded)
		if expanded >= max_states:
			var empty: Array[Vector2i] = []
			return _result(NO_SOLUTION, empty, false, expanded)
		expanded += 1
		for m in cur.legal_moves():
			var nb: SortBoard = cur.clone()
			nb.pour(m.x, m.y)
			var nk: String = nb.canonical_key()
			var ng: int = g + 1
			if best_g.has(nk) and int(best_g[nk]) <= ng:
				continue
			best_g[nk] = ng
			var np: Array[Vector2i] = cur_path.duplicate()
			np.append(m)
			_push(heap, _node(ng, heuristic(nb), nb, np, nk, weight))

	var no_path: Array[Vector2i] = []
	return _result(NO_SOLUTION, no_path, true, expanded)


## Heurystyka: suma po probówkach liczby granic kolorów (sąsiednich par o różnym
## kolorze). `[0,0,1,1]` -> 1, `[0,1,0,1]` -> 3, pusta/jednokolorowa -> 0.
## Dopuszczalna dla weight = 1: jeden przelew usuwa co najwyżej jedną granicę
## (przenosi całą górną serię), więc h <= prawdziwy koszt i wynik jest optymalny.
## Nie liczy rozdzielonych niepełnych probówek jednokolorowych (2+2) - nadal h <= koszt.
static func heuristic(board: SortBoard) -> int:
	var total: int = 0
	for t in board.tubes:
		for k in range(1, (t as Array).size()):
			if int(t[k]) != int(t[k - 1]):
				total += 1
	return total


## Odtwarza ścieżkę na klonie planszy. True tylko gdy każdy przelew jest legalny
## i stan końcowy jest wygrany.
static func replay(board: SortBoard, path: Array[Vector2i]) -> bool:
	var b: SortBoard = board.clone()
	for m in path:
		if not b.pour(m.x, m.y):
			return false
	return b.is_won()


static func _result(moves: int, path: Array[Vector2i], exact: bool, expanded: int) -> Dictionary:
	return {"moves": moves, "path": path, "exact": exact, "expanded": expanded}


static func _node(
	g: int, h: int, b: SortBoard, path: Array[Vector2i], key: String, weight: float
) -> Array:
	return [float(g) + weight * float(h), h, g, b, path, key]


## Węzeł a lepszy od b: mniejsze f, przy remisie mniejsze h.
static func _less(a: Array, b: Array) -> bool:
	if a[N_F] != b[N_F]:
		return a[N_F] < b[N_F]
	return a[N_H] < b[N_H]


static func _push(heap: Array, node: Array) -> void:
	heap.append(node)
	var i: int = heap.size() - 1
	while i > 0:
		var p: int = (i - 1) / 2
		if not _less(heap[i], heap[p]):
			break
		var tmp: Array = heap[i]
		heap[i] = heap[p]
		heap[p] = tmp
		i = p


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i: int = 0
		var n: int = heap.size()
		while true:
			var l: int = 2 * i + 1
			var r: int = l + 1
			var s: int = i
			if l < n and _less(heap[l], heap[s]):
				s = l
			if r < n and _less(heap[r], heap[s]):
				s = r
			if s == i:
				break
			var tmp: Array = heap[i]
			heap[i] = heap[s]
			heap[s] = tmp
			i = s
	return top
