extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_confetti.json"

var _level: Level
var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.clock = TestClock.fixed()
	_level.state = GameState.new()
	add_child(_level)


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _win() -> void:
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	var sol: Array = ContentGenerator.new().generate(seed_value, 1)["payload"]["solution"]
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func test_win_starts_confetti() -> void:
	_win()
	var c: CPUParticles2D = _level.confetti
	assert_bool(c.emitting).is_true()
	assert_bool(c.one_shot).is_true()
	assert_float(c.lifetime).is_equal_approx(float(GameConfig.get_value("confetti_seconds")), 0.001)
	assert_int(c.amount).is_equal(Level.CONFETTI_AMOUNT)
	var liquids: Array = _level.board.theme_data.get("liquids", [])
	var want: int = mini(Level.CONFETTI_COLORS, liquids.size())
	assert_int(c.color_initial_ramp.get_point_count()).is_equal(want)


func test_load_level_stops_confetti() -> void:
	_win()
	assert_bool(_level.confetti.emitting).is_true()
	_level.load_level(2)
	assert_bool(_level.confetti.emitting).is_false()


func test_effects_disabled_no_confetti() -> void:
	_level.effects_enabled = false
	_win()
	assert_bool(_level.confetti.emitting).is_false()


func test_restart_stops_confetti() -> void:
	_win()
	_level.restart()
	assert_bool(_level.confetti.emitting).is_false()
