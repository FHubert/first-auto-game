class_name Hud
extends Control
## Pasek gorny poziomu: numer poziomu, ruchy, cofnij (z licznikiem), restart, pauza.

signal undo_pressed
signal restart_pressed
signal pause_pressed
signal hint_pressed
signal extra_tube_pressed

# Teksty literalami do czasu lokalizacji (T-023: podmiana na tr()).
const TEXT_LEVEL: String = "Poziom %d"
const TEXT_MOVES: String = "Ruchy: %d"
const TEXT_UNDO: String = "Cofnij (%d)"
const TEXT_RESTART: String = "Restart"
const TEXT_PAUSE: String = "Pauza"
const TEXT_HINT: String = "Podpowiedź (%d)"
const TEXT_EXTRA_TUBE: String = "+Probówka (%d)"
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

var _round: GameRound
var _level_no: int = 1


func _ready() -> void:
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
	restart_button = _make_button(buttons, TEXT_RESTART, restart_pressed)
	restart_button.icon = load(ICON_RESTART)
	pause_button = _make_button(buttons, TEXT_PAUSE, pause_pressed)
	var boosters := HBoxContainer.new()
	boosters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(boosters)
	hint_button = _make_button(boosters, TEXT_HINT % Economy.hint_cost(), hint_pressed)
	extra_tube_button = _make_button(
		boosters, TEXT_EXTRA_TUBE % Economy.extra_tube_cost(), extra_tube_pressed
	)
	refresh()


func bind(round_in: GameRound, level_no: int) -> void:
	_round = round_in
	_level_no = level_no
	refresh()


func refresh() -> void:
	if level_label == null:
		return
	level_label.text = TEXT_LEVEL % _level_no
	var moves: int = 0
	var charges: int = 0
	if _round != null:
		moves = _round.moves()
		charges = _round.undo_charges()
	moves_label.text = TEXT_MOVES % moves
	undo_button.text = TEXT_UNDO % charges
	undo_button.disabled = charges <= 0


func set_boosters_visible(v: bool) -> void:
	if hint_button != null:
		hint_button.visible = v
		extra_tube_button.visible = v


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
