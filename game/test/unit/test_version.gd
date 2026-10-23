extends GdUnitTestSuite


func test_build_info_not_empty() -> void:
	assert_str(Version.BUILD_INFO).is_not_empty()


func test_version_is_semver() -> void:
	var parts: PackedStringArray = Version.VERSION.split(".")
	assert_int(parts.size()).is_equal(3)
	for part in parts:
		assert_bool(part.is_valid_int()).is_true()
