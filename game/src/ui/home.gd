class_name Home
extends Control
## Ekran glowny: Graj, monety, streak, pasek do motywu, nawigacja.

signal play_pressed
signal themes_pressed
signal shop_pressed
signal settings_pressed

const ICON_COIN: String = "res://assets/sprites/ui/icon_coin.svg"
const ICON_STREAK: String = "res://assets/sprites/ui/icon_streak.svg"
const FONT_SIZE: int = 32
const BUTTON_HEIGHT: int = 100
const MARGIN: int = 48

var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var play_button: Button
var coins_label: Label
var streak_label: Label
var theme_progress: ProgressBar
var theme_label: Label
var themes_button: Button
var shop_button: Button
var settings_button: Button


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
	var cost: int = Economy.theme_cost(state.themes_owned.size())
	theme_progress.max_value = cost
	theme_progress.value = mini(state.coins, cost)
	theme_label.text = tr("home_theme_progress") % [state.coins, cost]


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)
	coins_label = _icon_label(box, ICON_COIN)
	streak_label = _icon_label(box, ICON_STREAK)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	play_button = _button(box, play_pressed)
	theme_label = Label.new()
	theme_label.add_theme_font_size_override("font_size", FONT_SIZE)
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(theme_label)
	theme_progress = ProgressBar.new()
	theme_progress.show_percentage = false
	theme_progress.custom_minimum_size = Vector2(0, 32)
	box.add_child(theme_progress)
	themes_button = _button(box, themes_pressed)
	themes_button.text = tr("btn_themes")
	shop_button = _button(box, shop_pressed)
	shop_button.text = tr("btn_shop")
	settings_button = _button(box, settings_pressed)
	settings_button.text = tr("btn_settings")


func _icon_label(parent: Control, icon_path: String) -> Label:
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(48, 48)
	row.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(label)
	parent.add_child(row)
	return label


func _button(parent: Control, sig: Signal) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(func() -> void: sig.emit())
	parent.add_child(b)
	return b
