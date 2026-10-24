extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_app_prefetch.json"
const TEST_LEVEL: int = 12
const TEST_NOW_UNIX: int = 20000 * 86400 + 100

var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	_cleanup()
	SaveSystem.save_path = _old_path


func _cleanup() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _app(snapshot: Dictionary = {}) -> App:
	var app: App = auto_free(App.new())
	app.clock = func() -> int: return TEST_NOW_UNIX
	app.state = GameState.new()
	app.state.level = TEST_LEVEL
	app.state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	app.state.round_in_progress = snapshot
	add_child(app)
	return app


func test_home_requests_prefetch() -> void:
	var app := _app()
	assert_object(app.home_prefetch).is_not_null()


func test_play_uses_prefetch_without_sync_generation() -> void:
	var app := _app()
	(app.current_screen() as Home).play_pressed.emit()
	var level := app.current_screen() as Level
	assert_int(level.prefetch.sync_generations).is_equal(0)
	assert_object(app.home_prefetch).is_null()
	assert_int(level.level_no).is_equal(TEST_LEVEL)


func test_prefetched_level_equals_synchronous_generation() -> void:
	var app := _app()
	app.show_level()
	var level := app.current_screen() as Level
	var seed_value: int = int(GameConfig.get_value("campaign_seed"))
	var expected: Dictionary = ContentGenerator.new().generate(seed_value, TEST_LEVEL)
	assert_array(level.round.board().tubes).is_equal(expected["payload"]["tubes"])


func test_resumable_campaign_round_skips_prefetch() -> void:
	var first := _app()
	first.show_level()
	var snap: Dictionary = (first.current_screen() as Level).snapshot()
	assert_str(str(snap.get("mode", ""))).is_equal(Level.MODE_CAMPAIGN)
	var app := _app(snap)
	assert_object(app.home_prefetch).is_null()
	app.show_level()
	assert_bool(app.current_screen() is Level).is_true()
	assert_int((app.current_screen() as Level).prefetch.sync_generations).is_equal(0)


func test_leaving_home_cancels_prefetch() -> void:
	var app := _app()
	var pf: LevelPrefetch = app.home_prefetch
	app.show_settings()
	assert_object(app.home_prefetch).is_null()
	assert_int(pf._task_id).is_equal(-1)
