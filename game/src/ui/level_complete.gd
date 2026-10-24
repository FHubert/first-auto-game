class_name LevelComplete
extends Control
## Overlay po wygranej: monety, "Idealnie!" i przycisk "Dalej".

signal next_pressed
signal home_pressed
signal double_pressed

const SAMPLE_COINS: int = 15
const SAMPLE_LEVEL: int = 2

@onready var title_label: Label = $Panel/Box/TitleLabel
@onready var coins_label: Label = $Panel/Box/CoinsLabel
@onready var perfect_label: Label = $Panel/Box/PerfectLabel
@onready var progress_label: Label = $Panel/Box/ProgressLabel
@onready var double_button: Button = $Panel/Box/DoubleButton
@onready var next_button: Button = $Panel/Box/Buttons/NextButton
@onready var home_button: Button = $Panel/Box/Buttons/HomeButton


## Wysokosc panelu liczona od dolnej krawedzi (px, z marginesem) - plansza ma sie zmiescic nad nim.
func panel_height() -> float:
	return -$Panel.offset_top


func panel_rect() -> Rect2:
	return $Panel.get_global_rect()


func _ready() -> void:
	Locale.ensure_installed()
	next_button.text = tr("btn_next")
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	double_button.pressed.connect(func() -> void: double_pressed.emit())
	home_button.text = tr("btn_menu")
	home_button.pressed.connect(func() -> void: home_pressed.emit())
	if get_parent() == get_tree().root:
		show_result(SAMPLE_COINS, true, SAMPLE_LEVEL, "", {"key": "lc_new_color", "args": []})
		set_double_offer(SAMPLE_COINS, true)


## Jeden komunikat po wygranej kampanii: "+1 kolor" (priorytet) albo postep do motywu.
## `level_no` = numer ukonczonego poziomu. Zwraca {"key", "args"} albo {}.
static func progress_message(level_no: int, game_mode: String, state: GameState) -> Dictionary:
	if game_mode != Level.MODE_CAMPAIGN:
		return {}
	var gen := ContentGenerator.new()
	if int(gen.level_params(level_no + 1)["colors"]) > int(gen.level_params(level_no)["colors"]):
		return {"key": "lc_new_color", "args": []}
	if ThemeCatalog.next_theme_id(state) != "":
		return {
			"key": "lc_theme_progress", "args": [state.coins, ThemeCatalog.next_theme_cost(state)]
		}
	return {}


func show_result(
	coins: int, perfect: bool, level_no: int, title: String = "", progress: Dictionary = {}
) -> void:
	title_label.text = title if title != "" else tr("lc_title") % level_no
	coins_label.text = tr("lc_coins") % coins
	perfect_label.text = tr("lc_perfect")
	perfect_label.visible = perfect
	progress_label.visible = not progress.is_empty()
	if not progress.is_empty():
		var args: Array = progress.get("args", [])
		progress_label.text = (
			tr(str(progress["key"])) % args if not args.is_empty() else tr(str(progress["key"]))
		)
	double_button.visible = false
	visible = true


func set_double_offer(bonus: int, offered: bool) -> void:
	double_button.text = tr("btn_double") % bonus
	double_button.visible = offered and bonus > 0
