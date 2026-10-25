extends GdUnitTestSuite
## Static guard: every GameConfig key read in src/ exists in DEFAULTS,
## and no call site carries a duplicated literal fallback.

const SRC_ROOT: String = "res://src"
const CONFIG_SCRIPT: GDScript = preload("res://src/systems/config.gd")
const MIN_KEYS: int = 40
## A key counts as read only as the first argument of get_value / _cfg_*
## (whitespace/newline after "(" allowed), literal or via a same-file const.
const READ_CALL: String = "(?:get_value|_cfg_[a-z]+)\\(\\s*"
const READ_LITERAL_RE: String = READ_CALL + '"([a-z0-9_]+)"'
const CONST_STR_RE: String = 'const\\s+([A-Za-z_0-9]+)\\s*(?::\\s*String\\s*)?:?=\\s*"([a-z0-9_]+)"'
const SETTING_KEYS_RE: String = (
	'"(notifications_on|tutorial_done|colorblind_symbols|daily_intro_seen'
	+ '|music_on|sfx_on|haptics_on)"'
)

## Keys allowed to stay unread in src/ (each with a reason).
const UNREAD_ALLOWED: Array[String] = [
	# Design target from GDD (Sesja), not a runtime parameter.
	"session_target_seconds",
]


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_gd_files(dir_path.path_join(sub)))
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out


## Returns pattern's first capture (or whole match) -> Array of files.
func _scan(pattern: String) -> Dictionary:
	var re: RegEx = RegEx.new()
	re.compile(pattern)
	var found: Dictionary = {}
	for path: String in _gd_files(SRC_ROOT):
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in re.search_all(text):
			var key: String = m.get_string(1) if m.get_group_count() > 0 else m.get_string()
			if not found.has(key):
				found[key] = []
			found[key].append(path)
	return found


## Keys read via get_value/_cfg_* -> Array of files (literal or same-file const).
func _read_keys() -> Dictionary:
	var found: Dictionary = _scan(READ_LITERAL_RE)
	var const_re: RegEx = RegEx.new()
	const_re.compile(CONST_STR_RE)
	for path: String in _gd_files(SRC_ROOT):
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in const_re.search_all(text):
			var use_re: RegEx = RegEx.new()
			use_re.compile(READ_CALL + m.get_string(1) + "\\b")
			if use_re.search(text) != null:
				var key: String = m.get_string(2)
				if not found.has(key):
					found[key] = []
				found[key].append(path)
	return found


func test_all_read_keys_exist_in_defaults() -> void:
	var defaults: Dictionary = CONFIG_SCRIPT.DEFAULTS
	var found: Dictionary = _read_keys()
	assert_int(found.size()).is_greater_equal(MIN_KEYS)
	var missing: Array[String] = []
	for key: String in found:
		if not defaults.has(key):
			missing.append("%s (%s)" % [key, ", ".join(found[key])])
	(
		assert_array(missing)
		. override_failure_message("Keys missing in DEFAULTS: %s" % str(missing))
		. is_empty()
	)


func test_every_default_key_is_read_in_src() -> void:
	var defaults: Dictionary = CONFIG_SCRIPT.DEFAULTS
	var seen: Dictionary = _read_keys()
	var unread: Array[String] = []
	for key: String in defaults:
		if not seen.has(key) and not UNREAD_ALLOWED.has(key):
			unread.append(key)
	(
		assert_array(unread)
		. override_failure_message("DEFAULTS keys never read in src/: %s" % str(unread))
		. is_empty()
	)


func test_no_literal_fallbacks() -> void:
	var found: Dictionary = _scan('get_value\\("[a-z0-9_]+",')
	assert_dict(found).override_failure_message("Literal fallbacks: %s" % str(found)).is_empty()


func test_no_literal_setting_keys() -> void:
	var found: Dictionary = _scan(SETTING_KEYS_RE)
	for key: String in found.keys():
		var files: Array = (found[key] as Array).filter(
			func(p: String) -> bool: return not p.ends_with("/core/game_state.gd")
		)
		if files.is_empty():
			found.erase(key)
		else:
			found[key] = files
	assert_dict(found).override_failure_message("Literal setting keys: %s" % str(found)).is_empty()


func test_no_set_for_test_in_src() -> void:
	var found: Dictionary = _scan("\\bset_for_test\\(")
	for key: String in found.keys():
		var files: Array = (found[key] as Array).filter(
			func(p: String) -> bool: return not p.ends_with("/systems/config.gd")
		)
		if files.is_empty():
			found.erase(key)
		else:
			found[key] = files
	assert_dict(found).override_failure_message("set_for_test in src: %s" % str(found)).is_empty()


func _test_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_test_files(dir_path.path_join(sub)))
	for f: String in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out


func test_save_suites_use_save_cleanup() -> void:
	var setter: String = "SaveSystem." + "save_path ="
	var cleanup: String = "TestSaveCleanup." + "remove("
	var missing: Array[String] = []
	for path: String in _test_files("res://test"):
		var text: String = FileAccess.get_file_as_string(path)
		if text.contains(setter) and not text.contains(cleanup):
			missing.append(path)
	var msg: String = "Missing save cleanup: %s" % str(missing)
	assert_array(missing).override_failure_message(msg).is_empty()
