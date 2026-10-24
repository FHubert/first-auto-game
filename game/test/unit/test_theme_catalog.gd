extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_theme_catalog.json"
const LEVEL_SCENE: String = "res://src/levels/level.tscn"

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


func _state(coins: int) -> GameState:
	var s := GameState.new()
	s.coins = coins
	return s


func test_costs() -> void:
	assert_int(ThemeCatalog.all().size()).is_equal(4)
	assert_str(ThemeCatalog.free_id()).is_equal("classic")
	assert_int(ThemeCatalog.cost("classic")).is_equal(0)
	assert_int(ThemeCatalog.cost("pastel")).is_equal(600)
	assert_int(ThemeCatalog.cost("neon")).is_equal(1080)
	assert_int(ThemeCatalog.cost("ocean")).is_equal(1944)
	assert_int(ThemeCatalog.paid_index("xxx")).is_equal(0)


func test_buy() -> void:
	var s := _state(700)
	assert_bool(ThemeCatalog.buy(s, "pastel")).is_true()
	assert_int(s.coins).is_equal(100)
	assert_bool(s.owns_theme("pastel")).is_true()
	assert_bool(ThemeCatalog.buy(s, "neon")).is_false()
	assert_int(s.coins).is_equal(100)
	assert_bool(s.owns_theme("neon")).is_false()
	assert_bool(ThemeCatalog.buy(s, "pastel")).is_false()
	assert_int(s.coins).is_equal(100)
	assert_bool(ThemeCatalog.buy(s, "xxx")).is_false()


func test_set_active_and_persistence() -> void:
	var s := _state(700)
	assert_bool(ThemeCatalog.set_active(s, "neon")).is_false()
	ThemeCatalog.buy(s, "pastel")
	assert_bool(ThemeCatalog.set_active(s, "pastel")).is_true()
	assert_str(s.theme_active).is_equal("pastel")
	SaveSystem.save(s)
	var loaded: GameState = SaveSystem.load()
	assert_str(loaded.theme_active).is_equal("pastel")
	assert_bool(loaded.owns_theme("pastel")).is_true()


func test_next_theme_cost() -> void:
	var s := _state(5000)
	assert_int(ThemeCatalog.next_theme_cost(s)).is_equal(600)
	ThemeCatalog.buy(s, "pastel")
	assert_int(ThemeCatalog.next_theme_cost(s)).is_equal(1080)
	ThemeCatalog.buy(s, "neon")
	ThemeCatalog.buy(s, "ocean")
	assert_int(ThemeCatalog.next_theme_cost(s)).is_equal(0)
	assert_str(ThemeCatalog.next_theme_id(s)).is_equal("")


func test_screen_buy_and_use() -> void:
	var screen: ThemesScreen = auto_free(ThemesScreen.new())
	screen.state = _state(700)
	add_child(screen)
	assert_bool(screen.card_button("pastel").disabled).is_false()
	assert_bool(screen.card_button("neon").disabled).is_true()
	screen.card_button("pastel").pressed.emit()
	assert_int(screen.state.coins).is_equal(100)
	assert_str(screen.card_button("pastel").text).is_equal(tr("btn_use"))
	var changed: Array = []
	screen.theme_selected.connect(func(id: String) -> void: changed.append(id))
	screen.card_button("pastel").pressed.emit()
	assert_str(screen.state.theme_active).is_equal("pastel")
	assert_array(changed).is_equal(["pastel"])


func test_board_and_level_use_catalog() -> void:
	assert_str(BoardView.load_theme("pastel")["shape"]).is_equal("flask")
	var level: Level = auto_free(load(LEVEL_SCENE).instantiate())
	level.state = GameState.new()
	level.clock = TestClock.fixed()
	add_child(level)
	level.load_level(2, "pastel")
	assert_str(level.board.theme_data["id"]).is_equal("pastel")


func test_app_routes_to_themes() -> void:
	var app: App = auto_free(App.new())
	app.clock = TestClock.fixed()
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	app.show_themes()
	assert_bool(app.current_screen() is ThemesScreen).is_true()
	(app.current_screen() as ThemesScreen).back_pressed.emit()
	assert_bool(app.current_screen() is Home).is_true()


func _level_with_move() -> Level:
	var level: Level = auto_free(load(LEVEL_SCENE).instantiate())
	level.state = GameState.new()
	level.clock = TestClock.fixed()
	add_child(level)
	level.board.animate = false
	level.load_level(2, "classic")
	var m: Vector2i = level.round.board().legal_moves()[0]
	level.board.tap(m.x)
	level.board.tap(m.y)
	return level


func test_level_apply_theme_keeps_round() -> void:
	var level: Level = _level_with_move()
	var moves: int = level.round.moves()
	var tubes: Array = level.round.board().tubes.duplicate(true)
	level.apply_theme("neon")
	assert_str(level.board.theme_id).is_equal("neon")
	assert_int(level.round.moves()).is_equal(moves)
	assert_array(level.round.board().tubes).is_equal(tubes)
	var neon: Dictionary = ThemeCatalog.theme("neon")
	var expected: Array = []
	for c: String in neon["liquids"]:
		expected.append(Color(c))
	for i: int in tubes.size():
		assert_array(level.board.view_layers(i)).is_equal(tubes[i])
		assert_array(level.board.view_liquids(i)).is_equal(expected)
	assert_str(level.board.theme_data["background"]).is_equal(neon["background"])


func test_refresh_after_shop_applies_new_theme() -> void:
	var level: Level = _level_with_move()
	var moves: int = level.round.moves()
	level.state.themes_owned.append("neon")
	assert_bool(ThemeCatalog.set_active(level.state, "neon")).is_true()
	level.refresh_after_shop()
	assert_str(level.board.theme_id).is_equal("neon")
	assert_int(level.round.moves()).is_equal(moves)


func test_screen_uses_translated_names() -> void:
	TranslationServer.set_locale("pl")
	var screen: ThemesScreen = auto_free(ThemesScreen.new())
	screen.state = _state(0)
	add_child(screen)
	assert_str(screen.card_name_label("neon").text).is_equal("Neonowy")
	TranslationServer.set_locale("en")


func test_app_theme_selected_hook() -> void:
	var app: App = auto_free(App.new())
	app.clock = TestClock.fixed()
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	app.show_level()
	app.state.themes_owned.append("neon")
	ThemeCatalog.set_active(app.state, "neon")
	app._on_theme_selected("neon")
	assert_str((app.current_screen() as Level).board.theme_id).is_equal("neon")


func test_board_view_has_no_dead_themes_path() -> void:
	var src: String = FileAccess.get_file_as_string("res://src/ui/board_view.gd")
	assert_int(src.count("THEMES_PATH")).is_equal(0)
