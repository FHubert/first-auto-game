class_name LevelComplete
extends Control
## Overlay po wygranej: monety, "Idealnie!" i przycisk "Dalej".

signal next_pressed

# Teksty literalami do czasu lokalizacji (T-023: podmiana na tr()).
const TEXT_TITLE: String = "Poziom %d ukonczony!"
const TEXT_COINS: String = "+%d monet"
const TEXT_PERFECT: String = "Idealnie!"
const TEXT_NEXT: String = "Dalej"
const SAMPLE_COINS: int = 15
const SAMPLE_LEVEL: int = 2

@onready var title_label: Label = $Panel/Box/TitleLabel
@onready var coins_label: Label = $Panel/Box/CoinsLabel
@onready var perfect_label: Label = $Panel/Box/PerfectLabel
@onready var next_button: Button = $Panel/Box/NextButton


func _ready() -> void:
	next_button.text = TEXT_NEXT
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	if get_parent() == get_tree().root:
		show_result(SAMPLE_COINS, true, SAMPLE_LEVEL)


func show_result(coins: int, perfect: bool, level_no: int) -> void:
	title_label.text = TEXT_TITLE % level_no
	coins_label.text = TEXT_COINS % coins
	perfect_label.text = TEXT_PERFECT
	perfect_label.visible = perfect
	visible = true
