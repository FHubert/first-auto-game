class_name Hud
extends Control
## Pasek gorny poziomu: numer poziomu, ruchy, cofnij (z licznikiem), restart, pauza.

signal undo_pressed
signal restart_pressed
signal pause_pressed
signal hint_pressed
signal extra_tube_pressed
signal extra_tube_ad_pressed
signal undo_refill_ad_pressed

const ICON_UNDO: String = "res://assets/sprites/ui/icon_undo.svg"
const ICON_RESTART: String = "res://assets/sprites/ui/icon_restart.svg"
const BAR_HEIGHT: float = 230.0
const FONT_SIZE: int = 28

var level_label: Label
var moves_label: Label
var undo_button: Button
var restart_button: Button
var pause_button: Button
var hint_button: Button
var extra_tube_button: Button
var extra_tube_ad_button: Button
var undo_refill_ad_button: Button

var _round: GameRound
var _level_no: int = 1
var _title: String = ""
var _boosters_visible: bool = true


func _ready() -> void:
	Locale.ensure_installed()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = BAR_HEIGHT
	var rows := VBoxContainer.new()
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)
	var info := HBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(info)
	level_label = _make_label(info)
	moves_label = _make_label(info)
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(buttons)
	undo_button = _make_button(buttons, "", undo_pressed)
	undo_button.icon = load(ICON_UNDO)
	restart_button = _make_button(buttons, tr("btn_restart"), restart_pressed)
	restart_button.icon = load(ICON_RESTART)
	pause_button = _make_button(buttons, tr("btn_pause"), pause_pressed)
	var boosters := HBoxContainer.new()
	boosters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(boosters)
	hint_button = _make_button(boosters, tr("btn_hint") % Economy.hint_cost(), hint_pressed)
	extra_tube_button = _make_button(
		boosters, tr("btn_extra_tube") % Economy.extra_tube_cost(), extra_tube_pressed
	)
	extra_tube_ad_button = _make_button(boosters, tr("btn_extra_tube_ad"), extra_tube_ad_pressed)
	var amount: int = int(GameConfig.get_value("undo_refill_amount"))
	undo_refill_ad_button = _make_button(
		boosters, tr("btn_undo_refill_ad") % amount, undo_refill_ad_pressed
	)
	extra_tube_ad_button.visible = false
	undo_refill_ad_button.visible = false
	refresh()


func bind(round_in: GameRound, level_no: int) -> void:
	_round = round_in
	_level_no = level_no
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
	var charges: int = 0
	if _round != null:
		moves = _round.moves()
		charges = _round.undo_charges()
	moves_label.text = tr("hud_moves") % moves
	undo_button.text = tr("btn_undo") % charges
	undo_button.disabled = charges <= 0


func set_boosters_visible(v: bool) -> void:
	_boosters_visible = v
	if hint_button != null:
		hint_button.visible = v
		extra_tube_button.visible = v
		if not v:
			extra_tube_ad_button.visible = false
			undo_refill_ad_button.visible = false


func set_ad_offers(extra_tube: bool, undo_refill: bool) -> void:
	if extra_tube_ad_button == null:
		return
	extra_tube_ad_button.visible = _boosters_visible and extra_tube
	undo_refill_ad_button.visible = _boosters_visible and undo_refill


func _make_label(parent: Control) -> Label:
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(l)
	return l


func _make_button(parent: Control, text_in: String, sig: Signal) -> Button:
	var b := Button.new()
	b.text = text_in
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.expand_icon = true
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(func() -> void: sig.emit())
	parent.add_child(b)
	return b
