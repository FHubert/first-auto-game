extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_config_variant.json"
const KEY: String = "remote_config_variant"
const MAX_LEN: int = 24

var _old_path: String
var _prev_provider: AnalyticsProvider
var _fake: FakeAnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_prev_provider = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake


func after_test() -> void:
	Analytics.provider = _prev_provider
	GameConfig.reset()
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	SaveSystem.save_path = _old_path


func _app() -> App:
	var app: App = auto_free(App.new())
	app.clock = TestClock.fixed()
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	return app


func _variant_events() -> Array[String]:
	var out: Array[String] = []
	for e in _fake.events:
		var id: String = str(e.get("event_id", ""))
		if id.begins_with("config:variant:"):
			out.append(id)
	return out


func test_default_variant_logged_once() -> void:
	_app()
	assert_array(_variant_events()).contains_exactly(["config:variant:default"])
	await get_tree().process_frame


func test_remote_variant_logged() -> void:
	assert_int(GameConfig.apply_remote({KEY: "h1_b"})).is_equal(1)
	_app()
	assert_array(_variant_events()).contains_exactly(["config:variant:h1_b"])
	await get_tree().process_frame


func test_invalid_format_rejected() -> void:
	assert_int(GameConfig.apply_remote({KEY: "H1 B!"})).is_equal(0)
	assert_str(GameConfig.get_value(KEY)).is_equal("default")
	assert_int(GameConfig.apply_remote({KEY: "a".repeat(MAX_LEN + 1)})).is_equal(0)
	assert_str(GameConfig.get_value(KEY)).is_equal("default")


func test_max_length_accepted() -> void:
	assert_int(GameConfig.apply_remote({KEY: "a".repeat(MAX_LEN)})).is_equal(1)
	assert_str(GameConfig.get_value(KEY)).is_equal("a".repeat(MAX_LEN))


func test_no_duplicate_while_session_open() -> void:
	var app := _app()
	app.track_session_start()
	assert_int(_variant_events().size()).is_equal(1)
	app.track_session_end()
	app.track_session_start()
	assert_int(_variant_events().size()).is_equal(2)
	await get_tree().process_frame
