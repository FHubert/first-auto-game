class_name Home
extends Control
## Ekran glowny: Graj, monety, streak, pasek do motywu, nawigacja.

signal play_pressed
signal themes_pressed
signal shop_pressed
signal settings_pressed
signal daily_pressed

const UI_THEME: Theme = preload("res://assets/fonts/ui_theme.tres")
const STREAK_BEST_MIN_VISIBLE: int = 2
const GAP: int = 8
const CARD_SEPARATION: int = 16
const PILL_H: int = 94
const PILL_PAD: int = 28
const ICON_SIZE: int = 46
const BADGE_PAD: int = 18
const CARD_ICON_SIZE: int = 104
const PROGRESS_H: int = 26
const TUBE_W: int = 56
const TUBE_H: int = 84
const TUBE_GAP: int = 30
const DAILY_INTRO_SEEN_KEY: String = GameState.SETTING_DAILY_INTRO_SEEN

var state: GameState
var root_margin: MarginContainer
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var play_button: Button
var coins_label: Label
var streak_label: Label
var streak_best_label: Label
var theme_progress: ProgressBar
var theme_label: Label
var themes_button: Button
var shop_button: Button
var settings_button: Button
var daily_card: PanelContainer
var daily_title_label: Label
var daily_new_badge: Label
var daily_status_label: Label
var daily_timer_label: Label
var daily_total_label: Label
var daily_month_label: Label
var daily_button: Button

var _timer_acc: float = 0.0


func _ready() -> void:
	Locale.ensure_installed()
	if state == null:
		state = SaveSystem.load()
	_build()
	refresh()


func refresh() -> void:
	play_button.text = tr("home_play") % state.level
	coins_label.text = str(state.coins)
	streak_label.text = tr("home_streak") % state.streak_days
	streak_best_label.text = tr("home_streak_best") % state.streak_best
	streak_best_label.visible = state.streak_best >= STREAK_BEST_MIN_VISIBLE
	var cost: int = ThemeCatalog.next_theme_cost(state)
	if cost <= 0:
		theme_progress.max_value = 1
		theme_progress.value = 1
		theme_label.text = tr("home_all_themes")
	else:
		theme_progress.max_value = cost
		theme_progress.value = mini(state.coins, cost)
		theme_label.text = tr("home_theme_progress") % [state.coins, cost]
	_refresh_daily()


func _process(delta: float) -> void:
	_timer_acc += delta
	if _timer_acc >= 1.0:
		_timer_acc = 0.0
		_refresh_daily()


func _refresh_daily() -> void:
	if daily_card == null:
		return
	var now: int = int(clock.call())
	var day: int = DailyRewards.utc_day_from_unix(now)
	var unlocked: bool = DailyChallenge.is_unlocked(state)
	var done: bool = DailyChallenge.is_completed_today(state, day)
	if not unlocked:
		var lvl: int = int(GameConfig.get_value("daily_unlock_level"))
		daily_status_label.text = tr("daily_locked") % lvl
	elif done:
		daily_status_label.text = tr("daily_done")
	else:
		daily_status_label.text = tr("daily_available") % DailyChallenge.reward_amount()
	var left: int = DailyChallenge.seconds_to_next(now)
	var hms: String = "%02d:%02d:%02d" % [left / 3600, (left % 3600) / 60, left % 60]
	daily_timer_label.text = tr("daily_next_in") % hms
	daily_total_label.text = tr("home_daily_total") % state.daily_completed_total
	daily_total_label.visible = state.daily_completed_total > 0
	var progress: int = DailyChallenge.month_progress(state, day)
	var goal: int = DailyChallenge.month_goal()
	if progress >= goal:
		daily_month_label.text = tr("home_daily_month_done")
	else:
		daily_month_label.text = tr("home_daily_month") % [progress, goal]
	daily_month_label.visible = unlocked and progress >= 1
	daily_button.text = tr("btn_play_daily")
	daily_button.disabled = not unlocked or done
	daily_new_badge.visible = unlocked and not done and not daily_intro_seen()


## Czy gracz wszedl juz w Poziom dnia z karty (zly typ / brak klucza = false).
func daily_intro_seen() -> bool:
	var v: Variant = state.settings.get(DAILY_INTRO_SEEN_KEY, false)
	return typeof(v) == TYPE_BOOL and v


func _build() -> void:
	theme = UI_THEME
	ScreenHeader.add_backdrop(self)
	root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		root_margin.add_theme_constant_override("margin_" + side, UiTokens.SCREEN_PAD)
	add_child(root_margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	root_margin.add_child(box)
	_build_top(box)
	box.add_child(_spacer())
	var logo := Label.new()
	logo.text = "Vialo"
	logo.add_theme_font_size_override("font_size", UiTokens.FONT_HERO)
	logo.add_theme_color_override("font_outline_color", UiTokens.TEXT)
	logo.add_theme_constant_override("outline_size", 4)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(logo)
	box.add_child(TubesMini.new(_palette()))
	box.add_child(_spacer())
	play_button = _button(box, play_pressed, &"ButtonPrimary")
	play_button.custom_minimum_size.y = UiTokens.PLAY_BTN
	play_button.icon = UiTokens.icon("play")
	play_button.add_theme_constant_override("icon_max_width", 48)
	_build_daily_card(box)
	_build_theme_bar(box)
	box.add_child(_spacer())
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 0)
	box.add_child(nav)
	themes_button = _nav(nav, "palette", "btn_themes", themes_pressed)
	shop_button = _nav(nav, "bag", "btn_shop", shop_pressed)
	settings_button = _nav(nav, "gear", "btn_settings", settings_pressed)


func _palette() -> Array[Color]:
	var liquids: Array = ThemeCatalog.theme(state.theme_active).get("liquids", [])
	var out: Array[Color] = []
	for c: Variant in liquids:
		out.append(Color(str(c)))
	return out


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func _pill(parent: Control) -> HBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.BG_DEEP
	sb.set_corner_radius_all(PILL_H)
	sb.content_margin_left = PILL_PAD
	sb.content_margin_right = PILL_PAD
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.y = PILL_H
	parent.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	return row


func _icon(name: String, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UiTokens.icon(name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size, size)
	return icon


func _label(parent: Control, variation: StringName = &"") -> Label:
	var l := Label.new()
	if variation != &"":
		l.theme_type_variation = variation
	parent.add_child(l)
	return l


func _build_top(box: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	box.add_child(top)
	var coin_row := _pill(top)
	coin_row.add_child(_icon("coin", ICON_SIZE))
	coins_label = _label(coin_row)
	coins_label.add_theme_font_size_override("font_size", UiTokens.FONT_BTN)
	top.add_child(_spacer_h())
	var streak_row := _pill(top)
	streak_row.add_child(_icon("streak", ICON_SIZE))
	streak_label = _label(streak_row)
	streak_label.add_theme_font_size_override("font_size", UiTokens.FONT_BTN)
	streak_best_label = _label(streak_row, &"LabelCaption")


func _spacer_h() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _build_daily_card(parent: Control) -> void:
	daily_card = PanelContainer.new()
	daily_card.theme_type_variation = &"Card"
	parent.add_child(daily_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", CARD_SEPARATION)
	daily_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	col.add_child(head)
	head.add_child(_card_icon())
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 16)
	info.add_child(title_row)
	daily_title_label = _label(title_row, &"LabelTitle")
	daily_title_label.text = tr("daily_challenge_title")
	daily_title_label.add_theme_font_size_override("font_size", UiTokens.FONT_BTN)
	daily_new_badge = _label(title_row)
	daily_new_badge.text = tr("home_daily_new")
	daily_new_badge.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	daily_new_badge.add_theme_color_override("font_color", UiTokens.ON_ACCENT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.ACCENT
	sb.set_corner_radius_all(UiTokens.TOUCH_MIN)
	sb.content_margin_left = BADGE_PAD
	sb.content_margin_right = BADGE_PAD
	daily_new_badge.add_theme_stylebox_override("normal", sb)
	daily_new_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	daily_status_label = _label(info)
	daily_status_label.add_theme_font_size_override("font_size", UiTokens.FONT_BTN)
	daily_status_label.add_theme_color_override("font_color", UiTokens.ACCENT)
	var meta := HFlowContainer.new()
	meta.add_theme_constant_override("h_separation", GAP)
	meta.add_theme_constant_override("v_separation", 0)
	info.add_child(meta)
	daily_timer_label = _label(meta, &"LabelCaption")
	daily_month_label = _label(meta, &"LabelCaption")
	daily_total_label = _label(meta, &"LabelCaption")
	daily_button = _button(col, daily_pressed, &"ButtonAccent")


func _card_icon() -> PanelContainer:
	var c := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.CARD_ICON
	sb.set_corner_radius_all(UiTokens.TILE_RADIUS)
	c.add_theme_stylebox_override("panel", sb)
	c.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var center := CenterContainer.new()
	c.add_child(center)
	center.add_child(_icon("calendar", int(CARD_ICON_SIZE * 0.6)))
	return c


func _build_theme_bar(box: VBoxContainer) -> void:
	theme_label = _label(box, &"LabelCaption")
	theme_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	theme_progress = ProgressBar.new()
	theme_progress.show_percentage = false
	theme_progress.custom_minimum_size = Vector2(0, PROGRESS_H)
	var track := StyleBoxFlat.new()
	track.bg_color = UiTokens.BG_DEEP
	track.set_corner_radius_all(PROGRESS_H)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTokens.ACCENT
	fill.set_corner_radius_all(PROGRESS_H)
	theme_progress.add_theme_stylebox_override("background", track)
	theme_progress.add_theme_stylebox_override("fill", fill)
	box.add_child(theme_progress)


func _nav(row: HBoxContainer, icon_name: String, key: String, sig: Signal) -> Button:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 12)
	row.add_child(cell)
	var b := _button(cell, sig, &"ButtonNav")
	b.icon = UiTokens.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 64)
	b.custom_minimum_size = Vector2(UiTokens.NAV_BTN, UiTokens.NAV_BTN)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = tr(key)
	var l := _label(cell)
	l.text = tr(key)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	l.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	return b


func _button(parent: Control, sig: Signal, variation: StringName) -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, UiTokens.BTN_H)
	b.pressed.connect(func() -> void: sig.emit())
	parent.add_child(b)
	return b


## Miniatura 5 probowek (czysta grafika, kolory palety aktywnego motywu).
class TubesMini:
	extends Control

	var colors: Array[Color] = []

	func _init(palette: Array[Color]) -> void:
		colors = palette
		custom_minimum_size = Vector2(0, TUBE_H + 24)

	func _draw() -> void:
		var total: float = 5 * TUBE_W + 4 * TUBE_GAP
		var x0: float = (size.x - total) / 2.0
		var fills: Array = [[0, 6], [2], [5, 4, 7, 1], [5], [3]]
		var fill_h: Array = [0.45, 0.8, 1.0, 0.8, 0.4]
		for i: int in 5:
			var top: float = 30.0 if i == 2 else 0.0 + 14.0
			var r := Rect2(x0 + i * (TUBE_W + TUBE_GAP), top, TUBE_W, TUBE_H - top + 14.0)
			draw_rect(r, UiTokens.CARD_ROW, true)
			var layers: Array = fills[i]
			var lh: float = r.size.y * float(fill_h[i]) / layers.size()
			for j: int in layers.size():
				if colors.is_empty():
					break
				var c: Color = colors[int(layers[j]) % colors.size()]
				draw_rect(Rect2(r.position.x + 6, r.end.y - 6 - lh * (j + 1), TUBE_W - 12, lh), c)
			draw_rect(r, UiTokens.TEXT_SECTION, false, 4.0)
			draw_rect(
				Rect2(r.position.x - 6, r.position.y - 6, TUBE_W + 12, 10), UiTokens.TEXT_SECTION
			)
