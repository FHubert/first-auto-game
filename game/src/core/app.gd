class_name App
extends Control
## Router ekranow: Home <-> Level <-> Settings. Budowany w kodzie.

const SCREEN_HOME: String = "home"
const SCREEN_LEVEL: String = "level"
const SCREEN_SETTINGS: String = "settings"
const SCREEN_THEMES: String = "themes"
const POPUP_SCENE: PackedScene = preload("res://src/ui/daily_reward_popup.tscn")
const SCENE_HOME: String = "res://src/ui/home.tscn"
const SCENE_LEVEL: String = "res://src/levels/level.tscn"
const SCENE_SETTINGS: String = "res://src/ui/settings_screen.tscn"
const SCENE_THEMES: String = "res://src/ui/themes_screen.tscn"

var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var _screen: Node
var _screen_name: String = ""
var _popup: DailyRewardPopup
var _popup_shown_day: int = -1


func _ready() -> void:
	if state == null:
		state = SaveSystem.load()
	Locale.ensure_installed()
	Locale.apply_setting(str(state.settings.get("locale", "")))
	Audio.apply_settings(state.settings)
	Audio.play_music()
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
	home.themes_pressed.connect(show_themes)
	home.shop_pressed.connect(func() -> void: Analytics.track_design("nav:shop"))
	home.daily_pressed.connect(show_daily_level)
	add_child(home)
	_maybe_show_daily_popup(home)


func popup_visible() -> bool:
	return _popup != null and is_instance_valid(_popup) and _popup.visible


func _maybe_show_daily_popup(home: Home) -> void:
	var day: int = DailyRewards.utc_day_from_unix(int(clock.call()))
	if not DailyRewards.can_claim(state, day) or _popup_shown_day == day:
		return
	_popup_shown_day = day
	_popup = POPUP_SCENE.instantiate()
	add_child(_popup)
	_popup.show_for(state, day)
	_popup.claimed.connect(func(_amount: int) -> void: home.refresh())
	_popup.claimed.connect(_close_popup)
	_popup.closed.connect(_close_popup)


func _close_popup(_amount: int = 0) -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.visible = false
		_popup.queue_free()
	_popup = null


func show_level() -> void:
	var level: Level = _swap(SCENE_LEVEL, SCREEN_LEVEL)
	level.clock = clock
	level.pause_requested.connect(show_home)
	level.home_requested.connect(show_home)
	add_child(level)


func show_daily_level() -> void:
	var level: Level = _swap(SCENE_LEVEL, SCREEN_LEVEL)
	level.clock = clock
	level.pause_requested.connect(show_home)
	level.home_requested.connect(show_home)
	level.round = GameRound.new()  # pomija load_level w _ready; start_daily ustawi runde
	add_child(level)
	level.start_daily(DailyRewards.utc_day_from_unix(int(clock.call())))


func show_settings() -> void:
	var screen: SettingsScreen = _swap(SCENE_SETTINGS, SCREEN_SETTINGS)
	screen.back_pressed.connect(show_home)
	screen.settings_changed.connect(_on_setting_changed)
	add_child(screen)


func show_themes() -> void:
	Analytics.track_design("nav:themes")
	var screen: ThemesScreen = _swap(SCENE_THEMES, SCREEN_THEMES)
	screen.back_pressed.connect(show_home)
	add_child(screen)


func _on_setting_changed(key: String) -> void:
	Audio.apply_settings(state.settings)
	if key == "locale":
		Locale.apply_setting(str(state.settings.get("locale", "")))
		show_settings()


## Zwalnia biezacy ekran, tworzy nowy ze stanem (przed add_child).
func _swap(path: String, screen_name: String) -> Node:
	_close_popup()
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = (load(path) as PackedScene).instantiate()
	_screen_name = screen_name
	_screen.set("state", state)
	if _screen.get("clock") != null:
		_screen.set("clock", clock)
	return _screen
