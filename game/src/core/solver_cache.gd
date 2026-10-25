class_name SolverCache
extends RefCounted
## Cache rozwiazan solvera per uklad planszy (T-222). Klucz = dokladny uklad probowek
## (nie canonical_key): sciezka zawiera indeksy probowek. Wydzielone z GameRound (limit
## metod publicznych); zasilane synchronicznie (_solve_cached) albo z HintJob.

var _entries: Dictionary = {}


static func key_of(board: SortBoard) -> String:
	return str(board.tubes)


func has_key(key: String) -> bool:
	return _entries.has(key)


func get_entry(key: String) -> Dictionary:
	return _entries[key]


func put(key: String, moves: int, path: Array) -> void:
	_entries[key] = {"moves": moves, "path": path}


func clear() -> void:
	_entries = {}
