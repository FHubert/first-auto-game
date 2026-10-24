extends GdUnitTestSuite

const CAMPAIGN: String = "campaign"


func _first_level(color_growth: bool) -> int:
	var gen := ContentGenerator.new()
	for l in range(1, 31):
		var grows: bool = (
			int(gen.level_params(l + 1)["colors"]) > int(gen.level_params(l)["colors"])
		)
		if grows == color_growth:
			return l
	return -1


func before_test() -> void:
	GameConfig.reset()


func test_new_color_message() -> void:
	var l: int = _first_level(true)
	assert_int(l).is_greater(0)
	var msg: Dictionary = LevelComplete.progress_message(l, CAMPAIGN, GameState.new())
	assert_str(msg["key"]).is_equal("lc_new_color")
	assert_array(msg["args"]).is_empty()


func test_theme_progress_message() -> void:
	var l: int = _first_level(false)
	var state := GameState.new()
	state.coins = 42
	var msg: Dictionary = LevelComplete.progress_message(l, CAMPAIGN, state)
	assert_str(msg["key"]).is_equal("lc_theme_progress")
	assert_array(msg["args"]).is_equal([42, ThemeCatalog.next_theme_cost(state)])


func test_all_themes_owned_gives_nothing() -> void:
	var state := GameState.new()
	for id: String in ThemeCatalog.ids():
		if not state.owns_theme(id):
			state.themes_owned.append(id)
	assert_dict(LevelComplete.progress_message(_first_level(false), CAMPAIGN, state)).is_empty()


func test_daily_gives_nothing() -> void:
	var msg: Dictionary = LevelComplete.progress_message(
		_first_level(true), Level.MODE_DAILY, GameState.new()
	)
	assert_dict(msg).is_empty()


func test_scene_progress_label() -> void:
	var lc: LevelComplete = (load("res://src/ui/level_complete.tscn") as PackedScene).instantiate()
	add_child(lc)
	lc.show_result(10, false, 3, "", {})
	assert_bool(lc.progress_label.visible).is_false()
	lc.show_result(10, false, 3, "", {"key": "lc_theme_progress", "args": [5, 100]})
	assert_bool(lc.progress_label.visible).is_true()
	assert_str(lc.progress_label.text).is_equal(tr("lc_theme_progress") % [5, 100])
	lc.show_result(10, false, 3, "", {"key": "lc_new_color", "args": []})
	assert_str(lc.progress_label.text).is_equal(tr("lc_new_color"))
	lc.free()
