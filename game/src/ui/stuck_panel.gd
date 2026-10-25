class_name StuckPanel
extends Control
## Overlay "Utknales": odleglosc od celu i opcje (cofnij, boostery, restart, pomin).

signal undo_pressed
signal extra_tube_pressed
signal undo_refill_pressed
signal extra_tube_ad_pressed
signal undo_refill_ad_pressed
signal restart_pressed
signal skip_pressed
signal hint_pressed
signal closed
signal panel_height_changed

enum Pill { FREE, AD, PRICE }

const SAMPLE_DISTANCE: int = 3
const SAMPLE_UNDO_CHARGES: int = 2

const ROW_PAD: int = 22
const ROW_GAP: int = 22
const ROW_MIN_H: int = 100
const TILE_SIZE: int = 74
const PILL_H: int = 66
const AD_SHADOW := Color("#9FB0CF")

var undo_desc_label: Label

var effects_enabled: bool = true

@onready var title_label: Label = $Panel/Box/Head/Titles/TitleLabel
@onready var distance_label: Label = $Panel/Box/Head/Titles/DistanceLabel
@onready var close_button: Button = $Panel/Box/Head/CloseButton
@onready var undo_button: Button = $Panel/Box/UndoButton
@onready var extra_tube_button: Button = $Panel/Box/ExtraTubeButton
@onready var undo_refill_button: Button = $Panel/Box/UndoRefillButton
@onready var hint_button: Button = $Panel/Box/HintButton
@onready var extra_tube_ad_button: Button = $Panel/Box/ExtraTubeAdButton
@onready var undo_refill_ad_button: Button = $Panel/Box/UndoRefillAdButton
@onready var restart_button: Button = $Panel/Box/Bottom/RestartButton
@onready var skip_button: Button = $Panel/Box/Bottom/SkipButton


func _ready() -> void:
	Locale.ensure_installed()
	title_label.text = tr("stuck_title")
	close_button.icon = UiTokens.icon("close")
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.add_theme_constant_override("icon_max_width", UiTokens.TILE_ICON)
	_bottom_button(restart_button, "restart", tr("btn_restart"))
	_bottom_button(skip_button, "skip", tr("btn_skip_ad"))
	var amount: int = int(GameConfig.get_value("undo_refill_amount"))
	var tube_desc: String = tr("stuck_row_tube_desc")
	var refill_title: String = tr("stuck_row_refill") % amount
	var refill_desc: String = tr("stuck_row_refill_desc")
	var undo_labels: Array[Label] = _build_row(
		undo_button, "undo", tr("stuck_row_undo"), "", Pill.FREE, tr("stuck_free")
	)
	undo_desc_label = undo_labels[1]
	_build_row(
		extra_tube_ad_button, "add_tube", tr("stuck_row_tube"), tube_desc, Pill.AD, tr("hud_ad")
	)
	_build_row(
		extra_tube_button,
		"add_tube",
		tr("stuck_row_tube"),
		tube_desc,
		Pill.PRICE,
		str(Economy.extra_tube_cost())
	)
	_build_row(undo_refill_ad_button, "undo", refill_title, refill_desc, Pill.AD, tr("hud_ad"))
	_build_row(
		undo_refill_button,
		"undo",
		refill_title,
		refill_desc,
		Pill.PRICE,
		str(Economy.undo_refill_cost())
	)
	_build_row(
		hint_button,
		"hint",
		tr("stuck_row_hint"),
		tr("stuck_row_hint_desc"),
		Pill.PRICE,
		str(Economy.hint_cost())
	)
	$Panel.minimum_size_changed.connect(func() -> void: panel_height_changed.emit())
	hint_button.pressed.connect(
		func() -> void:
			visible = false
			closed.emit()
			hint_pressed.emit()
	)
	extra_tube_ad_button.pressed.connect(func() -> void: extra_tube_ad_pressed.emit())
	undo_refill_ad_button.pressed.connect(func() -> void: undo_refill_ad_pressed.emit())
	undo_button.pressed.connect(func() -> void: undo_pressed.emit())
	extra_tube_button.pressed.connect(func() -> void: extra_tube_pressed.emit())
	undo_refill_button.pressed.connect(func() -> void: undo_refill_pressed.emit())
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	close_button.pressed.connect(
		func() -> void:
			visible = false
			closed.emit()
	)
	if get_parent() == get_tree().root:
		show_sample()


func _bottom_button(b: Button, icon_name: String, text: String) -> void:
	b.text = text
	b.icon = UiTokens.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 40)


func _row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.CARD_ROW
	sb.set_corner_radius_all(UiTokens.CARD_ROW_RADIUS)
	return sb


func _icon(name: String, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UiTokens.icon(name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(size, size)
	return icon


func _label(text: String, size: int, color: Color, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Zawartosc wiersza "ikona - tytul + opis - akcja" wewnatrz `btn` (tekst przycisku pusty).
## Zwraca [tytul, opis].
func _build_row(
	btn: Button, icon_name: String, title: String, desc: String, kind: Pill, action: String
) -> Array[Label]:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, _row_style())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = ROW_PAD
	row.offset_right = -ROW_PAD
	row.add_theme_constant_override("separation", ROW_GAP)
	btn.add_child(row)
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.CARD_ICON
	sb.set_corner_radius_all(UiTokens.TILE_RADIUS)
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var center := CenterContainer.new()
	center.add_child(_icon(icon_name, UiTokens.TILE_ICON))
	tile.add_child(center)
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var t: Label = _label(title, UiTokens.FONT_MD, UiTokens.TEXT, texts)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var d: Label = _label(desc, UiTokens.FONT_XS, UiTokens.TEXT_MUTED, texts)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_pill(kind, action))
	_ignore_mouse(row)
	row.minimum_size_changed.connect(
		func() -> void:
			btn.custom_minimum_size.y = maxf(ROW_MIN_H, row.get_combined_minimum_size().y + ROW_PAD)
	)
	return [t, d]


func _pill(kind: Pill, text: String) -> PanelContainer:
	var bg: Color = UiTokens.ACCENT
	var fg: Color = UiTokens.ON_ACCENT
	var shadow: Color = UiTokens.ACCENT_SHADOW
	if kind == Pill.FREE:
		bg = UiTokens.PRIMARY
		fg = UiTokens.ON_PRIMARY
		shadow = UiTokens.PRIMARY_SHADOW
	elif kind == Pill.AD:
		bg = UiTokens.TEXT
		fg = UiTokens.BG
		shadow = AD_SHADOW
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(PILL_H)
	sb.border_width_bottom = 6
	sb.border_color = shadow
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.y = PILL_H
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	if kind != Pill.FREE:
		var ic: TextureRect = _icon("video" if kind == Pill.AD else "coin", 32)
		if kind == Pill.AD:
			ic.modulate = fg
		h.add_child(ic)
	_label(text, UiTokens.FONT_SM, fg, h)
	return p


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## Odleglosc gornej krawedzi panelu od dolnej krawedzi ekranu (px, z marginesem); jak LevelComplete.
func panel_height() -> float:
	var min_h: float = $Panel.get_combined_minimum_size().y - $Panel.offset_bottom
	return maxf(-$Panel.offset_top, min_h)


func panel_rect() -> Rect2:
	return $Panel.get_global_rect()


func show_for(round_in: GameRound, allow_skip: bool = true, offers: Dictionary = {}) -> void:
	var dist: int = round_in.moves_to_goal()
	distance_label.text = tr("stuck_distance") % dist if dist >= 0 else tr("stuck_no_solution")
	var charges: int = round_in.counters.undo_charges
	undo_desc_label.text = tr("stuck_row_undo_desc") % charges
	undo_button.disabled = charges <= 0
	undo_button.modulate.a = 0.5 if charges <= 0 else 1.0
	_set_offer_rows(bool(offers.get("extra_tube", false)), bool(offers.get("undo_refill", false)))
	hint_button.visible = dist >= 0
	skip_button.visible = allow_skip and round_in.can_skip() and bool(offers.get("skip", false))
	visible = true
	OverlayFx.enter($Panel, OverlayFx.enabled_for(self, effects_enabled))


## Reklama ma pierwszenstwo przed cena (jak w HUD): jeden wiersz na akcje.
func _set_offer_rows(tube_ad: bool, refill_ad: bool) -> void:
	extra_tube_ad_button.visible = tube_ad
	extra_tube_button.visible = not tube_ad
	undo_refill_ad_button.visible = refill_ad
	undo_refill_button.visible = not refill_ad


func show_sample() -> void:
	show_sample_rows()
	visible = true
	OverlayFx.enter($Panel, OverlayFx.enabled_for(self, effects_enabled))


## Wiersze i dystans jak na makiecie (bez animacji wejscia) - podglad sceny i kadr.
func show_sample_rows() -> void:
	distance_label.text = tr("stuck_distance") % SAMPLE_DISTANCE
	undo_desc_label.text = tr("stuck_row_undo_desc") % SAMPLE_UNDO_CHARGES
	undo_button.disabled = false
	undo_button.modulate.a = 1.0
	skip_button.visible = true
	_set_offer_rows(true, false)
	hint_button.visible = true
