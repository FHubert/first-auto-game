class_name ScreenHeader
extends RefCounted
## Wspolne elementy ekranow UI v2 (Themes/Shop/Settings): naglowek, pill monet, przelacznik.

const UI_THEME: Theme = preload("res://assets/fonts/ui_theme.tres")
const ICON_MAX := 44
const SWITCH_SIZE := Vector2i(112, 64)

static var _switch_cache: Dictionary = {}


## Nieprzezroczyste tlo ekranu (BG) jako pierwsze dziecko.
static func add_backdrop(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = UiTokens.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)


## Naglowek: [wstecz] [tytul] [pill monet]. Zwraca {"back": Button, "coins": Label}.
static func build(parent: Control, title: String, with_coins: bool) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SCREEN_PAD / 2)
	parent.add_child(row)
	var back := Button.new()
	back.theme_type_variation = &"ButtonIcon"
	back.icon = UiTokens.icon("back")
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.expand_icon = false
	back.custom_minimum_size = Vector2(UiTokens.BTN_ICON, UiTokens.BTN_ICON)
	back.add_theme_constant_override("icon_max_width", ICON_MAX)
	row.add_child(back)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"LabelTitle"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER if with_coins else HORIZONTAL_ALIGNMENT_LEFT
	)
	row.add_child(label)
	var coins: Label = null
	if with_coins:
		coins = coins_pill(row)
	return {"back": back, "coins": coins}


## Przycisk zamknij (X) overlayow: kolo TOUCH_MIN x TOUCH_MIN (wariant `ButtonClose`:
## tlo CARD_ROW, bez cienia i paddingu). Dodany do `parent`; pozycje ustawia wolajacy.
static func close_button(parent: Control) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"ButtonClose"
	b.icon = UiTokens.icon("close")
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", UiTokens.TILE_ICON)
	b.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN, UiTokens.TOUCH_MIN)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(b)
	return b


## Pill monet (ikona + liczba) dodany do `parent`; zwraca etykiete z liczba.
static func coins_pill(parent: Control, font_size: int = UiTokens.FONT_BTN) -> Label:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.BG_DEEP
	sb.set_corner_radius_all(UiTokens.BTN_ICON)
	sb.set_content_margin_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	pill.add_theme_stylebox_override("panel", sb)
	parent.add_child(pill)
	var inner := HBoxContainer.new()
	pill.add_child(inner)
	var icon := TextureRect.new()
	icon.texture = UiTokens.icon("coin")
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inner.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	inner.add_child(label)
	return label


## Przycisk bez tla i bez paddingu stylu (wiersz listy).
static func plain(b: Button) -> void:
	b.flat = true
	b.custom_minimum_size.y = UiTokens.TOUCH_MIN
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())


## Przelacznik CheckButton: wlaczony = PRIMARY, bez tla przycisku.
static func style_switch(t: CheckButton) -> void:
	plain(t)
	for state: String in ["checked", "checked_disabled", "unchecked", "unchecked_disabled"]:
		t.add_theme_icon_override(state, _switch_texture(state.begins_with("checked")))


static func _switch_texture(on: bool) -> Texture2D:
	if _switch_cache.has(on):
		return _switch_cache[on]
	var img := Image.create(SWITCH_SIZE.x, SWITCH_SIZE.y, false, Image.FORMAT_RGBA8)
	var r: float = SWITCH_SIZE.y / 2.0
	var track: Color = UiTokens.PRIMARY if on else UiTokens.BG_DEEP
	var knob: Color = UiTokens.TEXT if on else UiTokens.TEXT_SECTION
	var kx: float = SWITCH_SIZE.x - r if on else r
	for y in SWITCH_SIZE.y:
		for x in SWITCH_SIZE.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var seg: float = clampf(p.x, r, SWITCH_SIZE.x - r)
			var d_track: float = p.distance_to(Vector2(seg, r)) - r
			var c := track
			c.a = clampf(0.5 - d_track, 0.0, 1.0)
			var k: float = clampf(0.5 - (p.distance_to(Vector2(kx, r)) - (r - 8.0)), 0.0, 1.0)
			img.set_pixel(x, y, c.lerp(knob, k) if k > 0.0 else c)
	var tex := ImageTexture.create_from_image(img)
	_switch_cache[on] = tex
	return tex
