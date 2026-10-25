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
const NOTIF_IDS: Dictionary = {"streak": 1, "daily": 2, "comeback": 3}
const NOTIF_KIND_STREAK: String = "streak"

var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var notifications: NotificationProvider = NotificationProvider.new()
var tz_offset: Callable = func() -> int: return int(Time.get_time_zone_from_system()["bias"])
var effects_enabled: bool = true
var shop_overlay: ShopScreen
## Generacja poziomu kampanii w tle od wejscia na Home (T-167); null = brak.
var home_prefetch: LevelPrefetch
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
		if SaveSystem.last_load_source in ["backup", "fresh"]:
			Analytics.track_design("save:recovered:%s" % SaveSystem.last_load_source)
	_cancel_notifications()
	Purchases.bind_state(state)
	Locale.ensure_installed()
	Locale.apply_setting(str(state.settings.get("locale", "")))
	Audio.apply_settings(state.settings)
	Audio.play_music()
	if bool(state.settings.get(GameState.SETTING_TUTORIAL_DONE, false)):
		show_home()
	else:
		show_level()


func _exit_tree() -> void:
	_drop_home_prefetch()
	if Ads.ad_about_to_show.is_connected(_on_ad_about_to_show):
		Ads.ad_about_to_show.disconnect(_on_ad_about_to_show)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_round()
		_schedule_notifications()
		track_session_end()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_cancel_notifications()
		track_session_start()
		_on_focus_in()


## Powrot z tla: Level nie liczy czasu w tle; Home odswieza sie i moze pokazac popup nagrody.
func _on_focus_in() -> void:
	if state == null:
		return
	if _screen is Level:
		(_screen as Level).resume_clock()
	elif _screen is Home:
		var home := _screen as Home
		home.refresh()
		_maybe_show_daily_popup(home)


## Planuje lokalne notyfikacje przy wyjsciu w tlo (provider niedostepny = zero wywolan).
func _schedule_notifications() -> void:
	if state == null or not notifications.is_available():
		return
	notifications.cancel_all()
	if not NotificationPermission.allows_scheduling(notifications.permission_status()):
		return
	var now: int = int(clock.call())
	for entry: Dictionary in NotificationPlanner.plan(now, int(tz_offset.call()), state):
		var kind: String = str(entry["kind"])
		var body: String = tr(str(entry["body_key"]))
		if kind == NOTIF_KIND_STREAK:
			body = body % state.streak_days
		notifications.schedule(
			int(NOTIF_IDS[kind]), int(entry["fire_unix"]), tr(str(entry["title_key"])), body
		)
		Analytics.track_design("notif:scheduled:%s" % kind)


## Jedna prosba o zgode systemowa przy wejsciu na Home (T-223). Flaga zapisywana PRZED
## prosba: zabicie aplikacji w trakcie dialogu nie pyta drugi raz.
func _maybe_request_notif_permission() -> void:
	if state == null or not notifications.is_available():
		return
	if not NotificationPermission.should_ask(state, notifications.permission_status()):
		return
	state.settings[GameState.SETTING_NOTIF_PERMISSION_ASKED] = true
	SaveSystem.save(state)
	notifications.request_permission(_on_notif_permission_result)


func _on_notif_permission_result(status: String) -> void:
	if status in [NotificationProvider.PERMISSION_GRANTED, NotificationProvider.PERMISSION_DENIED]:
		Analytics.track_design("notif:permission:%s" % status)


func _cancel_notifications() -> void:
	if notifications.is_available():
		notifications.cancel_all()


func _on_ad_about_to_show(_kind: String) -> void:
	_save_round()


## Zapisuje biezaca runde (jesli ekran to Level) do round_in_progress.
func _save_round() -> void:
	if state == null or not _screen is Level:
		return
	state.round_in_progress = (_screen as Level).snapshot()
	SaveSystem.save(state)


## Odrzuca niepusty snapshot rundy: raz loguje Fail + level:fail:abandon i czysci pole.
func _discard_snapshot() -> void:
	var snap: Dictionary = state.round_in_progress
	if snap.is_empty():
		return
	var lvl: int = _snap_int(snap, "level_no")
	var day: int = _snap_int(snap, "utc_day")
	var mode_in: String = str(snap.get("mode", ""))
	Analytics.track_progression("Fail", mode_in, Level.level_id_for(mode_in, lvl, day))
	Analytics.track_design("level:fail:abandon")
	if mode_in == Level.MODE_CAMPAIGN:
		var rd: Variant = snap.get("round")
		var restarts: int = 0
		if typeof(rd) == TYPE_DICTIONARY:
			restarts = maxi(_snap_int(rd as Dictionary, "restarts"), 0)
		Analytics.track_design(
			"level:fail:abandon:" + LevelBrackets.id_for(lvl), float(restarts + 1)
		)
	state.round_in_progress = {}


func _snap_int(snap: Dictionary, key: String) -> int:
	var v: Variant = GameState._as_int(snap.get(key))
	return 0 if v == null else int(v)


func _today() -> int:
	return DailyRewards.utc_day_from_unix(int(clock.call()))


## Starts a focus session once (no duplicate after _ready + FOCUS_IN).
func track_session_start() -> void:
	if _session_open:
		return
	_session_open = true
	_session_start_s = float(clock.call())
	Analytics.track_design("session:start")
	Analytics.track_design("config:variant:%s" % str(GameConfig.get_value("remote_config_variant")))


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
	home.daily_pressed.connect(_on_home_daily_pressed)
	add_child(home)
	_request_home_prefetch()
	_maybe_show_daily_popup(home)
	_maybe_request_notif_permission()


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
	var pf: LevelPrefetch = home_prefetch
	home_prefetch = null  # wlasnosc przechodzi na Level (cancel_all w jego _exit_tree)
	var level: Level = _swap(SCENE_LEVEL, SCREEN_LEVEL)
	if pf != null:
		level.prefetch = pf  # takze przy wznowieniu: Level i tak sprzata instancje
	level.clock = clock
	level.effects_enabled = effects_enabled
	level.pause_requested.connect(show_home)
	level.home_requested.connect(show_home)
	level.shop_requested.connect(func(r: String) -> void: show_shop(r, true))
	var snap: Dictionary = state.round_in_progress
	if str(snap.get("mode", "")) == Level.MODE_CAMPAIGN:
		level.autoload_level = false  # resume/load_level ustawi runde
		add_child(level)
		if not level.resume(snap, _today()):
			_discard_snapshot()
			level.load_level(state.level, state.theme_active)
		return
	_discard_snapshot()
	add_child(level)


func _on_home_daily_pressed() -> void:
	state.settings[Home.DAILY_INTRO_SEEN_KEY] = true
	SaveSystem.save(state)
	Analytics.track_design("nav:daily")
	show_daily_level()


func show_daily_level() -> void:
	var level: Level = _swap(SCENE_LEVEL, SCREEN_LEVEL)
	level.clock = clock
	level.effects_enabled = effects_enabled
	level.pause_requested.connect(show_home)
	level.home_requested.connect(show_home)
	level.shop_requested.connect(func(r: String) -> void: show_shop(r, true))
	level.autoload_level = false  # start_daily/resume ustawi runde
	add_child(level)
	if str(state.round_in_progress.get("mode", "")) == Level.MODE_DAILY:
		if level.resume(state.round_in_progress, _today()):
			return
	_discard_snapshot()
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
	if key == GameState.SETTING_NOTIFICATIONS_ON and not bool(state.settings.get(key, true)):
		_cancel_notifications()
	if key == "locale":
		Locale.apply_setting(str(state.settings.get("locale", "")))
		show_settings()


## Wznawialna runda kampanii nie generuje poziomu, wiec bez zadania.
func _request_home_prefetch() -> void:
	_drop_home_prefetch()
	if str(state.round_in_progress.get("mode", "")) == Level.MODE_CAMPAIGN:
		return
	home_prefetch = LevelPrefetch.new()
	home_prefetch.request(int(GameConfig.get_value("campaign_seed")), state.level)


func _drop_home_prefetch() -> void:
	if home_prefetch != null:
		home_prefetch.cancel_all()
	home_prefetch = null


## Zwalnia biezacy ekran, tworzy nowy ze stanem (przed add_child).
func _swap(path: String, screen_name: String) -> Node:
	_drop_home_prefetch()
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
