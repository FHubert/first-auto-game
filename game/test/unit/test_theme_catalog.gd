extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_theme_catalog.json"

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
	var level: Level = auto_free(load("res://src/levels/level.tscn").instantiate())
	level.state = GameState.new()
	add_child(level)
	level.load_level(2, "pastel")
	assert_str(level.board.theme_data["id"]).is_equal("pastel")


func test_app_routes_to_themes() -> void:
	var app: App = auto_free(App.new())
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	app.show_themes()
	assert_bool(app.current_screen() is ThemesScreen).is_true()
	(app.current_screen() as ThemesScreen).back_pressed.emit()
	assert_bool(app.current_screen() is Home).is_true()
