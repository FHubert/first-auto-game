extends GdUnitTestSuite

## Paczki wariantow A/B z docs/remote_config/*.json musza przechodzic GameConfig.apply_remote.

const VARIANT_RE: String = "^[a-z0-9_]{1,24}$"


func before_test() -> void:
	GameConfig.reset()


func after_test() -> void:
	GameConfig.reset()


func _dir() -> String:
	return (
		ProjectSettings.globalize_path("res://").path_join("../docs/remote_config").simplify_path()
	)


func _packages() -> Dictionary:
	var out: Dictionary = {}
	var dir: String = _dir()
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() != "json":
			continue
		var file: FileAccess = FileAccess.open(dir.path_join(f), FileAccess.READ)
		assert_object(file).is_not_null()
		out[f.get_basename()] = JSON.parse_string(file.get_as_text())
	return out


func test_at_least_four_packages() -> void:
	var pk: Dictionary = _packages()
	assert_int(pk.size()).is_greater_equal(4)
	assert_dict(pk).contains_keys(["default", "h1_b", "h2_b", "h3_b"])


func test_each_file_parses_to_dictionary() -> void:
	for name: String in _packages():
		var v: Variant = _packages()[name]
		assert_bool(v is Dictionary).is_true()
		assert_bool((v as Dictionary).is_empty()).is_false()


func test_every_key_exists_in_defaults() -> void:
	var pk: Dictionary = _packages()
	for name: String in pk:
		for k: String in pk[name]:
			var msg: String = "%s: unknown key %s" % [name, k]
			assert_bool(GameConfig.DEFAULTS.has(k)).override_failure_message(msg).is_true()


func test_apply_remote_accepts_all_keys() -> void:
	var pk: Dictionary = _packages()
	for name: String in pk:
		GameConfig.reset()
		var pkg: Dictionary = pk[name]
		assert_int(GameConfig.apply_remote(pkg)).override_failure_message(name).is_equal(pkg.size())
		for k: String in pkg:
			var want: Variant = pkg[k]
			var got: Variant = GameConfig.get_value(k)
			if want is float and got is float:
				assert_float(got).is_equal_approx(want, 0.0001)
			elif want is float:
				assert_int(got).is_equal(int(want))
			else:
				assert_that(got).is_equal(want)


func test_variant_matches_file_name() -> void:
	var re: RegEx = RegEx.create_from_string(VARIANT_RE)
	var pk: Dictionary = _packages()
	for name: String in pk:
		var variant: String = str(pk[name]["remote_config_variant"])
		assert_str(variant).is_equal(name)
		assert_bool(re.search(variant) != null).is_true()


func test_reset_restores_defaults() -> void:
	GameConfig.apply_remote(_packages()["h2_b"])
	GameConfig.reset()
	var keys: Array[String] = [
		"interstitial_every_n_rounds", "interstitial_min_seconds", "interstitial_min_level"
	]
	for k: String in keys:
		assert_that(GameConfig.get_value(k)).is_equal(GameConfig.DEFAULTS[k])


func test_default_package_only_has_variant() -> void:
	assert_int((_packages()["default"] as Dictionary).size()).is_equal(1)
