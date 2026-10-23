extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_level_flow.json"
const FAKE_UNIX: int = 20750 * 86400 + 100

var _level: Level
var _old_path: String
var _coins_before: int


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.clock = func() -> int: return FAKE_UNIX
	_coins_before = _level.state.coins
	add_child(_level)


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


func _solution() -> Array:
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	return ContentGenerator.new().generate(seed_value, 1)["payload"]["solution"]


func _win() -> void:
	var sol: Array = _solution()
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func test_hud_shows_level_and_moves() -> void:
	assert_str(_level.hud.level_label.text).contains("1")
	var m: Vector2i = _level.round.board().legal_moves()[0]
	_level.board.tap(m.x)
	_level.board.tap(m.y)
	assert_str(_level.hud.moves_label.text).contains("1")


func test_win_advances_level_and_pays_coins() -> void:
	_win()
	var st: GameState = _level.state
	var reward: int = int(GameConfig.get_value("win_reward_coins"))
	reward += int(GameConfig.get_value("par_bonus_coins"))
	assert_int(st.level).is_equal(2)
	assert_int(st.coins).is_equal(_coins_before + reward)
	assert_bool(_level.level_complete.visible).is_true()
	assert_int(st.levels_completed).is_equal(1)
	assert_int(st.streak_days).is_equal(1)


func test_win_is_saved() -> void:
	_win()
	var loaded: GameState = SaveSystem.load()
	assert_int(loaded.level).is_equal(2)
	assert_int(loaded.coins).is_equal(_level.state.coins)


func test_next_loads_following_level() -> void:
	_win()
	_level.on_next_pressed()
	assert_bool(_level.level_complete.visible).is_false()
	assert_str(_level.hud.level_label.text).contains("2")
	assert_int(_level.round.moves()).is_equal(0)
	var views: int = 0
	for c in _level.board.get_children():
		if c is TubeView and not c.is_queued_for_deletion():
			views += 1
	assert_int(views).is_equal(_level.round.board().tube_count())


func test_undo_and_restart() -> void:
	var charges: int = _level.round.undo_charges()
	var m: Vector2i = _level.round.board().legal_moves()[0]
	_level.board.tap(m.x)
	_level.board.tap(m.y)
	_level.undo()
	assert_int(_level.round.moves()).is_equal(0)
	assert_str(_level.hud.undo_button.text).contains(str(charges - 1))
	_level.board.tap(m.x)
	_level.board.tap(m.y)
	_level.restart()
	assert_int(_level.round.moves()).is_equal(0)
	assert_int(_level.state.level_restarts).is_equal(1)


func _win_level_two() -> void:
	_level.load_level(2)
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	var sol: Array = ContentGenerator.new().generate(seed_value, 2)["payload"]["solution"]
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func test_double_coins_once_on_level_two() -> void:
	_win_level_two()
	assert_bool(_level.can_double_coins()).is_true()
	var before: int = _level.state.coins
	var bonus: int = Economy.rewarded_bonus(_level._last_win_coins)
	assert_bool(_level.watch_double_coins()).is_true()
	assert_int(_level.state.coins).is_equal(before + bonus)
	assert_bool(_level.watch_double_coins()).is_false()
	assert_int(_level.state.coins).is_equal(before + bonus)


func test_double_coins_not_on_level_one() -> void:
	_win()
	assert_bool(_level.can_double_coins()).is_false()
	assert_bool(_level.watch_double_coins()).is_false()


func test_watch_extra_tube_is_free() -> void:
	var coins: int = _level.state.coins
	var tubes: int = _level.round.board().tube_count()
	assert_bool(_level.watch_extra_tube()).is_true()
	assert_int(_level.round.board().tube_count()).is_equal(tubes + 1)
	assert_int(_level.state.coins).is_equal(coins)
	assert_bool(_level.watch_extra_tube()).is_false()


func test_watch_undo_refill_adds_charges() -> void:
	var before: int = _level.round.undo_charges()
	assert_bool(_level.watch_undo_refill()).is_true()
	var amount: int = int(GameConfig.get_value("undo_refill_amount"))
	assert_int(_level.round.undo_charges()).is_equal(before + amount)
