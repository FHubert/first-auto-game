class_name ShopScreen
extends Control
## Sklep IAP: ceny wylacznie z IapProvider (Purchases.price_text), restore (wymog Apple).

signal back_pressed
signal purchase_requested(sku: String)

const FONT_SIZE: int = 32
const MARGIN: int = 48
const UI_THEME: Theme = preload("res://assets/fonts/ui_theme.tres")
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
				var window_s: int = int(GameConfig.get_value("starter_offer_hours", 72)) * 3600
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
			return tr("shop_desc_starter") % int(GameConfig.get_value("iap_starter_coins", 800))
		"remove_ads":
			return tr("shop_desc_remove_ads")
		"coins_small":
			return tr("shop_desc_coins") % int(GameConfig.get_value("iap_coins_small", 500))
		_:
			return tr("shop_desc_coins") % int(GameConfig.get_value("iap_coins_large", 1500))


func _label(parent: Control, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, height: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(b)
	return b


func _build() -> void:
	backdrop = PanelContainer.new()
	backdrop.theme = UI_THEME
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)
	_label(box, tr("shop_title"))
	coins_label = _label(box)
	reason_label = _label(box)
	for sku in SKU_ORDER:
		var col := VBoxContainer.new()
		box.add_child(col)
		_label(col, tr("shop_item_" + sku))
		var desc := _label(col, _desc(sku))
		var extra := _label(col)
		var b := _button(col, "", 90)
		b.pressed.connect(_on_buy.bind(sku))
		cards[sku] = {"panel": col, "button": b, "desc": desc, "extra": extra}
	status_label = _label(box)
	restore_button = _button(box, tr("btn_restore"), 90)
	restore_button.pressed.connect(Purchases.restore)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	back_button = _button(box, tr("btn_back"), 100)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
