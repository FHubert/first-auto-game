extends Node
## Autoload "SaveSystem": atomic JSON persistence of GameState.

var save_path: String = "user://save.json"
## When true save() is a no-op (screenshot mode must not overwrite the player's save).
var read_only: bool = false
## Where the last load() got its state: "main", "backup", "fresh" (file existed but unreadable)
## or "none" (no main file).
var last_load_source: String = ""


## Path of the backup copy (previous valid save).
func backup_path() -> String:
	return save_path + ".bak"


## Writes to a temp file, verifies it, keeps the previous save as .bak, then renames over the
## target. Returns true on success; on failure the main file and .bak stay untouched.
func save(state: GameState) -> bool:
	if read_only:
		return true
	var tmp_path: String = save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s (err %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(state.to_dict()))
	var write_err: int = file.get_error()
	file.close()
	if write_err != OK:
		push_error("SaveSystem: write failed (err %d)" % write_err)
		_remove_file(tmp_path)
		return false
	var check := JSON.new()
	if (
		check.parse(FileAccess.get_file_as_string(tmp_path)) != OK
		or typeof(check.data) != TYPE_DICTIONARY
	):
		push_error("SaveSystem: written file failed verification")
		_remove_file(tmp_path)
		return false
	if FileAccess.file_exists(save_path):
		var copy_err: int = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path())
		)
		if copy_err != OK:
			push_warning("SaveSystem: backup copy failed (err %d)" % copy_err)
	var err: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(save_path)
	)
	if err != OK:
		push_error("SaveSystem: rename failed (err %d)" % err)
		_remove_file(tmp_path)
		return false
	return true


## Returns the saved state; the backup if the main file is corrupted; else a fresh state.
func load() -> GameState:
	if not FileAccess.file_exists(save_path):
		last_load_source = "none"
		return fresh_state()
	var state: GameState = _parse_state(save_path)
	if state != null:
		last_load_source = "main"
		return state
	state = _parse_state(backup_path())
	if state != null:
		last_load_source = "backup"
		return state
	last_load_source = "fresh"
	return fresh_state()


## New player state with the starting coin grant (T-173). Not used for states read from a save.
static func fresh_state() -> GameState:
	var state := GameState.new()
	state.coins = int(GameConfig.get_value("starting_coins"))
	return state


## Null when the file is missing, not valid JSON, not a Dictionary or invalid GameState data.
func _parse_state(path: String) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning(
			"SaveSystem: corrupted file %s (parse error line %d)" % [path, json.get_error_line()]
		)
		return null
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: corrupted file %s" % path)
		return null
	var state: GameState = GameState.from_dict(parsed)
	if state == null:
		push_warning("SaveSystem: invalid save data in %s" % path)
	return state


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
