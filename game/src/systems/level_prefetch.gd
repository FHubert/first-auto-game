class_name LevelPrefetch
extends RefCounted
## Generacja poziomu N+1 w tle (ADR-011). Cache = 1 wpis.
## Watek robi dokladnie to samo co wywolanie synchroniczne (ContentGenerator.generate),
## wiec wynik jest identyczny (ADR-009). Generator w watku TYLKO czyta GameConfig;
## apply_remote nie jest wolany w trakcie rundy (remote config przy starcie aplikacji).

## Ile razy take() musialo generowac synchronicznie (diagnostyka/testy).
var sync_generations: int = 0

var _task_id: int = -1
var _seed: int = 0
var _level: int = -1
## Pisane wylacznie przez watek roboczy; czytane dopiero po wait_for_task_completion
## (ta funkcja daje happens-before), wiec Mutex nie jest potrzebny.
var _result: Dictionary = {}


func request(seed_value: int, level: int) -> void:
	if _level == level and _seed == seed_value and _task_id != -1:
		return
	cancel_all()
	_seed = seed_value
	_level = level
	_task_id = WorkerThreadPool.add_task(_work.bind(seed_value, level), false, "LevelPrefetch")


func take(seed_value: int, level: int) -> Dictionary:
	if _task_id != -1 and _seed == seed_value and _level == level:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		var out: Dictionary = _result
		_reset()
		return out
	cancel_all()
	sync_generations += 1
	return ContentGenerator.new().generate(seed_value, level)


## Zadania nie da sie anulowac - czekamy na koniec i czyscimy cache.
func cancel_all() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
	_reset()


func _work(seed_value: int, level: int) -> void:
	_result = ContentGenerator.new().generate(seed_value, level)


func _reset() -> void:
	_task_id = -1
	_level = -1
	_result = {}
