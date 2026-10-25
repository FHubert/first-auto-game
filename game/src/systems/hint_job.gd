class_name HintJob
extends RefCounted
## Podpowiedz liczona w tle na WorkerThreadPool (ADR-014, uzupelnia ADR-011).
## Watek robi dokladnie to samo co GameRound._solve_cached (exact, a przy braku wyniku
## przebieg wazony), na KLONIE planszy zrobionym na watku glownym - wynik jest identyczny.
## `_result` pisze wylacznie watek roboczy; czytany dopiero po zakonczeniu zadania
## (is_task_completed / wait_for_task_completion daja happens-before), wiec bez Mutexu.

## Testy: podmiana solvera (Callable(board, limit, weight, cancel) -> Dictionary).
var solve_fn: Callable = _real_solve

var _task_id: int = -1
var _key: String = ""
var _board: SortBoard
var _limit: int = 0
var _weight: float = 1.0
var _cancel: SolverCancel
var _result: Dictionary = {}


func request(board: SortBoard, limit: int, fallback_weight: float) -> void:
	cancel()
	_board = board.clone()
	_key = SolverCache.key_of(board, limit)
	_limit = limit
	_weight = fallback_weight
	_cancel = SolverCancel.new()
	_task_id = WorkerThreadPool.add_task(_work, false, "HintJob")


func is_busy() -> bool:
	return _task_id != -1


## Klucz cache (SolverCache.key_of: plansza + limit) z chwili zadania.
func key() -> String:
	return _key


## {} dopoki liczy (albo brak zadania); potem {moves, path} jednorazowo.
func poll() -> Dictionary:
	if _task_id == -1 or not WorkerThreadPool.is_task_completed(_task_id):
		return {}
	WorkerThreadPool.wait_for_task_completion(_task_id)
	var out: Dictionary = _result
	_reset()
	return out


## Anuluje i czeka na koniec (solver sprawdza flage co kilkaset rozwiniec, ~30 ms).
func cancel() -> void:
	if _task_id == -1:
		return
	_cancel.cancelled = true
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_reset()


func _work() -> void:
	var r: Dictionary = solve_fn.call(_board, _limit, SortSolver.EXACT_WEIGHT, _cancel)
	if int(r["moves"]) <= 0 and not _board.is_won() and not _cancel.cancelled:
		r = solve_fn.call(_board, _limit, _weight, _cancel)
	_result = {"moves": int(r["moves"]), "path": r["path"]}


func _reset() -> void:
	_task_id = -1
	_key = ""
	_board = null
	_cancel = null
	_result = {}


static func _real_solve(
	board: SortBoard, limit: int, weight: float, cancel: SolverCancel
) -> Dictionary:
	return SortSolver.solve(board, limit, weight, cancel)
