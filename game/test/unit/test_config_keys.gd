extends GdUnitTestSuite
## Static guard: every GameConfig key read in src/ exists in DEFAULTS,
## and no call site carries a duplicated literal fallback.

const SRC_ROOT: String = "res://src"
const MIN_KEYS: int = 40


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


func test_all_read_keys_exist_in_defaults() -> void:
	var defaults: Dictionary = load("res://src/systems/config.gd").DEFAULTS
	var found: Dictionary = _scan('get_value\\("([a-z0-9_]+)"')
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


func test_no_literal_fallbacks() -> void:
	var found: Dictionary = _scan('get_value\\("[a-z0-9_]+",')
	assert_dict(found).override_failure_message("Literal fallbacks: %s" % str(found)).is_empty()
