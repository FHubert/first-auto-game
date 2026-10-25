class_name SolverCache
extends RefCounted
## Cache rozwiazan solvera per uklad planszy (T-222). Klucz = dokladny uklad probowek
## (nie canonical_key): sciezka zawiera indeksy probowek. Wydzielone z GameRound (limit
## metod publicznych); zasilane synchronicznie (_solve_cached) albo z HintJob.

var _entries: Dictionary = {}


## T-237: limit w kluczu - wyniki z roznych budzetow (podpowiedz vs moves_to_goal) sie nie mieszaja.
static func key_of(board: SortBoard, limit: int) -> String:
	return str(board.tubes) + "#" + str(limit)


func has_key(key: String) -> bool:
	return _entries.has(key)


func get_entry(key: String) -> Dictionary:
	return _entries[key]


func put(key: String, moves: int, path: Array) -> void:
	_entries[key] = {"moves": moves, "path": path}


func clear() -> void:
	_entries = {}
