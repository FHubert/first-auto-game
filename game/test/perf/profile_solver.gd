extends SceneTree
## Profil hot-spotow SortSolver.solve (T-134). Reczny, poza `make test`:
##   cd game && ../.tools/godot --headless --path . --script res://test/perf/profile_solver.gd
## Metoda: instrumentowana kopia petli solve (Time.get_ticks_usec wokol kazdej operacji,
## narzut pomiaru odjety wg kalibracji) na planszach poziomow 1..200 i Poziomu dnia
## 20750..20759, budzety jak w generatorze. 3 przebiegi -> mediana udzialow %.
## Drugi pomiar: czas nieinstrumentowanego SortSolver.solve i ContentGenerator.generate 1..200.

const OPS: Array = ["legal_moves", "clone", "pour", "key", "heuristic", "best_g", "push", "pop"]
const RUNS: int = 3


func _initialize() -> void:
	var boards: Array = []
	# load() w runtime: autoloady (GameConfig) istnieja dopiero po kompilacji tego skryptu.
	var gen: RefCounted = load("res://src/systems/content_generator.gd").new()
	var t0: int = Time.get_ticks_usec()
	for lv in range(1, 201):
		boards.append(gen.generate(1, lv))
	var gen_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	for day in range(20750, 20760):
		boards.append(gen.generate_daily(day))
	var runs: Array = []
	var plain: Array = []
	for _r in RUNS:
		var acc: Dictionary = {}
		for op in OPS:
			acc[op] = 0
		acc["total"] = 0
		var p0: int = Time.get_ticks_usec()
		for d in boards:
			_solve_all(SortBoard.from_payload(d["payload"]), d["payload"], acc, false)
		plain.append(Time.get_ticks_usec() - p0)
		acc = acc.duplicate()
		for op in OPS:
			acc[op] = 0
		for d in boards:
			_solve_all(SortBoard.from_payload(d["payload"]), d["payload"], acc, true)
		runs.append(acc)
	print("PROFIL (mediana udzialow %% z %d przebiegow, narzut timera wliczony)" % RUNS)
	var sum_pct: float = 0.0
	for op in OPS:
		var shares: Array = []
		for acc in runs:
			shares.append(100.0 * float(acc[op]) / float(acc["total"]))
		shares.sort()
		sum_pct += float(shares[1])
		print("  %-12s %5.1f %%" % [op, shares[1]])
	print("  %-12s %5.1f %%" % ["inne (reszta)", 100.0 - sum_pct])
	plain.sort()
	print("solve bez instrumentacji (mediana): %.1f ms" % (float(plain[1]) / 1000.0))
	print("generate 1..200 (1 przebieg): %.1f ms (%.2f ms/poziom)" % [gen_ms, gen_ms / 200.0])
	quit()


func _solve_all(board: SortBoard, payload: Dictionary, acc: Dictionary, timed: bool) -> void:
	var max_states: int = int(_cfg("solver_max_states"))
	var weight: float = float(_cfg("solver_fallback_weight"))
	var exact_budget: int = int(_cfg("gen_exact_state_budget"))
	var res: Dictionary = {"moves": -1, "exact": false}
	if int(payload["colors"]) <= int(_cfg("gen_exact_max_colors")):
		res = _solve(board, mini(max_states, exact_budget), 1.0, acc, timed)
	if int(res["moves"]) == -1 and not res["exact"]:
		_solve(board, max_states, weight, acc, timed)


## Kopia SortSolver.solve z licznikami czasu; ta sama kolejnosc operacji.
func _solve(
	b0: SortBoard, max_states: int, weight: float, acc: Dictionary, timed: bool
) -> Dictionary:
	if not timed:
		return SortSolver.solve(b0, max_states, weight)
	var t_all: int = Time.get_ticks_usec()
	var n_ops: int = 0
	var t: int = 0
	var heap: Array = []
	var best_g: Dictionary = {}
	var start_key: Variant = b0.canonical_key()
	best_g[start_key] = 0
	SortSolver._push(
		heap,
		SortSolver._node(0, SortSolver.heuristic(b0), b0, null, Vector2i.ZERO, start_key, weight)
	)
	var expanded: int = 0
	var res: Dictionary = {"moves": -1, "exact": true}
	while not heap.is_empty():
		t = Time.get_ticks_usec()
		var node: Array = SortSolver._pop(heap)
		_add(acc, "pop", t)
		n_ops += 1
		var key: Variant = node[SortSolver.N_KEY]
		var g: int = node[SortSolver.N_G]
		if g > int(best_g.get(key, g)):
			continue
		var cur: SortBoard = node[SortSolver.N_BOARD]
		if cur.is_won():
			res = {"moves": g, "exact": true}
			break
		if expanded >= max_states:
			res = {"moves": -1, "exact": false}
			break
		expanded += 1
		t = Time.get_ticks_usec()
		var moves: Array[Vector2i] = cur.legal_moves()
		_add(acc, "legal_moves", t)
		for m in moves:
			t = Time.get_ticks_usec()
			var nb: SortBoard = cur.clone()
			_add(acc, "clone", t)
			t = Time.get_ticks_usec()
			nb.pour(m.x, m.y)
			_add(acc, "pour", t)
			t = Time.get_ticks_usec()
			var nk: Variant = nb.canonical_key()
			_add(acc, "key", t)
			var ng: int = g + 1
			t = Time.get_ticks_usec()
			var skip: bool = best_g.has(nk) and int(best_g[nk]) <= ng
			if not skip:
				best_g[nk] = ng
			_add(acc, "best_g", t)
			if skip:
				continue
			t = Time.get_ticks_usec()
			var h: int = SortSolver.heuristic(nb)
			_add(acc, "heuristic", t)
			t = Time.get_ticks_usec()
			SortSolver._push(heap, SortSolver._node(ng, h, nb, node, m, nk, weight))
			_add(acc, "push", t)
		node[SortSolver.N_BOARD] = null
	acc["total"] += Time.get_ticks_usec() - t_all
	return res


func _add(acc: Dictionary, op: String, t_start: int) -> void:
	acc[op] += maxi(0, Time.get_ticks_usec() - t_start)


func _cfg(key: String) -> Variant:
	return root.get_node("GameConfig").get_value(key)
