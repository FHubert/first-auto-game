class_name LevelComplete
extends Control
## Overlay po wygranej: monety, "Idealnie!" i przycisk "Dalej".

signal next_pressed
signal home_pressed

const SAMPLE_COINS: int = 15
const SAMPLE_LEVEL: int = 2

@onready var title_label: Label = $Panel/Box/TitleLabel
@onready var coins_label: Label = $Panel/Box/CoinsLabel
@onready var perfect_label: Label = $Panel/Box/PerfectLabel
@onready var next_button: Button = $Panel/Box/NextButton
@onready var home_button: Button = $Panel/Box/HomeButton


func _ready() -> void:
	Locale.ensure_installed()
	next_button.text = tr("btn_next")
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	home_button.text = tr("btn_menu")
	home_button.pressed.connect(func() -> void: home_pressed.emit())
	if get_parent() == get_tree().root:
		show_result(SAMPLE_COINS, true, SAMPLE_LEVEL)


func show_result(coins: int, perfect: bool, level_no: int, title: String = "") -> void:
	title_label.text = title if title != "" else tr("lc_title") % level_no
	coins_label.text = tr("lc_coins") % coins
	perfect_label.text = tr("lc_perfect")
	perfect_label.visible = perfect
	visible = true
