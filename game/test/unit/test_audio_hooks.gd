extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_audio_hooks.json"

var _level: Level
var _old_path: String
var _full: Array[int] = [0]


func before_test() -> void:
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	add_child(_level)
	_full[0] = 0
	Audio.sfx_requested.connect(_count)


func after_test() -> void:
	Audio.sfx_requested.disconnect(_count)
	if is_instance_valid(_level):
		_level.free()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	SaveSystem.save_path = _old_path


func _count(sfx_name: String) -> void:
	if sfx_name == "tube_full":
		_full[0] += 1


func test_closes_tube() -> void:
	var b: SortBoard = SortBoard.new([[1, 1, 1, 1], [1, 2, 1, 2], [3, 3], []], 4)
	assert_bool(Level.closes_tube(b, 0)).is_true()
	assert_bool(Level.closes_tube(b, 1)).is_false()
	assert_bool(Level.closes_tube(b, 2)).is_false()
	assert_bool(Level.closes_tube(b, 3)).is_false()


func test_level_plays_tube_full_once_per_closing_pour() -> void:
	var b: SortBoard = _level.round.board()
	b.tubes[0] = [9, 9, 9, 9]
	b.capacity = 4
	_level.board.pour_finished.emit(1, 0)
	assert_int(_full[0]).is_equal(1)
	b.tubes[0] = [9, 9]
	_level.board.pour_finished.emit(1, 0)
	assert_int(_full[0]).is_equal(1)
