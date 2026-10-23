extends GdUnitTestSuite


func test_build_info_not_empty() -> void:
	assert_str(Version.BUILD_INFO).is_not_empty()


func test_version_is_semver() -> void:
	var parts: PackedStringArray = Version.VERSION.split(".")
	assert_int(parts.size()).is_equal(3)
	for part in parts:
		assert_bool(part.is_valid_int()).is_true()


func test_build_info_format() -> void:
	var regex := RegEx.new()
	regex.compile("^[0-9]+(\\.[0-9]+)*\\+[0-9]+$")
	var matches_format: bool = regex.search(Version.BUILD_INFO) != null
	assert_bool(Version.BUILD_INFO == "dev" or matches_format).is_true()


func test_build_code_dev() -> void:
	assert_int(Version.build_code()).is_equal(-1)
	assert_bool(Version.is_dev_build()).is_true()


func test_parse_build_code_table() -> void:
	var cases: Array = [
		["0.1.0+42", 42],
		["1.2.3+7", 7],
		["dev", -1],
		["0.1.0+", -1],
		["0.1.0+abc", -1],
		["", -1],
	]
	for case in cases:
		var info: String = case[0]
		var expected: int = case[1]
		(
			assert_int(Version.parse_build_code(info))
			. override_failure_message("parse_build_code('%s') should be %d" % [info, expected])
			. is_equal(expected)
		)
