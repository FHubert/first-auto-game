extends GdUnitTestSuite

const SCENE: String = "res://src/ui/home.tscn"


func _args(extra: Array) -> PackedStringArray:
	return PackedStringArray(extra)


func test_valid_all_flags() -> void:
	var r: Dictionary = ScreenshotArgs.parse(
		_args(["--screenshot=" + SCENE, "--out=/tmp/a.png", "--lang=pl", "--fixture=midgame"])
	)
	assert_bool(r["ok"]).is_true()
	assert_str(r["scene"]).is_equal(SCENE)
	assert_str(r["out"]).is_equal("/tmp/a.png")
	assert_str(r["lang"]).is_equal("pl")
	assert_str(r["fixture"]).is_equal("midgame")


func test_defaults_for_optional_flags() -> void:
	var r: Dictionary = ScreenshotArgs.parse(_args(["--screenshot=" + SCENE, "--out=a.png"]))
	assert_bool(r["ok"]).is_true()
	assert_str(r["fixture"]).is_equal("default")
	assert_str(r["lang"]).is_equal("")


func test_missing_out_fails() -> void:
	assert_bool(ScreenshotArgs.parse(_args(["--screenshot=" + SCENE]))["ok"]).is_false()


func test_out_without_png_fails() -> void:
	var r: Dictionary = ScreenshotArgs.parse(_args(["--screenshot=" + SCENE, "--out=a.jpg"]))
	assert_bool(r["ok"]).is_false()
	assert_str(r["error"]).is_not_empty()


func test_unknown_scene_fails() -> void:
	var r: Dictionary = ScreenshotArgs.parse(_args(["--screenshot=res://nope.tscn", "--out=a.png"]))
	assert_bool(r["ok"]).is_false()


func test_unknown_fixture_fails() -> void:
	var r: Dictionary = ScreenshotArgs.parse(
		_args(["--screenshot=" + SCENE, "--out=a.png", "--fixture=zzz"])
	)
	assert_bool(r["ok"]).is_false()


func test_unknown_lang_fails() -> void:
	var r: Dictionary = ScreenshotArgs.parse(
		_args(["--screenshot=" + SCENE, "--out=a.png", "--lang=xx"])
	)
	assert_bool(r["ok"]).is_false()


func test_action_for_every_known_scene() -> void:
	for scene in ScreenshotArgs.KNOWN_SCENES:
		assert_str(ScreenshotArgs.action_for(scene)).is_not_empty()
	assert_str(ScreenshotArgs.action_for("res://nope.tscn")).is_empty()


func test_now_flag_parsed() -> void:
	var r: Dictionary = ScreenshotArgs.parse(
		_args(["--screenshot=" + SCENE, "--out=a.png", "--now=1700000000"])
	)
	assert_bool(r["ok"]).is_true()
	assert_int(r["now"]).is_equal(1700000000)


func test_now_defaults_to_constant() -> void:
	var r: Dictionary = ScreenshotArgs.parse(_args(["--screenshot=" + SCENE, "--out=a.png"]))
	assert_int(r["now"]).is_equal(ScreenshotArgs.SCREENSHOT_NOW_UNIX)


func test_now_invalid_fails() -> void:
	for bad in ["abc", "-5"]:
		var r: Dictionary = ScreenshotArgs.parse(
			_args(["--screenshot=" + SCENE, "--out=a.png", "--now=" + bad])
		)
		assert_bool(r["ok"]).is_false()
		assert_str(r["error"]).is_equal("--now must be a non-negative integer")
