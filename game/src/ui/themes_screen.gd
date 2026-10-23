class_name ThemesScreen
extends Control
## Ekran motywow: podglad, cena, zakup, aktywacja.

signal back_pressed
signal theme_selected(id: String)
signal theme_bought(id: String)

const FONT_SIZE: int = 32
const MARGIN: int = 48
const PREVIEW_SIZE: Vector2 = Vector2(220, 140)

var state: GameState
var coins_label: Label
var back_button: Button
## id -> {"panel": Control, "button": Button}
var cards: Dictionary = {}


func _ready() -> void:
	Locale.ensure_installed()
	if state == null:
		state = SaveSystem.load()
	_build()
	refresh()


func card_button(id: String) -> Button:
	return cards[id]["button"]


func refresh() -> void:
	coins_label.text = str(state.coins)
	for id: String in cards:
		var b: Button = cards[id]["button"]
		if state.theme_active == id:
			b.text = tr("btn_active")
			b.disabled = true
		elif ThemeCatalog.is_owned(state, id):
			b.text = tr("btn_use")
			b.disabled = false
		else:
			b.text = tr("btn_buy") % ThemeCatalog.cost(id)
			b.disabled = not ThemeCatalog.can_buy(state, id)


func _on_card_pressed(id: String) -> void:
	if ThemeCatalog.is_owned(state, id):
		if ThemeCatalog.set_active(state, id):
			SaveSystem.save(state)
			refresh()
			theme_selected.emit(id)
	elif ThemeCatalog.buy(state, id):
		SaveSystem.save(state)
		refresh()
		theme_bought.emit(id)


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)
	var title := Label.new()
	title.text = tr("themes_title")
	title.add_theme_font_size_override("font_size", FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", FONT_SIZE)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(coins_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	box.add_child(grid)
	for t: Dictionary in ThemeCatalog.all():
		_add_card(grid, t)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	back_button = Button.new()
	back_button.text = tr("btn_back")
	back_button.custom_minimum_size = Vector2(0, 100)
	back_button.add_theme_font_size_override("font_size", FONT_SIZE)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back_button)


func _add_card(grid: GridContainer, t: Dictionary) -> void:
	var id: String = str(t.get("id", ""))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = str(t.get("name", id))
	name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var preview := ThemePreview.new()
	preview.theme_data = t
	preview.custom_minimum_size = PREVIEW_SIZE
	col.add_child(preview)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 90)
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(_on_card_pressed.bind(id))
	col.add_child(b)
	grid.add_child(col)
	cards[id] = {"panel": col, "button": b}


## Maly podglad: 3 probowki z warstwami cieczy na tle motywu.
class ThemePreview:
	extends Control
	var theme_data: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(theme_data.get("background", "#000000")))
		var liquids: Array = theme_data.get("liquids", [])
		var glass := Color(theme_data.get("glass", "#FFFFFF"))
		var tube_w: float = size.x / 5.0
		var tube_h: float = size.y * 0.8
		var layer_h: float = tube_h / 4.0
		for i in 3:
			var x: float = tube_w * (0.75 + 1.25 * i)
			var top: float = size.y * 0.1
			for l in 4:
				if liquids.is_empty():
					break
				var c := Color(liquids[(i + l) % liquids.size()])
				draw_rect(Rect2(x, top + tube_h - layer_h * (l + 1), tube_w, layer_h), c)
			draw_rect(Rect2(x, top, tube_w, tube_h), glass, false, 3.0)
