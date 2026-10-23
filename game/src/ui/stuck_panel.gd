class_name StuckPanel
extends Control
## Overlay "Utknales": odleglosc od celu i opcje (cofnij, boostery, restart, pomin).

signal undo_pressed
signal extra_tube_pressed
signal undo_refill_pressed
signal restart_pressed
signal skip_pressed
signal closed

# Teksty literalami do czasu lokalizacji (T-023: podmiana na tr()).
const TEXT_TITLE: String = "Utknąłeś"
const TEXT_DISTANCE: String = "%d ruchów od celu"
const TEXT_NO_SOLUTION: String = "Brak rozwiązania z tego stanu"
const TEXT_UNDO: String = "Cofnij (%d)"
const TEXT_EXTRA_TUBE: String = "+Probówka (%d)"
const TEXT_UNDO_REFILL: String = "+%d cofnięcia (%d)"
const TEXT_RESTART: String = "Restart"
const TEXT_SKIP: String = "Pomiń"
const TEXT_CLOSE: String = "Zamknij"
const SAMPLE_DISTANCE: int = 3

@onready var title_label: Label = $Panel/Box/TitleLabel
@onready var distance_label: Label = $Panel/Box/DistanceLabel
@onready var undo_button: Button = $Panel/Box/UndoButton
@onready var extra_tube_button: Button = $Panel/Box/ExtraTubeButton
@onready var undo_refill_button: Button = $Panel/Box/UndoRefillButton
@onready var restart_button: Button = $Panel/Box/RestartButton
@onready var skip_button: Button = $Panel/Box/SkipButton
@onready var close_button: Button = $Panel/Box/CloseButton


func _ready() -> void:
	title_label.text = TEXT_TITLE
	restart_button.text = TEXT_RESTART
	skip_button.text = TEXT_SKIP
	close_button.text = TEXT_CLOSE
	extra_tube_button.text = TEXT_EXTRA_TUBE % Economy.extra_tube_cost()
	var amount: int = int(GameConfig.get_value("undo_refill_amount", 3))
	undo_refill_button.text = TEXT_UNDO_REFILL % [amount, Economy.undo_refill_cost()]
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


func show_for(round_in: GameRound) -> void:
	var dist: int = round_in.moves_to_goal()
	distance_label.text = TEXT_DISTANCE % dist if dist >= 0 else TEXT_NO_SOLUTION
	var charges: int = round_in.undo_charges()
	undo_button.text = TEXT_UNDO % charges
	undo_button.disabled = charges <= 0
	skip_button.visible = round_in.can_skip()
	visible = true


func show_sample() -> void:
	distance_label.text = TEXT_DISTANCE % SAMPLE_DISTANCE
	undo_button.text = TEXT_UNDO % 0
	undo_button.disabled = true
	skip_button.visible = true
	visible = true
