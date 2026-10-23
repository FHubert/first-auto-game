class_name App
extends Control
## Router ekranow: Home <-> Level <-> Settings. Budowany w kodzie.

const SCREEN_HOME: String = "home"
const SCREEN_LEVEL: String = "level"
const SCREEN_SETTINGS: String = "settings"
const SCENE_HOME: String = "res://src/ui/home.tscn"
const SCENE_LEVEL: String = "res://src/levels/level.tscn"
const SCENE_SETTINGS: String = "res://src/ui/settings_screen.tscn"

var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var _screen: Node
var _screen_name: String = ""


func _ready() -> void:
	if state == null:
		state = SaveSystem.load()
	Locale.ensure_installed()
	Locale.apply_setting(str(state.settings.get("locale", "")))
	if bool(state.settings.get("tutorial_done", false)):
		show_home()
	else:
		show_level()


func current_screen() -> Node:
	return _screen


func current_screen_name() -> String:
	return _screen_name


func show_home() -> void:
	var home: Home = _swap(SCENE_HOME, SCREEN_HOME)
	home.play_pressed.connect(show_level)
	home.settings_pressed.connect(show_settings)
	home.themes_pressed.connect(func() -> void: Analytics.track_design("nav:themes"))
	home.shop_pressed.connect(func() -> void: Analytics.track_design("nav:shop"))
	add_child(home)


func show_level() -> void:
	var level: Level = _swap(SCENE_LEVEL, SCREEN_LEVEL)
	level.clock = clock
	level.pause_requested.connect(show_home)
	level.home_requested.connect(show_home)
	add_child(level)


func show_settings() -> void:
	var screen: SettingsScreen = _swap(SCENE_SETTINGS, SCREEN_SETTINGS)
	screen.back_pressed.connect(show_home)
	screen.settings_changed.connect(_on_setting_changed)
	add_child(screen)


func _on_setting_changed(key: String) -> void:
	if key == "locale":
		Locale.apply_setting(str(state.settings.get("locale", "")))
		show_settings()


## Zwalnia biezacy ekran, tworzy nowy ze stanem (przed add_child).
func _swap(path: String, screen_name: String) -> Node:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = (load(path) as PackedScene).instantiate()
	_screen_name = screen_name
	_screen.set("state", state)
	if _screen.get("clock") != null:
		_screen.set("clock", clock)
	return _screen
