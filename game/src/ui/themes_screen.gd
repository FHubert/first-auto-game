class_name ThemesScreen
extends Control
## Ekran motywow: podglad, cena, zakup, aktywacja.

signal back_pressed
signal theme_selected(id: String)
signal theme_bought(id: String)

const GAP: int = 22
const PREVIEW_H: int = 150
const ACTIVE_BORDER: int = 6

var state: GameState
var coins_label: Label
var back_button: Button
var progress_panel: Control
var progress_bar: ProgressBar
var progress_label: Label
var progress_amount: Label
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


func card_name_label(id: String) -> Label:
	return cards[id]["name"]


func refresh() -> void:
	coins_label.text = str(state.coins)
	for id: String in cards:
		var b: Button = cards[id]["button"]
		var panel: Control = cards[id]["panel"]
		var active: bool = state.theme_active == id
		(cards[id]["check"] as Control).visible = active
		panel.remove_theme_stylebox_override("panel")
		b.icon = null
		b.remove_theme_color_override("font_color")
		if active:
			b.text = tr("btn_active")
			b.disabled = true
			var sb := (
				ScreenHeader.UI_THEME.get_stylebox("panel", "Card").duplicate() as StyleBoxFlat
			)
			sb.set_border_width_all(ACTIVE_BORDER)
			sb.border_color = UiTokens.ACCENT
			panel.add_theme_stylebox_override("panel", sb)
		elif ThemeCatalog.is_owned(state, id):
			b.text = tr("btn_use")
			b.disabled = false
		else:
			b.text = str(ThemeCatalog.cost(id))
			b.disabled = not ThemeCatalog.can_buy(state, id)
			b.icon = UiTokens.icon("coin")
			b.add_theme_color_override("font_color", UiTokens.ACCENT)
	var next_id: String = ThemeCatalog.next_theme_id(state)
	progress_panel.visible = next_id != ""
	if next_id != "":
		var cost: int = ThemeCatalog.cost(next_id)
		var missing: int = maxi(0, cost - state.coins)
		progress_label.text = tr("themes_remaining") % [tr("theme_name_" + next_id), missing]
		progress_amount.text = "%d / %d" % [mini(state.coins, cost), cost]
		progress_bar.max_value = cost
		progress_bar.value = mini(state.coins, cost)


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
	theme = ScreenHeader.UI_THEME
	ScreenHeader.add_backdrop(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiTokens.SCREEN_PAD)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	margin.add_child(box)
	var header: Dictionary = ScreenHeader.build(box, tr("themes_title"), true)
	back_button = header["back"]
	coins_label = header["coins"]
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	box.add_child(grid)
	for t: Dictionary in ThemeCatalog.all():
		_add_card(grid, t)
	_build_progress(box)


func _build_progress(box: Control) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardRow"
	box.add_child(panel)
	progress_panel = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	progress_label = Label.new()
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(progress_label)
	progress_amount = Label.new()
	progress_amount.add_theme_color_override("font_color", UiTokens.ACCENT)
	progress_amount.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	row.add_child(progress_amount)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 20
	var track := StyleBoxFlat.new()
	track.bg_color = UiTokens.BG_DEEP
	track.set_corner_radius_all(10)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UiTokens.ACCENT
	progress_bar.add_theme_stylebox_override("background", track)
	progress_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(progress_bar)


func _add_card(grid: GridContainer, t: Dictionary) -> void:
	var id: String = str(t.get("id", ""))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var preview := ThemePreview.new()
	preview.theme_data = t
	preview.custom_minimum_size = Vector2(0, PREVIEW_H)
	col.add_child(preview)
	var name_row := HBoxContainer.new()
	col.add_child(name_row)
	var name_label := Label.new()
	name_label.text = tr("theme_name_" + id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	name_row.add_child(name_label)
	var check := TextureRect.new()
	check.texture = UiTokens.icon("check")
	check.custom_minimum_size = Vector2(44, 44)
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_row.add_child(check)
	var b := Button.new()
	b.theme_type_variation = &"ButtonSecondary"
	b.custom_minimum_size = Vector2(0, UiTokens.TOUCH_MIN)
	b.add_theme_constant_override("icon_max_width", ScreenHeader.ICON_MAX)
	b.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	b.pressed.connect(_on_card_pressed.bind(id))
	col.add_child(b)
	grid.add_child(panel)
	cards[id] = {"panel": panel, "button": b, "name": name_label, "check": check}


## Maly podglad: 4 probowki z warstwami cieczy na tle motywu.
class ThemePreview:
	extends Control
	var theme_data: Dictionary = {}

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(theme_data.get("background", "#000000"))
		bg.set_corner_radius_all(UiTokens.CARD_ROW_RADIUS)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var liquids: Array = theme_data.get("liquids", [])
		var glass := Color(theme_data.get("glass", "#FFFFFF"))
		var tube_w: float = size.x / 8.0
		var tube_h: float = size.y * 0.72
		var layer_h: float = tube_h / 4.0
		var top: float = size.y * 0.14
		for i in 4:
			var x: float = tube_w * (0.9 + 1.7 * i)
			for l in 4:
				if liquids.is_empty():
					break
				var c := Color(liquids[(i + l) % liquids.size()])
				draw_rect(Rect2(x, top + tube_h - layer_h * (l + 1), tube_w, layer_h), c)
			draw_rect(Rect2(x, top, tube_w, tube_h), glass, false, 3.0)
