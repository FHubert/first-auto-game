class_name ThemesScreen
extends Control
## Ekran motywow: podglad, cena, zakup, aktywacja.

signal back_pressed
signal theme_selected(id: String)
signal theme_bought(id: String)

const GAP: int = 22
const PREVIEW_H: int = 277
const PREVIEW_MIN_H: int = 150
const FIT_SLACK: int = 4
const PREVIEW_RADIUS: int = 30
const CARD_GAP: int = 18
const CHECK_SIZE: int = 44
const LOCK_BORDER: int = 4
const LOCK_BORDER_ALPHA: float = 0.5
const ICON_TEXT_GAP: float = 10.0
const COIN_ICON: float = 40.0
const BAR_H: int = 18
const PROGRESS_GAP: int = 15
const ACTIVE_BORDER: int = 6

var state: GameState
var coins_label: Label
var back_button: Button
var progress_panel: Control
var progress_bar: ProgressBar
var progress_label: Label
var progress_amount: Label
var progress_hint: Label
## id -> {"panel": Control, "button": Button}
var cards: Dictionary = {}
var previews: Array[Control] = []
var _margin: MarginContainer


func _ready() -> void:
	Locale.ensure_installed()
	if state == null:
		state = SaveSystem.load()
	_build()
	refresh()
	# Autowrap daje przed layoutem absurdalna wysokosc minimalna - licz po pierwszej klatce.
	await get_tree().process_frame
	_fit_previews()


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
		for st: String in ["normal", "hover", "pressed", "disabled"]:
			b.remove_theme_stylebox_override(st)
		b.add_theme_color_override("font_disabled_color", UiTokens.TEXT_MUTED)
		var locked: bool = not active and not ThemeCatalog.is_owned(state, id)
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
			b.add_theme_color_override("font_color", UiTokens.ACCENT)
			b.add_theme_color_override("font_disabled_color", UiTokens.ACCENT)
			var lock_sb := _locked_style()
			for st: String in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(st, lock_sb)
		(cards[id]["coin"] as Control).visible = locked
		(b.get_meta("place_icon") as Callable).call()
	var next_id: String = ThemeCatalog.next_theme_id(state)
	progress_panel.visible = next_id != ""
	if next_id != "":
		var cost: int = ThemeCatalog.cost(next_id)
		var missing: int = maxi(0, cost - state.coins)
		progress_label.text = tr("themes_remaining") % [tr("theme_name_" + next_id), missing]
		progress_amount.text = "%d / %d" % [mini(state.coins, cost), cost]
		progress_bar.max_value = cost
		progress_bar.value = mini(state.coins, cost)


## Miniatury maja 277 px (makieta), ale na niskim ekranie kurcza sie, zeby calosc sie miescila.
func _fit_previews() -> void:
	if previews.is_empty() or size.y <= 0.0 or _margin == null:
		return
	var rows: int = ceili(previews.size() / 2.0)
	var cur: float = previews[0].custom_minimum_size.y
	var fixed: float = _margin.get_combined_minimum_size().y - rows * cur
	var h: int = int((size.y - fixed) / rows) - FIT_SLACK
	for p: Control in previews:
		p.custom_minimum_size.y = clampi(h, PREVIEW_MIN_H, PREVIEW_H)


func _locked_style() -> StyleBoxFlat:
	var sb := ScreenHeader.UI_THEME.get_stylebox("normal", "ButtonSecondary").duplicate()
	var flat := sb as StyleBoxFlat
	flat.bg_color = UiTokens.CARD_ROW
	flat.set_border_width_all(LOCK_BORDER)
	flat.border_color = Color(UiTokens.ACCENT, LOCK_BORDER_ALPHA)
	return flat


## Button.icon przykleja ikone do krawedzi - moneta jest dzieckiem przycisku obok tekstu.
func _add_coin(b: Button) -> TextureRect:
	var coin := TextureRect.new()
	coin.name = "InlineIcon"
	coin.texture = UiTokens.icon("coin")
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size = Vector2.ONE * COIN_ICON
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(coin)
	var place := func() -> void:
		var font: Font = b.get_theme_font("font")
		var fsize: int = b.get_theme_font_size("font_size")
		var text_w: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var x: float = b.size.x * 0.5 - text_w * 0.5 - ICON_TEXT_GAP - COIN_ICON
		coin.position = Vector2(x, (b.size.y - COIN_ICON) * 0.5)
	b.resized.connect(place)
	b.set_meta("place_icon", place)
	return coin


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
	_margin = margin
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
	resized.connect(_fit_previews)


func _build_progress(box: Control) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardRow"
	box.add_child(panel)
	progress_panel = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", PROGRESS_GAP)
	panel.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	progress_label = Label.new()
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(progress_label)
	progress_amount = Label.new()
	progress_amount.add_theme_color_override("font_color", UiTokens.ACCENT)
	progress_amount.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	row.add_child(progress_amount)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = BAR_H
	var track := StyleBoxFlat.new()
	track.bg_color = UiTokens.BG_DEEP
	track.set_corner_radius_all(BAR_H)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = UiTokens.ACCENT
	progress_bar.add_theme_stylebox_override("background", track)
	progress_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(progress_bar)
	progress_hint = Label.new()
	progress_hint.text = tr("themes_hint")
	progress_hint.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
	progress_hint.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	progress_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(progress_hint)


func _add_card(grid: GridContainer, t: Dictionary) -> void:
	var id: String = str(t.get("id", ""))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", CARD_GAP)
	panel.add_child(col)
	var preview := ThemePreview.new()
	preview.theme_data = t
	preview.custom_minimum_size = Vector2(0, PREVIEW_H)
	col.add_child(preview)
	previews.append(preview)
	var name_row := HBoxContainer.new()
	col.add_child(name_row)
	var name_label := Label.new()
	name_label.text = tr("theme_name_" + id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	name_row.add_child(name_label)
	var check := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = UiTokens.ACCENT
	csb.set_corner_radius_all(CHECK_SIZE / 2)
	check.add_theme_stylebox_override("panel", csb)
	check.custom_minimum_size = Vector2(CHECK_SIZE, CHECK_SIZE)
	var check_icon := TextureRect.new()
	check_icon.texture = UiTokens.icon("check")
	check_icon.modulate = UiTokens.ON_ACCENT
	check_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.add_child(check_icon)
	name_row.add_child(check)
	var b := Button.new()
	b.theme_type_variation = &"ButtonSecondary"
	b.custom_minimum_size = Vector2(0, UiTokens.TOUCH_MIN)
	b.add_theme_font_size_override("font_size", UiTokens.FONT_SM)
	b.pressed.connect(_on_card_pressed.bind(id))
	col.add_child(b)
	var coin := _add_coin(b)
	grid.add_child(panel)
	cards[id] = {
		"panel": panel,
		"button": b,
		"name": name_label,
		"check": check,
		"check_icon": check_icon,
		"coin": coin,
	}


## Maly podglad: 4 zaokraglone probowki (wzor makiety 06) na tle motywu.
class ThemePreview:
	extends Control
	const PATTERN: Array = [[0, 1, 2, 3], [4, 5, 6, 7], [1, 0, 3, 2], [6, 7, 4, 5]]
	const TUBE_W: float = 44.0
	const TUBE_H: float = 170.0
	const TUBE_GAP: float = 17.0
	const BOTTOM_PAD: float = 33.0
	const TOP_PAD: float = 18.0
	const LINE: float = 5.0
	const PAD: float = 4.0
	const GLASS_A: float = 0.7
	var theme_data: Dictionary = {}

	## Skala rysunku: na niskiej miniaturze probowki kurcza sie proporcjonalnie (jak scale_for).
	func draw_scale() -> float:
		return clampf((size.y - TOP_PAD - BOTTOM_PAD) / TUBE_H, 0.0, 1.0)

	## Prostokat i-tej probowki - ta sama geometria, ktorej uzywa _draw().
	func tube_rect(i: int) -> Rect2:
		var k: float = draw_scale()
		var total: float = (4.0 * TUBE_W + 3.0 * TUBE_GAP) * k
		var x0: float = (size.x - total) / 2.0
		return Rect2(
			x0 + i * (TUBE_W + TUBE_GAP) * k,
			size.y - (BOTTOM_PAD + TUBE_H) * k,
			TUBE_W * k,
			TUBE_H * k
		)

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(theme_data.get("background", "#000000"))
		bg.set_corner_radius_all(PREVIEW_RADIUS)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		for i: int in 4:
			_draw_tube(tube_rect(i), PATTERN[i])

	func _draw_tube(r: Rect2, pattern: Array) -> void:
		var liquids: Array = theme_data.get("liquids", [])
		var radius: float = r.size.x * 0.5
		var k: float = draw_scale()
		var inner := r.grow(-PAD * k)
		var lh: float = inner.size.y / 4.0
		for l: int in 4:
			if liquids.is_empty():
				break
			var c := Color(liquids[int(pattern[l]) % liquids.size()])
			var lr := Rect2(inner.position.x, inner.end.y - lh * (l + 1), inner.size.x, lh)
			draw_colored_polygon(TubeView.layer_polygon(lr, l == 0, radius - PAD * k), c)
		var glass := Color(theme_data.get("glass", "#FFFFFF"))
		glass.a = GLASS_A
		var lw: float = LINE * k
		var half: float = lw * 0.5
		var line := Rect2(r.position.x + half, r.position.y, r.size.x - lw, r.size.y - half)
		draw_polyline(TubeView.bottom_round_path(line, radius - half), glass, lw, true)
