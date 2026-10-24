extends Node
## Autoload "SaveSystem": atomic JSON persistence of GameState.

var save_path: String = "user://save.json"
## When true save() is a no-op (screenshot mode must not overwrite the player's save).
var read_only: bool = false


## Writes to a temp file, then renames over the target. Returns true on success.
func save(state: GameState) -> bool:
	if read_only:
		return true
	var tmp_path: String = save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s (err %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(state.to_dict()))
	file.close()
	var err: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(save_path)
	)
	if err != OK:
		push_error("SaveSystem: rename failed (err %d)" % err)
		return false
	return true


## Returns the saved state; a fresh state if missing or corrupted.
func load() -> GameState:
	if not FileAccess.file_exists(save_path):
		return GameState.new()
	var text: String = FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: corrupted save file, starting fresh")
		return GameState.new()
	var state: GameState = GameState.from_dict(parsed)
	if state == null:
		push_warning("SaveSystem: invalid save data, starting fresh")
		return GameState.new()
	return state
