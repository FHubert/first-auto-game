class_name LevelComplete
extends Control
## Overlay po wygranej: monety, "Idealnie!" i przycisk "Dalej".

signal next_pressed
signal home_pressed
signal double_pressed
## Panel zmienil minimalna wysokosc (po rozlozeniu zawijanego tekstu) - plansza ma sie dopasowac.
signal panel_height_changed

const SAMPLE_COINS: int = 15
const SAMPLE_LEVEL: int = 2
const THEME_BAR_H: int = 26
const ICON_TEXT_GAP: int = 14

var btn_copy_result: Button
var clipboard_setter: Callable = DisplayServer.clipboard_set
var effects_enabled: bool = true
var _share_text: String = ""

@onready var level_caption: Label = $Header/LevelCaption
@onready var title_label: Label = $Header/TitleLabel
@onready var coins_label: Label = $Panel/Box/CoinRow/CoinsLabel
@onready var perfect_badge: PanelContainer = $Panel/Box/PerfectBadge
@onready var perfect_label: Label = $Panel/Box/PerfectBadge/PerfectLabel
@onready var breakdown_label: Label = $Panel/Box/BreakdownLabel
@onready var theme_row: VBoxContainer = $Panel/Box/ThemeRow
@onready var theme_name_label: Label = $Panel/Box/ThemeRow/NameRow/ThemeNameLabel
@onready var theme_value_label: Label = $Panel/Box/ThemeRow/NameRow/ThemeValueLabel
@onready var theme_bar: ProgressBar = $Panel/Box/ThemeRow/ThemeBar
@onready var progress_label: Label = $Panel/Box/ProgressLabel
@onready var double_button: Button = $Panel/Box/DoubleButton
@onready var next_button: Button = $Panel/Box/NextButton
@onready var home_button: Button = $Panel/Box/HomeButton


## Odleglosc gornej krawedzi panelu od dolnej krawedzi ekranu (px, Z marginesem `-offset_bottom`):
## stala z sceny albo wysokosc z tresci (np. dlugi komunikat postepu) - co wieksze.
## Panel rosnie w gore (grow_vertical = begin), wiec
## `panel_rect().size.y == panel_height() - margines`.
func panel_height() -> float:
	var min_h: float = $Panel.get_combined_minimum_size().y - $Panel.offset_bottom
	return maxf(-$Panel.offset_top, min_h)


## Wysokosc naglowka (px od gory ekranu): stala ze sceny albo tresc, co wieksze.
func header_height() -> float:
	return maxf($Header.offset_bottom, $Header.offset_top + $Header.get_combined_minimum_size().y)


func header_rect() -> Rect2:
	return $Header.get_global_rect()


func panel_rect() -> Rect2:
	return $Panel.get_global_rect()


func _ready() -> void:
	Locale.ensure_installed()
	$Panel.minimum_size_changed.connect(func() -> void: panel_height_changed.emit())
	next_button.text = tr("btn_next")
	_add_inline_icon(next_button, "arrow_right", UiTokens.ON_PRIMARY, true)
	_add_inline_icon(double_button, "video", UiTokens.ON_ACCENT, false)
	(next_button.get_meta("place_icon") as Callable).call()
	$Panel/Box/CoinRow/CoinIcon.texture = UiTokens.icon("coin")
	_style_badge()
	_style_theme_bar()
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		home_button.add_theme_color_override(state, UiTokens.TEXT_SOFT)
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	double_button.pressed.connect(func() -> void: double_pressed.emit())
	home_button.text = tr("btn_menu")
	home_button.pressed.connect(func() -> void: home_pressed.emit())
	btn_copy_result = Button.new()
	btn_copy_result.visible = false
	btn_copy_result.pressed.connect(_on_copy_pressed)
	btn_copy_result.theme_type_variation = &"ButtonSecondary"
	btn_copy_result.custom_minimum_size.y = UiTokens.TOUCH_MIN
	$Panel/Box.add_child(btn_copy_result)
	$Panel/Box.move_child(btn_copy_result, next_button.get_index())
	if get_parent() == get_tree().root:
		show_result(SAMPLE_COINS, true, SAMPLE_LEVEL, "", {"key": "lc_new_color", "args": []})
		set_double_offer(SAMPLE_COINS, true)


## Button.icon rysuje ikone przy krawedzi przycisku, nie przy tekscie - dlatego ikona jest
## dzieckiem przycisku, ustawianym tuz obok wysrodkowanego tekstu (makieta 03).
func _add_inline_icon(b: Button, icon_name: String, color: Color, after: bool) -> void:
	var tr_icon := TextureRect.new()
	tr_icon.name = "InlineIcon"
	tr_icon.texture = UiTokens.icon(icon_name)
	tr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr_icon.size = Vector2.ONE * UiTokens.TILE_ICON
	tr_icon.modulate = color
	tr_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tr_icon)
	var place := func() -> void:
		var font: Font = b.get_theme_font("font")
		var fsize: int = b.get_theme_font_size("font_size")
		var text_w: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var half: float = text_w * 0.5 + ICON_TEXT_GAP
		var x: float = b.size.x * 0.5 + (half if after else -half - tr_icon.size.x)
		tr_icon.position = Vector2(x, (b.size.y - tr_icon.size.y) * 0.5)
		tr_icon.visible = b.text != ""
	b.resized.connect(place)
	b.visibility_changed.connect(place)
	b.set_meta("place_icon", place)


func _style_theme_bar() -> void:
	breakdown_label.add_theme_color_override("font_color", UiTokens.TEXT_SOFT)
	theme_value_label.add_theme_color_override("font_color", UiTokens.ACCENT)
	theme_bar.custom_minimum_size = Vector2(0, THEME_BAR_H)
	var track := StyleBoxFlat.new()
	track.bg_color = UiTokens.BG_DEEP
	track.set_corner_radius_all(THEME_BAR_H)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTokens.ACCENT
	fill.set_corner_radius_all(THEME_BAR_H)
	theme_bar.add_theme_stylebox_override("background", track)
	theme_bar.add_theme_stylebox_override("fill", fill)


func _style_badge() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTokens.ACCENT, 0.16)
	sb.set_corner_radius_all(UiTokens.TILE_RADIUS)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	perfect_badge.add_theme_stylebox_override("panel", sb)
	perfect_label.add_theme_color_override("font_color", UiTokens.ACCENT)


## Jeden komunikat po wygranej kampanii: "+1 kolor" (priorytet) albo postep do motywu.
## `level_no` = numer ukonczonego poziomu. Zwraca {"key", "args"} albo {}.
static func progress_message(
	level_no: int, game_mode: String, state: GameState, month_goal_hit: bool = false
) -> Dictionary:
	if game_mode == Level.MODE_DAILY and month_goal_hit:
		return {
			"key": "lc_month_goal", "args": [int(GameConfig.get_value("daily_month_goal_coins"))]
		}
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
	coins: int,
	perfect: bool,
	level_no: int,
	title: String = "",
	progress: Dictionary = {},
	breakdown: Dictionary = {}
) -> void:
	title_label.text = title if title != "" else tr("lc_great")
	level_caption.visible = title == ""
	level_caption.text = (tr("hud_level") % level_no).to_upper()
	var fx_on: bool = OverlayFx.enabled_for(self, effects_enabled)
	UiFx.count_up(coins_label, coins, UiFx.COUNT_SECONDS, tr("lc_coins"), fx_on)
	var moves: int = int(breakdown.get("moves", 0))
	perfect_label.text = (
		tr("lc_perfect_moves") % moves if perfect and moves > 0 else tr("lc_perfect")
	)
	perfect_label.visible = perfect
	perfect_badge.visible = perfect
	var bonus: int = int(breakdown.get("perfect", 0))
	breakdown_label.visible = bonus > 0
	breakdown_label.text = tr("lc_breakdown") % [int(breakdown.get("win", 0)), bonus]
	var theme_cost: int = int(breakdown.get("theme_cost", 0))
	theme_row.visible = theme_cost > 0
	if theme_cost > 0:
		var have: int = mini(int(breakdown.get("coins", 0)), theme_cost)
		theme_name_label.text = tr("lc_next_theme") % str(breakdown.get("theme_name", ""))
		theme_value_label.text = "%d / %d" % [have, theme_cost]
		theme_bar.max_value = theme_cost
		theme_bar.value = have
	progress_label.visible = not progress.is_empty()
	if not progress.is_empty():
		var args: Array = progress.get("args", [])
		progress_label.text = (
			tr(str(progress["key"])) % args if not args.is_empty() else tr(str(progress["key"]))
		)
	if theme_row.visible and progress.get("key", "") == "lc_theme_progress":
		progress_label.visible = false
	double_button.visible = false
	hide_share()
	visible = true
	OverlayFx.enter($Panel, OverlayFx.enabled_for(self, effects_enabled))


## Globalny srodek ikony monety (cel lotu monet).
func coin_target() -> Vector2:
	return ($Panel/Box/CoinRow/CoinIcon as Control).get_global_rect().get_center()


func set_share(share_text: String) -> void:
	_share_text = share_text
	btn_copy_result.text = tr("btn_copy_result")
	btn_copy_result.disabled = false
	btn_copy_result.visible = true


func hide_share() -> void:
	_share_text = ""
	btn_copy_result.visible = false


func _on_copy_pressed() -> void:
	clipboard_setter.call(_share_text)
	btn_copy_result.text = tr("btn_copied")
	btn_copy_result.disabled = true
	Analytics.track_design("daily:share")


func set_double_offer(bonus: int, offered: bool) -> void:
	double_button.text = tr("btn_double") % bonus
	(double_button.get_meta("place_icon") as Callable).call()
	double_button.visible = offered and bonus > 0
