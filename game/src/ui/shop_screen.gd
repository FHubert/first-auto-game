class_name ShopScreen
extends Control
## Sklep IAP: ceny wylacznie z IapProvider (Purchases.price_text), restore (wymog Apple).

signal back_pressed
signal purchase_requested(sku: String)

const GAP: int = 30
const UI_THEME: Theme = preload("res://assets/fonts/ui_theme.tres")
const SKU_ICONS: Dictionary = {
	"starter_pack": "coin",
	"remove_ads": "video_off",
	"coins_small": "coin",
	"coins_large": "coins_stack"
}
## Ponizej tej wysokosci viewportu karta startowa jest kompaktowa (mniejsza miniatura, bez motywu).
const COMPACT_BELOW_H: float = 1400.0
const SKU_ORDER: Array[String] = ["starter_pack", "coins_small", "coins_large", "remove_ads"]

var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var reason: String = ""
var coins_label: Label
var reason_label: Label
var backdrop: PanelContainer
var status_label: Label
## Karty w przewijanym obszarze: na niskich ekranach lista przewija sie, restore zostaje na dole.
var scroll: ScrollContainer
var restore_button: LinkButton
var back_button: Button
## sku -> {"panel", "button", "desc", "extra", "badge", "clock"} (Control/Button/Label/TextureRect)
var cards: Dictionary = {}
var compact: bool = false
var _theme_label: Label
var _tubes: StarterTubes
var _outer: VBoxContainer
var _box: VBoxContainer
var _list: VBoxContainer
var _fit_queued: bool = false


func _ready() -> void:
	Locale.ensure_installed()
	if state == null:
		state = SaveSystem.load()
	Purchases.bind_state(state)
	_build()
	Purchases.products_updated.connect(func(_p: Array) -> void: refresh())
	Purchases.purchase_granted.connect(func(_s: String) -> void: refresh())
	Purchases.restore_done.connect(_on_restore_done)
	resized.connect(_apply_compact)
	refresh()
	_apply_compact()
	_queue_fit()


func has_card(sku: String) -> bool:
	return cards.has(sku) and (cards[sku]["panel"] as Control).visible


func card_button(sku: String) -> Button:
	return cards[sku]["button"]


func refresh() -> void:
	coins_label.text = str(state.coins)
	var key: String = "shop_reason_" + reason
	reason_label.text = tr(key)
	reason_label.visible = reason != "" and reason_label.text != key
	for sku: String in cards:
		var panel: Control = cards[sku]["panel"]
		var b: Button = cards[sku]["button"]
		var extra: Label = cards[sku]["extra"]
		var clock_icon: TextureRect = cards[sku]["clock"]
		if extra != null:
			extra.visible = false
			clock_icon.visible = false
		if sku == Purchases.SKU_STARTER:
			var now: int = int(clock.call())
			panel.visible = Purchases.starter_offer_visible(state.level, now)
			if panel.visible:
				var window_s: int = int(GameConfig.get_value("starter_offer_hours")) * 3600
				var left_s: int = state.starter_offer_start_day + window_s - now
				extra.text = str(tr("shop_offer_left")) % format_hms(left_s)
				extra.visible = true
				clock_icon.visible = true
		if Purchases.NON_CONSUMABLE.has(sku) and state.has_purchase(sku):
			b.text = tr("btn_owned")
			b.disabled = true
		elif Purchases.price_text(sku) == "":
			b.text = tr("shop_price_unknown")
			b.disabled = true
		else:
			var price: String = Purchases.price_text(sku)
			b.text = str(tr("shop_buy_for")) % price if sku == Purchases.SKU_STARTER else price
			b.disabled = false


func _queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit_list.call_deferred()


## Gdy cala lista miesci sie na ekranie, stopka (restore) laduje tuz pod nia;
## gdy nie, lista wypelnia ekran i przewija sie (zachowanie T-303).
func _fit_list() -> void:
	_fit_queued = false
	if _outer == null or _outer.size.y <= 0.0:
		return
	var used: float = 0.0
	var shown: int = 0
	for c: Node in _box.get_children():
		var ctrl := c as Control
		if ctrl == scroll or not ctrl.visible:
			continue
		used += ctrl.get_combined_minimum_size().y
		shown += 1
	var footer: float = (
		status_label.get_combined_minimum_size().y + restore_button.get_combined_minimum_size().y
	)
	used += float(GAP * shown)
	var avail: float = _outer.size.y - footer - used
	var content: float = _list.get_combined_minimum_size().y
	var fits: bool = content <= avail
	var flag: int = Control.SIZE_SHRINK_BEGIN if fits else Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = content if fits else 0.0
	scroll.size_flags_vertical = flag
	_box.size_flags_vertical = flag


func _apply_compact() -> void:
	compact = size.y > 0.0 and size.y < COMPACT_BELOW_H
	if _theme_label != null:
		_theme_label.visible = not compact
		_tubes.set_compact(compact)


func _on_buy(sku: String) -> void:
	Purchases.buy(sku)
	purchase_requested.emit(sku)
	refresh()


func _on_restore_done(restored: Array) -> void:
	status_label.text = (
		tr("shop_restored") % restored.size()
		if not restored.is_empty()
		else tr("shop_restore_none")
	)
	refresh()


static func format_hms(seconds: int) -> String:
	var t: int = maxi(seconds, 0)
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


func _title(sku: String) -> String:
	match sku:
		"coins_small":
			return str(tr("shop_coins_amount")) % int(GameConfig.get_value("iap_coins_small"))
		"coins_large":
			return str(tr("shop_coins_amount")) % int(GameConfig.get_value("iap_coins_large"))
		_:
			return tr("shop_item_" + sku)


func _desc(sku: String) -> String:
	match sku:
		"starter_pack":
			return tr("shop_starter_once")
		"remove_ads":
			return tr("shop_desc_remove_ads")
		"coins_small":
			var cost: int = maxi(int(GameConfig.get_value("extra_tube_cost_coins")), 1)
			return (
				str(tr("shop_desc_tubes")) % (int(GameConfig.get_value("iap_coins_small")) / cost)
			)
		_:
			return (
				str(tr("shop_desc_bonus")) % int(GameConfig.get_value("iap_coins_large_bonus_pct"))
			)


func _label(parent: Control, text: String = "", variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _build() -> void:
	theme = UI_THEME
	backdrop = PanelContainer.new()
	backdrop.theme = UI_THEME
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiTokens.BG
	backdrop.add_theme_stylebox_override("panel", bg)
	add_child(backdrop)
	move_child(backdrop, 0)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiTokens.SCREEN_PAD)
	add_child(margin)
	## Zewnetrzny box bez odstepu: lista przylega do stopki (restore + status).
	var outer := VBoxContainer.new()
	_outer = outer
	outer.resized.connect(_queue_fit)
	outer.add_theme_constant_override("separation", 0)
	margin.add_child(outer)
	var box := VBoxContainer.new()
	_box = box
	box.add_theme_constant_override("separation", GAP)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(box)
	var header: Dictionary = ScreenHeader.build(box, tr("shop_title"), true)
	back_button = header["back"]
	coins_label = header["coins"]
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	reason_label = _label(box, "", &"LabelCaption")
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_list = list
	list.minimum_size_changed.connect(_queue_fit)
	for sku in SKU_ORDER:
		_build_card(list, sku)
	status_label = _label(outer, "", &"LabelCaption")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restore_button = LinkButton.new()
	restore_button.text = tr("btn_restore")
	restore_button.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	restore_button.custom_minimum_size.y = UiTokens.TOUCH_MIN
	restore_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore_button.add_theme_font_size_override("font_size", UiTokens.FONT_SM + 2)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		restore_button.add_theme_color_override(c, UiTokens.TEXT_SOFT)
	restore_button.pressed.connect(Purchases.restore)
	outer.add_child(restore_button)


func _style(radius: int, bg: Color, margins: Array[int], border: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = UiTokens.ACCENT
	sb.content_margin_left = margins[0]
	sb.content_margin_top = margins[1]
	sb.content_margin_right = margins[2]
	sb.content_margin_bottom = margins[3]
	return sb


func _text(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := _label(parent, text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _icon(sku_icon: String, px: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UiTokens.icon(sku_icon)
	icon.custom_minimum_size = Vector2(px, px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _build_card(box: Control, sku: String) -> void:
	var starter: bool = sku == Purchases.SKU_STARTER
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		(
			_style(48, UiTokens.CARD_ICON, [33, 37, 33, 33], 6)
			if starter
			else _style(41, UiTokens.CARD, [26, 26, 26, 26])
		)
	)
	box.add_child(panel)
	var b := Button.new()
	b.theme_type_variation = &"ButtonPrimary" if starter else &"ButtonAccent"
	b.custom_minimum_size = Vector2(0 if starter else 177, UiTokens.BTN_H if starter else 81)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(_on_buy.bind(sku))
	var extra: Label
	var badge: Label
	var desc: Label
	var clock_icon: TextureRect
	if starter:
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 26)
		panel.add_child(wrap)
		var top := HBoxContainer.new()
		wrap.add_child(top)
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _style(24, UiTokens.ACCENT, [18, 0, 18, 0]))
		pill.custom_minimum_size.y = 48
		top.add_child(pill)
		badge = _text(pill, tr("shop_starter_badge"), 24, UiTokens.ON_ACCENT)
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var offer := HBoxContainer.new()
		offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer.alignment = BoxContainer.ALIGNMENT_END
		offer.add_theme_constant_override("separation", 8)
		top.add_child(offer)
		clock_icon = _icon("clock", 32)
		clock_icon.name = "OfferClock"
		clock_icon.modulate = UiTokens.ACCENT
		clock_icon.visible = false
		offer.add_child(clock_icon)
		extra = _text(offer, "", 26, UiTokens.ACCENT)
		extra.autowrap_mode = TextServer.AUTOWRAP_OFF
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 30)
		wrap.add_child(row)
		var tile := PanelContainer.new()
		var theme_def: Dictionary = ThemeCatalog.theme(
			str(GameConfig.get_value("iap_starter_theme"))
		)
		var bg: Color = Color(str(theme_def.get("background", "#000000")))
		tile.add_theme_stylebox_override("panel", _style(30, bg, [22, 18, 22, 18]))
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tubes = StarterTubes.new(theme_def)
		tile.add_child(_tubes)
		row.add_child(tile)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 7)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var coins_row := HBoxContainer.new()
		coins_row.add_theme_constant_override("separation", 12)
		col.add_child(coins_row)
		var coin := _icon("coin", 44)
		coin.name = "InlineIcon"
		coins_row.add_child(coin)
		var amount: int = int(GameConfig.get_value("iap_starter_coins"))
		var coins_text := _text(
			coins_row, str(tr("shop_starter_coins")) % amount, 44, UiTokens.TEXT
		)
		coins_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		var name_key: String = "theme_name_" + str(GameConfig.get_value("iap_starter_theme"))
		_theme_label = _text(
			col, str(tr("shop_starter_theme")) % tr(name_key), 30, UiTokens.TEXT_SOFT
		)
		desc = _text(col, _desc(sku), 24, UiTokens.TEXT_MUTED)
		wrap.add_child(b)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 26)
		panel.add_child(row)
		var icon_panel := PanelContainer.new()
		icon_panel.add_theme_stylebox_override(
			"panel", _style(33, UiTokens.CARD_ICON, [26, 26, 26, 26])
		)
		icon_panel.add_child(_icon(SKU_ICONS[sku], 51))
		icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon_panel)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(col)
		_text(col, _title(sku), 33, UiTokens.TEXT)
		var bonus: bool = sku == "coins_large"
		desc = _text(col, _desc(sku), 26, UiTokens.PRIMARY if bonus else UiTokens.TEXT_MUTED)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	cards[sku] = {
		"panel": panel,
		"button": b,
		"desc": desc,
		"extra": extra,
		"badge": badge,
		"clock": clock_icon
	}


## Miniatura 2 probowek motywu startowego (makieta 07): 3 i 4 warstwy.
class StarterTubes:
	extends Control

	const TUBE_PX := Vector2(37, 137)
	const GAP_PX := 11.0
	const LAYER_H := 31.0
	const OUTLINE_W := 4.0
	const PICKS: Array = [[0, 5, 2], [3, 7, 1, 6]]
	const COMPACT_K := 0.6
	var def: Dictionary
	var _k: float = 1.0

	func _init(theme_def: Dictionary) -> void:
		def = theme_def
		set_compact(false)

	func set_compact(on: bool) -> void:
		_k = COMPACT_K if on else 1.0
		custom_minimum_size = Vector2(TUBE_PX.x * 2.0 + GAP_PX, TUBE_PX.y) * _k
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k, _k))
		var liquids: Array = def.get("liquids", [])
		var glass := Color(str(def.get("glass", "#FFFFFF")), 0.8)
		var radius: float = TUBE_PX.x * 0.5
		for t: int in 2:
			var r := Rect2(Vector2(t * (TUBE_PX.x + GAP_PX), 0.0), TUBE_PX)
			var layers: Array = PICKS[t]
			for j: int in layers.size():
				var lr := Rect2(r.position.x, r.end.y - LAYER_H * (j + 1), r.size.x, LAYER_H)
				var c := Color(str(liquids[int(layers[j]) % liquids.size()]))
				draw_colored_polygon(TubeView.layer_polygon(lr, j == 0, radius), c)
			var half: float = OUTLINE_W * 0.5
			var line := Rect2(
				r.position.x + half, r.position.y, r.size.x - OUTLINE_W, r.size.y - half
			)
			draw_polyline(TubeView.bottom_round_path(line, radius - half), glass, OUTLINE_W, true)
