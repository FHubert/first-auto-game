class_name App
extends Control
## Router ekranow: Home <-> Level <-> Settings. Budowany w kodzie.

const SCREEN_HOME: String = "home"
const SCREEN_LEVEL: String = "level"
const SCREEN_SETTINGS: String = "settings"
const SCREEN_THEMES: String = "themes"
const SCREEN_SHOP: String = "shop"
const POPUP_SCENE: PackedScene = preload("res://src/ui/daily_reward_popup.tscn")
const SCENE_HOME: String = "res://src/ui/home.tscn"
const SCENE_LEVEL: String = "res://src/levels/level.tscn"
const SCENE_SETTINGS: String = "res://src/ui/settings_screen.tscn"
const SCENE_THEMES: String = "res://src/ui/themes_screen.tscn"
const SCENE_SHOP: String = "res://src/ui/shop_screen.tscn"

var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var shop_overlay: ShopScreen
var _screen: Node
var _screen_name: String = ""
var _popup: DailyRewardPopup
var _popup_shown_day: int = -1
var _session_start_s: float = 0.0
var _session_open: bool = false


func _ready() -> void:
	track_session_start()
	Ads.begin_consent()
	if not Ads.ad_about_to_show.is_connected(_on_ad_about_to_show):
		Ads.ad_about_to_show.connect(_on_ad_about_to_show)
	if state == null:
		state = SaveSystem.load()
	Purchases.bind_state(state)
	Locale.ensure_installed()
	Locale.apply_setting(str(state.settings.get("locale", "")))
	Audio.apply_settings(state.settings)
	Audio.play_music()
	if bool(state.settings.get("tutorial_done", false)):
		show_home()
	else:
		show_level()


func _exit_tree() -> void:
	if Ads.ad_about_to_show.is_connected(_on_ad_about_to_show):
		Ads.ad_about_to_show.disconnect(_on_ad_about_to_show)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_round()
		track_session_end()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		track_session_start()


func _on_ad_about_to_show(_kind: String) -> void:
	_save_round()


## Zapisuje biezaca runde (jesli ekran to Level) do round_in_progress.
func _save_round() -> void:
	if state == null or not _screen is Level:
		return
	state.round_in_progress = (_screen as Level).snapshot()
	SaveSystem.save(state)


func _today() -> int:
	return DailyRewards.utc_day_from_unix(int(clock.call()))


## Starts a focus session once (no duplicate after _ready + FOCUS_IN).
func track_session_start() -> void:
	if _session_open:
		return
	_session_open = true
	_session_start_s = float(clock.call())
	Analytics.track_design("session:start")


func track_session_end() -> void:
	if not _session_open:
		return
	_session_open = false
	Analytics.track_design("session:end", maxf(0.0, float(clock.call()) - _session_start_s))


func current_screen() -> Node:
	return _screen


func current_screen_name() -> String:
	return _screen_name


func show_home() -> void:
	var home: Home = _swap(SCENE_HOME, SCREEN_HOME)
	home.play_pressed.connect(show_level)
	home.settings_pressed.connect(show_settings)
	home.themes_pressed.connect(show_themes)
	home.shop_pressed.connect(
		func() -> void:
			Analytics.track_design("nav:shop")
			show_shop()
	)
	home.daily_pressed.connect(show_daily_level)
	add_child(home)
	_maybe_show_daily_popup(home)


func popup_visible() -> bool:
	return _popup != null and is_instance_valid(_popup) and _popup.visible


func _maybe_show_daily_popup(home: Home) -> void:
	var day: int = _today()
	if not DailyRewards.can_claim(state, day) or _popup_shown_day == day:
		return
	_popup_shown_day = day
	_popup = POPUP_SCENE.instantiate()
	add_child(_popup)
	_popup.show_for(state, day)
	if home.daily_card != null:
		home.daily_card.visible = false
	_popup.claimed.connect(func(_amount: int) -> void: home.refresh())
	_popup.claimed.connect(_close_popup)
	_popup.closed.connect(_close_popup)


func _close_popup(_amount: int = 0) -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.visible = false
		_popup.queue_free()
	_popup = null
	var home := _screen as Home
	if home != null and home.daily_card != null:
		home.daily_card.visible = true


func show_level() -> void:
	var level: Level = _swap(SCENE_LEVEL, SCREEN_LEVEL)
	level.clock = clock
	level.pause_requested.connect(show_home)
	level.home_requested.connect(show_home)
	level.shop_requested.connect(func(r: String) -> void: show_shop(r, true))
	var snap: Dictionary = state.round_in_progress
	if str(snap.get("mode", "")) == Level.MODE_CAMPAIGN:
		level.round = GameRound.new()  # pomija autoload w _ready; resume/load_level ustawi
		add_child(level)
		if not level.resume(snap, _today()):
			state.round_in_progress = {}
			level.load_level(state.level, state.theme_active)
		return
	add_child(level)


func show_daily_level() -> void:
	var level: Level = _swap(SCENE_LEVEL, SCREEN_LEVEL)
	level.clock = clock
	level.pause_requested.connect(show_home)
	level.home_requested.connect(show_home)
	level.shop_requested.connect(func(r: String) -> void: show_shop(r, true))
	level.round = GameRound.new()  # pomija load_level w _ready; start_daily ustawi runde
	add_child(level)
	if str(state.round_in_progress.get("mode", "")) == Level.MODE_DAILY:
		if level.resume(state.round_in_progress, _today()):
			return
		state.round_in_progress = {}
	level.start_daily(_today())


func show_settings() -> void:
	var screen: SettingsScreen = _swap(SCENE_SETTINGS, SCREEN_SETTINGS)
	screen.back_pressed.connect(show_home)
	screen.settings_changed.connect(_on_setting_changed)
	add_child(screen)


func show_themes() -> void:
	Analytics.track_design("nav:themes")
	var screen: ThemesScreen = _swap(SCENE_THEMES, SCREEN_THEMES)
	screen.back_pressed.connect(show_home)
	screen.theme_selected.connect(_on_theme_selected)
	add_child(screen)


func _on_theme_selected(_id: String) -> void:
	if _screen is Level:
		(_screen as Level).apply_theme(state.theme_active)


func shop_overlay_visible() -> bool:
	return shop_overlay != null and is_instance_valid(shop_overlay)


## Z Level sklep otwiera sie jako overlay (runda i tryb zachowane); inaczej pelny ekran.
func show_shop(reason: String = "", from_level: bool = false) -> void:
	if _screen is Level:
		_open_shop_overlay(reason)
		return
	var screen: ShopScreen = _swap(SCENE_SHOP, SCREEN_SHOP)
	screen.reason = reason
	screen.back_pressed.connect(show_level if from_level else show_home)
	add_child(screen)


func _open_shop_overlay(reason: String) -> void:
	if shop_overlay_visible():
		return
	shop_overlay = (load(SCENE_SHOP) as PackedScene).instantiate()
	shop_overlay.set("state", state)
	shop_overlay.reason = reason
	shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_overlay.back_pressed.connect(_close_shop_overlay)
	add_child(shop_overlay)


func _close_shop_overlay() -> void:
	if not shop_overlay_visible():
		shop_overlay = null
		return
	remove_child(shop_overlay)
	shop_overlay.queue_free()
	shop_overlay = null
	if _screen is Level:
		(_screen as Level).refresh_after_shop()


func _on_setting_changed(key: String) -> void:
	Audio.apply_settings(state.settings)
	if key == "locale":
		Locale.apply_setting(str(state.settings.get("locale", "")))
		show_settings()


## Zwalnia biezacy ekran, tworzy nowy ze stanem (przed add_child).
func _swap(path: String, screen_name: String) -> Node:
	_close_popup()
	if shop_overlay_visible():
		remove_child(shop_overlay)
		shop_overlay.queue_free()
	shop_overlay = null
	if _screen != null:
		_save_round()
		remove_child(_screen)
		_screen.queue_free()
	_screen = (load(path) as PackedScene).instantiate()
	_screen_name = screen_name
	_screen.set("state", state)
	if _screen.get("clock") != null:
		_screen.set("clock", clock)
	return _screen
