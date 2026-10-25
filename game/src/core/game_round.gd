# gdlint: ignore=max-public-methods
class_name GameRound
extends RefCounted
## Runda water sort: ruchy, cofnij, dodatkowa probówka, restart, podpowiedź.
## Kontrakt dla bota/UI: start(level_data) / step(action) / result().
## action = from * ACTION_BASE + to.

## Limit 16 probówek (action = from*16 + to); suma colors_max + empty_tubes +
## extra_tube_max_per_level musi się mieścić (pilnuje test_game_round).
const ACTION_BASE: int = 16
const NO_HINT: Vector2i = Vector2i(-1, -1)

## Aktywny czas rundy w sekundach, sumowany przez wznowienia; aktualizowany przez Level.
var elapsed_s: float = 0.0
var _level_data: Dictionary = {}
var _start_tubes: Array = []
var _board: SortBoard = SortBoard.new()
var _history: Array = []
var _moves: int = 0
var _undo_charges: int = 0
var _undos_used: int = 0
var _extra_tubes_added: int = 0
var _boosters_used: int = 0
var _restarts: int = 0
var _done: bool = false
var _won: bool = false
var _min_moves: int = 0
var _min_moves_exact: bool = false
var _solver_cache: Dictionary = {}


static func encode_action(from: int, to: int) -> int:
	return from * ACTION_BASE + to


static func decode_action(action: int) -> Vector2i:
	return Vector2i(action / ACTION_BASE, action % ACTION_BASE)


func start(level_data: Dictionary) -> void:
	_level_data = level_data
	var payload: Dictionary = level_data.get("payload", {})
	_board = SortBoard.from_payload(payload)
	_start_tubes = _board.to_tubes()
	var mm: Variant = GameState._as_int(payload.get("min_moves"))
	_min_moves = 0 if mm == null else int(mm)
	_min_moves_exact = bool(payload.get("min_moves_exact", false))
	_history = []
	_moves = 0
	_undos_used = 0
	_boosters_used = 0
	_restarts = 0
	elapsed_s = 0.0
	_extra_tubes_added = 0
	_undo_charges = _cfg_int("undo_free_per_level")
	_solver_cache = {}
	_done = _board.is_won()
	_won = _done


func to_dict() -> Dictionary:
	return {
		"level_data": _level_data.duplicate(true),
		"tubes": _board.to_tubes(),
		"capacity": _board.capacity,
		"history": _history.duplicate(true),
		"moves": _moves,
		"undo_charges": _undo_charges,
		"undos_used": _undos_used,
		"extra_tubes_added": _extra_tubes_added,
		"boosters_used": _boosters_used,
		"restarts": _restarts,
		"elapsed_s": elapsed_s,
	}


## Odtwarza rundę z to_dict() (także po JSON); null przy KAŻDEJ niespójności.
static func from_dict(d: Dictionary) -> GameRound:
	var ld: Variant = d.get("level_data")
	if typeof(ld) != TYPE_DICTIONARY or not _valid_payload((ld as Dictionary).get("payload")):
		return null
	var r := GameRound.new()
	r.start((ld as Dictionary).duplicate(true))
	var cap: Variant = GameState._as_int(d.get("capacity"))
	var extra: Variant = GameState._as_int(d.get("extra_tubes_added", 0))
	var moves: Variant = GameState._as_int(d.get("moves"))
	var hist: Variant = d.get("history")
	if cap == null or extra == null or moves == null or typeof(hist) != TYPE_ARRAY:
		return null
	if int(cap) != r._board.capacity or int(cap) < 1:
		return null
	if int(extra) < 0 or int(extra) > r._cfg_int("extra_tube_max_per_level"):
		return null
	if int(moves) != (hist as Array).size():
		return null
	var count: int = r._start_tubes.size() + int(extra)
	var want: Dictionary = _color_counts(r._start_tubes)
	var snaps: Array = (hist as Array).duplicate()
	snaps.append(d.get("tubes"))
	for snap: Variant in snaps:
		if not _valid_tubes(snap, int(cap), count, want):
			return null
	var ints: Array = []
	for key: String in ["undo_charges", "undos_used", "boosters_used", "restarts"]:
		var fallback: Variant = r._undo_charges if key == "undo_charges" else 0
		var v: Variant = GameState._as_int(d.get(key, fallback))
		if v == null or int(v) < 0:
			return null
		ints.append(int(v))
	r._start_tubes = _norm(r._start_tubes)
	r._board = SortBoard.new(_norm(snaps.pop_back()), int(cap))
	r._history = snaps.map(_norm)
	r._moves = int(moves)
	r._extra_tubes_added = int(extra)
	r._undo_charges = ints[0]
	r._undos_used = ints[1]
	r._boosters_used = ints[2]
	r._restarts = ints[3]
	var el: Variant = d.get("elapsed_s")
	if typeof(el) == TYPE_FLOAT or typeof(el) == TYPE_INT:
		r.elapsed_s = maxf(0.0, float(el))
	r._done = r._board.is_won()
	r._won = r._done
	return r


## Payload bezpieczny dla SortBoard.from_payload (typy tubes/capacity).
static func _valid_payload(p: Variant) -> bool:
	if typeof(p) != TYPE_DICTIONARY or typeof(p.get("tubes")) != TYPE_ARRAY:
		return false
	for t: Variant in p["tubes"]:
		if typeof(t) != TYPE_ARRAY:
			return false
		for c: Variant in t:
			var v: Variant = GameState._as_int(c)
			if v == null or int(v) < 0:
				return false
	if p.has("min_moves") and GameState._as_int(p["min_moves"]) == null:
		return false
	if p.has("capacity"):
		var cap: Variant = GameState._as_int(p["capacity"])
		return cap != null and int(cap) >= 1
	return true


static func _norm(tubes: Array) -> Array:
	var out: Array = []
	for t: Array in tubes:
		out.append(t.map(func(c: Variant) -> int: return int(c)))
	return out


static func _color_counts(tubes: Array) -> Dictionary:
	var out: Dictionary = {}
	for t: Array in tubes:
		for c: Variant in t:
			out[int(c)] = int(out.get(int(c), 0)) + 1
	return out


## Kształt, pojemność, liczba probówek i zachowanie masy każdego koloru.
static func _valid_tubes(tubes: Variant, cap: int, count: int, want: Dictionary) -> bool:
	if typeof(tubes) != TYPE_ARRAY or (tubes as Array).size() != count:
		return false
	var norm: Array = []
	for t: Variant in tubes:
		if typeof(t) != TYPE_ARRAY or (t as Array).size() > cap:
			return false
		var row: Array = []
		for c: Variant in t:
			var v: Variant = GameState._as_int(c)
			if v == null or int(v) < 0 or not want.has(int(v)):
				return false
			row.append(int(v))
		norm.append(row)
	return _color_counts(norm) == want and SortBoard.new(norm, cap).is_valid()


## Zwraca true gdy runda skończona.
func step(action: int) -> bool:
	var m: Vector2i = decode_action(action)
	try_move(m.x, m.y)
	return _done


## True gdy ruch był legalny i został wykonany.
func try_move(from: int, to: int) -> bool:
	if _done or not _board.can_pour(from, to):
		return false
	_history.append(_board.to_tubes())
	_board.pour(from, to)
	_moves += 1
	if _board.is_won():
		_done = true
		_won = true
	return true


func undo() -> bool:
	if _done or _history.is_empty() or _undo_charges <= 0:
		return false
	_board = SortBoard.new(_history.pop_back(), _board.capacity)
	_moves -= 1
	_undo_charges -= 1
	_undos_used += 1
	return true


func add_undo_charges(n: int) -> void:
	if n <= 0:
		return
	_undo_charges += n
	_boosters_used += 1


func undo_charges() -> int:
	return _undo_charges


func add_extra_tube() -> bool:
	if not can_add_extra_tube():
		return false
	_board.add_empty_tube()
	for snap: Array in _history:
		snap.append([])
	_extra_tubes_added += 1
	_boosters_used += 1
	return true


func restart() -> void:
	_board = SortBoard.new(_start_tubes, _board.capacity)
	_history = []
	_moves = 0
	_undo_charges = _cfg_int("undo_free_per_level")
	_extra_tubes_added = 0
	_done = _board.is_won()
	_won = _done
	_restarts += 1


func can_add_extra_tube() -> bool:
	return not _done and _extra_tubes_added < _cfg_int("extra_tube_max_per_level")


func restarts() -> int:
	return _restarts


func extra_tubes_added() -> int:
	return _extra_tubes_added


func can_skip() -> bool:
	return _restarts >= _cfg_int("skip_unlock_restarts")


func is_stuck() -> bool:
	return not _done and _board.legal_moves().is_empty()


## Pierwszy ruch solvera lub (-1, -1) gdy brak.
func hint() -> Vector2i:
	if _done:
		return NO_HINT
	var path: Array = _solve_cached().get("path", [])
	if path.is_empty():
		return NO_HINT
	_boosters_used += 1
	return path[0]


## Ruchy do celu wg solvera; 0 = wygrane, -1 = brak rozwiązania/limit.
func moves_to_goal() -> int:
	if _done:
		return 0
	return int(_solve_cached().get("moves", -1))


func min_moves() -> int:
	return _min_moves


func moves() -> int:
	return _moves


func board() -> SortBoard:
	return _board


func is_done() -> bool:
	return _done


func result() -> Dictionary:
	var slack: int = _cfg_int("par_slack_moves")
	return {
		"won": _won,
		"moves": _moves,
		"min_moves": _min_moves,
		"min_moves_exact": _min_moves_exact,
		"perfect": _won and _moves <= _min_moves + slack,
		"undos_used": _undos_used,
		"boosters_used": _boosters_used,
		"restarts": _restarts,
		"elapsed_s": elapsed_s,
		"steps": _moves,
	}


# Klucz = dokładny układ probówek (nie canonical_key): ścieżka zawiera indeksy probówek.
func _solve_cached() -> Dictionary:
	var key: String = str(_board.tubes)
	if _solver_cache.has(key):
		return _solver_cache[key]
	var limit: int = _cfg_int("hint_solver_max_states")
	var r: Dictionary = SortSolver.solve(_board, limit, SortSolver.EXACT_WEIGHT)
	if int(r["moves"]) <= 0 and not _board.is_won():
		var w: float = float(GameConfig.get_value("solver_fallback_weight"))
		r = SortSolver.solve(_board, limit, w)
	var out: Dictionary = {"moves": int(r["moves"]), "path": r["path"]}
	_solver_cache[key] = out
	return out


func _cfg_int(key: String) -> int:
	return int(GameConfig.get_value(key, 0))
