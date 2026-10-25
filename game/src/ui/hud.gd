class_name Hud
extends Control
## HUD planszy (UI v2, T-230): gorny pasek (pauza, tytul + ruchy/cel, pill monet)
## i dolny pasek 4 przyciskow-ikon (cofnij, od nowa, podpowiedz, +probowka).

signal undo_pressed
signal restart_pressed
signal pause_pressed
signal hint_pressed
signal extra_tube_pressed
signal extra_tube_ad_pressed
signal undo_refill_ad_pressed

const BADGE_OVERHANG: int = 12
const BADGE_BORDER: int = 4
const BAR_TOP_PAD: int = 18
const CAPTION_GAP: int = 11

var top_bar: Control
var bottom_bar: Control
var level_label: Label
var moves_label: Label
var coins_label: Label
var pause_button: Button
var undo_button: Button
var restart_button: Button
var hint_button: Button
var extra_tube_button: Button
var undo_badge: Label
var hint_cost_label: Label
var extra_tube_cost_label: Label
var extra_tube_ad_button: TextureRect
var undo_refill_ad_button: TextureRect
var effects_enabled: bool = true

var _backdrops: Array[ColorRect] = []
var _round: GameRound
var _state: GameState
var _level_no: int = 1
var _title: String = ""
var _boosters_visible: bool = true
var _hint_column: Control
var _tube_column: Control
var _hint_coin: TextureRect
var _tube_coin: TextureRect
var _tube_ad_label: Label


func _ready() -> void:
	Locale.ensure_installed()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_top()
	_build_bottom()
	for b: Button in [pause_button, undo_button, restart_button, hint_button, extra_tube_button]:
		UiFx.attach_press(b, func() -> bool: return effects_enabled)
	refresh()


func bind(round_in: GameRound, level_no: int, state_in: GameState = null) -> void:
	_round = round_in
	_level_no = level_no
	_state = state_in
	refresh()


## Pusty tekst przywraca domyslne "Poziom N".
func set_title(text: String) -> void:
	_title = text
	refresh()


func refresh() -> void:
	if level_label == null:
		return
	level_label.text = _title if _title != "" else tr("hud_level") % _level_no
	var moves: int = 0
	var goal: int = 0
	var charges: int = 0
	if _round != null:
		moves = _round.moves()
		goal = _round.min_moves()
		charges = _round.counters.undo_charges
	moves_label.text = tr("hud_moves_goal") % [moves, goal]
	if _state != null:
		coins_label.text = str(_state.coins)
	var badge_text: String = str(charges)
	var changed: bool = undo_badge.text != badge_text
	undo_badge.text = badge_text
	if changed:
		UiFx.pop(undo_badge, effects_enabled)
	_update_undo_state(charges)


## T-222: podpowiedz liczy sie w tle - przycisk nieaktywny z "…" do wyniku.
func set_hint_pending(pending: bool) -> void:
	if hint_button == null:
		return
	hint_button.disabled = pending
	hint_cost_label.text = "…" if pending else str(Economy.hint_cost())
	_hint_coin.visible = not pending


func start_hint_nudge() -> void:
	if hint_button != null and hint_button.visible:
		UiFx.pulse(hint_button, effects_enabled)


func stop_hint_nudge() -> void:
	if hint_button != null:
		UiFx.stop_pulse(hint_button)


func set_boosters_visible(v: bool) -> void:
	_boosters_visible = v
	if hint_button != null:
		_hint_column.visible = v
		_tube_column.visible = v
		hint_button.visible = v
		extra_tube_button.visible = v
		if not v:
			set_ad_offers(false, false)


func set_ad_offers(extra_tube: bool, undo_refill: bool) -> void:
	if extra_tube_ad_button == null:
		return
	var tube_ad: bool = _boosters_visible and extra_tube
	extra_tube_ad_button.visible = tube_ad
	_tube_ad_label.visible = tube_ad
	extra_tube_cost_label.visible = not tube_ad
	_tube_coin.visible = not tube_ad
	undo_refill_ad_button.visible = _boosters_visible and undo_refill
	var charges: int = _round.counters.undo_charges if _round != null else 0
	_update_undo_state(charges)


func _update_undo_state(charges: int) -> void:
	if undo_button == null:
		return
	undo_button.disabled = charges <= 0 and not undo_refill_ad_button.visible
	undo_badge.visible = not undo_refill_ad_button.visible


## Kolor tla paskow = tlo motywu planszy.
func set_backdrop(color: Color) -> void:
	for bg in _backdrops:
		bg.color = color


func _build_top() -> void:
	top_bar = Control.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = UiTokens.HUD_TOP_H
	add_child(top_bar)
	_backdrop(top_bar)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiTokens.SCREEN_PAD
	row.offset_right = -UiTokens.SCREEN_PAD
	top_bar.add_child(row)
	pause_button = Button.new()
	pause_button.theme_type_variation = &"ButtonIcon"
	pause_button.icon = UiTokens.icon("pause")
	pause_button.custom_minimum_size = Vector2(UiTokens.BTN_ICON, UiTokens.BTN_ICON)
	pause_button.add_theme_constant_override("icon_max_width", ScreenHeader.ICON_MAX)
	pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(pause_button)
	var mid := VBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	row.add_child(mid)
	level_label = Label.new()
	level_label.theme_type_variation = &"LabelTitle"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(level_label)
	moves_label = Label.new()
	moves_label.theme_type_variation = &"LabelCaption"
	moves_label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(moves_label)
	coins_label = ScreenHeader.coins_pill(row, UiTokens.FONT_MD)
	coins_label.get_parent().get_parent().size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_bottom() -> void:
	bottom_bar = Control.new()
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -UiTokens.HUD_BOTTOM_H
	add_child(bottom_bar)
	_backdrop(bottom_bar)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_top = BAR_TOP_PAD
	row.offset_left = UiTokens.SCREEN_PAD
	row.offset_right = -UiTokens.SCREEN_PAD
	bottom_bar.add_child(row)
	var undo_col := _column(row)
	undo_button = _icon_button(undo_col, "undo", _on_undo_pressed)
	_caption(undo_col, tr("btn_undo_short"))
	_build_badges()
	var restart_col := _column(row)
	restart_button = _icon_button(restart_col, "restart", func() -> void: restart_pressed.emit())
	_caption(restart_col, tr("btn_restart"))
	_hint_column = _column(row)
	hint_button = _icon_button(_hint_column, "hint", func() -> void: hint_pressed.emit())
	var hint_row := _cost_row(_hint_column)
	_hint_coin = hint_row[0]
	hint_cost_label = hint_row[1]
	hint_cost_label.text = str(Economy.hint_cost())
	_tube_column = _column(row)
	extra_tube_button = _icon_button(_tube_column, "add_tube", _on_extra_tube_pressed)
	var tube_row := _cost_row(_tube_column)
	_tube_coin = tube_row[0]
	extra_tube_cost_label = tube_row[1]
	extra_tube_cost_label.text = str(Economy.extra_tube_cost())
	var ad_row := tube_row[2] as HBoxContainer
	extra_tube_ad_button = _video_icon()
	ad_row.add_child(extra_tube_ad_button)
	_tube_ad_label = Label.new()
	_tube_ad_label.text = tr("hud_ad")
	_style_cost(_tube_ad_label)
	ad_row.add_child(_tube_ad_label)
	extra_tube_ad_button.visible = false
	_tube_ad_label.visible = false


## Tlo paska (plansza rysuje wlasne tlo tylko we wlasnym prostokacie).
func _backdrop(bar: Control) -> void:
	var bg := ColorRect.new()
	bg.color = UiTokens.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)
	_backdrops.append(bg)


func _column(parent: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", CAPTION_GAP)
	parent.add_child(col)
	return col


func _icon_button(col: Control, icon_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"ButtonHud"
	b.icon = UiTokens.icon(icon_name)
	b.custom_minimum_size = Vector2(UiTokens.HUD_BTN, UiTokens.HUD_BTN)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", UiTokens.HUD_ICON)
	b.pressed.connect(on_press)
	col.add_child(b)
	return b


func _caption(col: Control, text_in: String) -> Label:
	var l := Label.new()
	l.text = text_in
	l.theme_type_variation = &"LabelCaption"
	l.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	l.add_theme_color_override("font_color", UiTokens.TEXT_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return l


func _style_cost(l: Label) -> void:
	l.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	l.add_theme_color_override("font_color", UiTokens.ACCENT)


## Zwraca [moneta, etykieta kosztu, wiersz].
func _cost_row(col: Control) -> Array:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 6)
	col.add_child(r)
	var coin := TextureRect.new()
	coin.texture = UiTokens.icon("coin")
	coin.custom_minimum_size = Vector2(UiTokens.HUD_COST_ICON, UiTokens.HUD_COST_ICON)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(coin)
	var l := Label.new()
	_style_cost(l)
	r.add_child(l)
	return [coin, l, r]


func _video_icon() -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTokens.icon("video")
	t.modulate = UiTokens.ACCENT
	t.custom_minimum_size = Vector2(UiTokens.HUD_COST_ICON, UiTokens.HUD_COST_ICON)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _build_badges() -> void:
	undo_badge = Label.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.ACCENT
	sb.border_color = UiTokens.BG
	sb.set_border_width_all(BADGE_BORDER)
	sb.set_corner_radius_all(UiTokens.HUD_BADGE / 2)
	undo_badge.add_theme_stylebox_override("normal", sb)
	undo_badge.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	undo_badge.add_theme_color_override("font_color", UiTokens.ON_ACCENT)
	undo_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	undo_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_corner(undo_badge)
	undo_refill_ad_button = _video_icon()
	_corner(undo_refill_ad_button)
	undo_refill_ad_button.visible = false


## Znaczek w prawym gornym rogu przycisku Cofnij.
func _corner(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	c.offset_left = BADGE_OVERHANG - UiTokens.HUD_BADGE
	c.offset_right = BADGE_OVERHANG
	c.offset_top = -BADGE_OVERHANG
	c.offset_bottom = UiTokens.HUD_BADGE - BADGE_OVERHANG
	undo_button.add_child(c)


func _on_undo_pressed() -> void:
	if undo_refill_ad_button.visible:
		undo_refill_ad_pressed.emit()
	else:
		undo_pressed.emit()


func _on_extra_tube_pressed() -> void:
	if extra_tube_ad_button.visible:
		extra_tube_ad_pressed.emit()
	else:
		extra_tube_pressed.emit()
