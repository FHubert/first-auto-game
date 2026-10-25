class_name ShopScreen
extends Control
## Sklep IAP: ceny wylacznie z IapProvider (Purchases.price_text), restore (wymog Apple).

signal back_pressed
signal purchase_requested(sku: String)

const GAP: int = 22
const UI_THEME: Theme = preload("res://assets/fonts/ui_theme.tres")
const SKU_ICONS: Dictionary = {
	"starter_pack": "coin", "remove_ads": "video", "coins_small": "coin", "coins_large": "coin"
}
const SKU_ORDER: Array[String] = ["starter_pack", "remove_ads", "coins_small", "coins_large"]

var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var reason: String = ""
var coins_label: Label
var reason_label: Label
var backdrop: PanelContainer
var status_label: Label
var restore_button: Button
var back_button: Button
## sku -> {"panel": Control, "button": Button, "desc": Label, "extra": Label}
var cards: Dictionary = {}


func _ready() -> void:
	Locale.ensure_installed()
	if state == null:
		state = SaveSystem.load()
	Purchases.bind_state(state)
	_build()
	Purchases.products_updated.connect(func(_p: Array) -> void: refresh())
	Purchases.purchase_granted.connect(func(_s: String) -> void: refresh())
	Purchases.restore_done.connect(_on_restore_done)
	refresh()


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
		extra.visible = false
		if sku == Purchases.SKU_STARTER:
			var now: int = int(clock.call())
			panel.visible = Purchases.starter_offer_visible(state.level, now)
			if panel.visible:
				var window_s: int = int(GameConfig.get_value("starter_offer_hours")) * 3600
				var left_s: int = state.starter_offer_start_day + window_s - now
				extra.text = tr("shop_offer_left") % int(ceil(left_s / 3600.0))
				extra.visible = true
		if Purchases.NON_CONSUMABLE.has(sku) and state.has_purchase(sku):
			b.text = tr("btn_owned")
			b.disabled = true
		elif Purchases.price_text(sku) == "":
			b.text = tr("shop_price_unknown")
			b.disabled = true
		else:
			b.text = Purchases.price_text(sku)
			b.disabled = false


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


func _desc(sku: String) -> String:
	match sku:
		"starter_pack":
			return tr("shop_desc_starter") % int(GameConfig.get_value("iap_starter_coins"))
		"remove_ads":
			return tr("shop_desc_remove_ads")
		"coins_small":
			return tr("shop_desc_coins") % int(GameConfig.get_value("iap_coins_small"))
		_:
			return tr("shop_desc_coins") % int(GameConfig.get_value("iap_coins_large"))


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	margin.add_child(box)
	var header: Dictionary = ScreenHeader.build(box, tr("shop_title"), true)
	back_button = header["back"]
	coins_label = header["coins"]
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	reason_label = _label(box, "", &"LabelCaption")
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for sku in SKU_ORDER:
		_build_card(box, sku)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	status_label = _label(box, "", &"LabelCaption")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restore_button = Button.new()
	restore_button.text = tr("btn_restore")
	ScreenHeader.plain(restore_button)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		restore_button.add_theme_color_override(c, UiTokens.TEXT_MUTED)
	restore_button.pressed.connect(Purchases.restore)
	box.add_child(restore_button)


func _build_card(box: Control, sku: String) -> void:
	var starter: bool = sku == Purchases.SKU_STARTER
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card" if starter else &"CardRow"
	if starter:
		var sb := UI_THEME.get_stylebox("panel", "Card").duplicate() as StyleBoxFlat
		sb.set_border_width_all(6)
		sb.border_color = UiTokens.ACCENT
		panel.add_theme_stylebox_override("panel", sb)
	box.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	panel.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon_panel := PanelContainer.new()
	var ib := StyleBoxFlat.new()
	ib.bg_color = UiTokens.CARD_ICON
	ib.set_corner_radius_all(UiTokens.CARD_ROW_RADIUS)
	ib.set_content_margin_all(14)
	icon_panel.add_theme_stylebox_override("panel", ib)
	var icon := TextureRect.new()
	icon.texture = UiTokens.icon(SKU_ICONS[sku])
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_panel.add_child(icon)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := _label(col, tr("shop_item_" + sku))
	title.add_theme_font_size_override("font_size", UiTokens.FONT_BTN)
	var extra := _label(col, "", &"LabelCaption")
	extra.add_theme_color_override("font_color", UiTokens.ACCENT)
	var desc := _label(col, _desc(sku), &"LabelCaption")
	for l: Label in [title, extra, desc]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := Button.new()
	b.theme_type_variation = &"ButtonPrimary" if starter else &"ButtonAccent"
	b.custom_minimum_size = Vector2(0 if starter else 200, UiTokens.BTN_H)
	b.pressed.connect(_on_buy.bind(sku))
	if starter:
		panel.remove_child(row)
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", GAP)
		panel.add_child(wrap)
		wrap.add_child(row)
		wrap.add_child(b)
	else:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	row.add_child(icon_panel)
	row.add_child(col)
	row.move_child(icon_panel, 0)
	if not starter:
		row.move_child(b, row.get_child_count() - 1)
	cards[sku] = {"panel": panel, "button": b, "desc": desc, "extra": extra}
