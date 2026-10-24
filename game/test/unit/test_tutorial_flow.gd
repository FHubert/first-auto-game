extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_tutorial.json"

var _level: Level
var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	_cleanup()
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _cleanup() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _make_level(done: bool) -> void:
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.state.settings["tutorial_done"] = done
	add_child(_level)


func test_state_machine_happy_path() -> void:
	var t := TutorialFlow.new()
	t.start(Vector2i(0, 2))
	assert_bool(t.on_tube_selected(1)).is_false()
	assert_int(t.step).is_equal(TutorialFlow.Step.PICK_SOURCE)
	assert_int(t.highlight()).is_equal(0)
	assert_bool(t.on_pour(0, 2, Vector2i(1, 3), false)).is_false()
	assert_bool(t.on_tube_selected(0)).is_true()
	assert_int(t.step).is_equal(TutorialFlow.Step.PICK_TARGET)
	assert_int(t.highlight()).is_equal(2)
	t.on_deselect()
	assert_int(t.step).is_equal(TutorialFlow.Step.PICK_SOURCE)
	t.on_tube_selected(0)
	assert_bool(t.on_pour(0, 1, Vector2i(1, 3), false)).is_false()
	assert_bool(t.on_pour(0, 2, Vector2i(1, 3), false)).is_true()
	assert_int(t.step).is_equal(TutorialFlow.Step.FINISH)
	assert_int(t.highlight()).is_equal(1)
	assert_bool(t.on_pour(1, 3, GameRound.NO_HINT, true)).is_true()
	assert_bool(t.is_done()).is_true()
	assert_int(t.highlight()).is_equal(-1)
	assert_str(t.message()).is_empty()


func test_win_on_expected_pour_finishes() -> void:
	var t := TutorialFlow.new()
	t.start(Vector2i(0, 1))
	t.on_tube_selected(0)
	assert_bool(t.on_pour(0, 1, GameRound.NO_HINT, true)).is_true()
	assert_bool(t.is_done()).is_true()


func test_level_one_is_two_colors_short() -> void:
	var seed_value: int = int(GameConfig.get_value("campaign_seed"))
	var payload: Dictionary = ContentGenerator.new().generate(seed_value, 1)["payload"]
	assert_int(int(payload["colors"])).is_equal(2)
	assert_int(int(payload["min_moves"])).is_less_equal(4)


func test_scene_runs_tutorial_to_completion() -> void:
	_make_level(false)
	assert_object(_level.tutorial).is_not_null()
	assert_bool(_level.tutorial_overlay.visible).is_true()
	assert_bool(_level.hud.hint_button.visible).is_false()
	var path: Array = SortSolver.solve(_level.round.board(), 20000, 1.0)["path"]
	for m: Vector2i in path:
		_level.board.tap(m.x)
		_level.board.tap(m.y)
	assert_bool(bool(_level.state.settings["tutorial_done"])).is_true()
	assert_object(_level.tutorial).is_null()
	assert_bool(_level.tutorial_overlay.visible).is_false()
	assert_bool(_level.hud.hint_button.visible).is_true()
	assert_bool(bool(SaveSystem.load().settings["tutorial_done"])).is_true()


func test_scene_illegal_target_restarts_step() -> void:
	_make_level(false)
	var m: Vector2i = _level.tutorial.expected
	_level.board.tap(m.x)
	assert_int(_level.tutorial.step).is_equal(TutorialFlow.Step.PICK_TARGET)
	var bad: int = m.x
	for i: int in _level.round.board().tube_count():
		if i != m.x and not _level.round.board().can_pour(m.x, i):
			bad = i
			break
	_level.board.tap(bad)
	assert_int(_level.board.selected_index()).is_equal(-1)
	assert_int(_level.tutorial.step).is_equal(TutorialFlow.Step.PICK_SOURCE)
	assert_int(_level.tutorial.highlight()).is_equal(m.x)
	assert_bool(_level.tutorial_overlay.visible).is_true()
	assert_str(_level.tutorial_overlay.label.text).is_equal(tr("tut_pick_source"))


func test_scene_skips_tutorial_when_done() -> void:
	_make_level(true)
	assert_object(_level.tutorial).is_null()
	assert_bool(_level.tutorial_overlay.visible).is_false()
	assert_bool(_level.hud.hint_button.visible).is_true()
