class_name TubeView
extends Control
## Pojedyncza probowka: szklo (9-slice) + warstwy plynu rysowane w _draw().

signal tapped(index: int)

## Wnetrze szkla wg tools/gen_assets.py::tube_image (sprite 128x384, 9-slice 24/48):
## maska wewn. (12, 12, 115, 371), promien dolnych rogow 36 => lewy margines 12,
## prawy 128-115 = 13, dol 13. Narozniki 9-slice nie sa skalowane.
const LIQUID_MARGIN_X: float = 12.0
const LIQUID_MARGIN_RIGHT: float = 13.0
const LIQUID_MARGIN_BOTTOM: float = 13.0
const LIQUID_MARGIN_TOP: float = 40.0
const BOTTOM_RADIUS: float = 36.0
const ARC_SEGMENTS: int = 8
const SYMBOL_LIGHT: Color = Color("#FFFFFF", 0.85)
const SYMBOL_DARK: Color = Color("#14213D")
const SYMBOL_DARK_LUMINANCE: float = 0.6

var index: int = 0
var capacity: int = 4
var layers: Array = []
var liquids: Array = []
var show_symbols: bool = false
var symbols_drawn: int = 0

var _body: NinePatchRect


func setup(
	index_in: int,
	capacity_in: int,
	texture: Texture2D,
	slice: Dictionary,
	glass: Color,
	liquids_in: Array
) -> void:
	index = index_in
	capacity = capacity_in
	liquids = liquids_in
	_body = NinePatchRect.new()
	_body.texture = texture
	_body.modulate = glass
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.patch_margin_left = int(slice.get("left", 24))
	_body.patch_margin_right = int(slice.get("right", 24))
	_body.patch_margin_top = int(slice.get("top", 48))
	_body.patch_margin_bottom = int(slice.get("bottom", 48))
	add_child(_body)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_layers(layers_in: Array) -> void:
	layers = layers_in
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		tapped.emit(index)


static func inner_rect(view_size: Vector2) -> Rect2:
	return Rect2(
		LIQUID_MARGIN_X,
		LIQUID_MARGIN_TOP,
		view_size.x - LIQUID_MARGIN_X - LIQUID_MARGIN_RIGHT,
		view_size.y - LIQUID_MARGIN_TOP - LIQUID_MARGIN_BOTTOM
	)


static func layer_rect(view_size: Vector2, capacity_in: int, i: int) -> Rect2:
	var inner: Rect2 = inner_rect(view_size)
	var layer_h: float = inner.size.y / float(maxi(capacity_in, 1))
	return Rect2(inner.position.x, inner.end.y - layer_h * float(i + 1), inner.size.x, layer_h)


static func layer_polygon(rect: Rect2, rounded_bottom: bool, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(rect.position)
	pts.append(Vector2(rect.end.x, rect.position.y))
	if not rounded_bottom:
		pts.append(rect.end)
		pts.append(Vector2(rect.position.x, rect.end.y))
		return pts
	var r: float = minf(radius, minf(rect.size.y, rect.size.x * 0.5))
	var right_c := Vector2(rect.end.x - r, rect.end.y - r)
	var left_c := Vector2(rect.position.x + r, rect.end.y - r)
	for k: int in ARC_SEGMENTS:
		var a: float = (PI * 0.5) * float(k) / float(ARC_SEGMENTS - 1)
		pts.append(right_c + Vector2(cos(a), sin(a)) * r)
	for k: int in ARC_SEGMENTS:
		var a: float = PI * 0.5 + (PI * 0.5) * float(k) / float(ARC_SEGMENTS - 1)
		pts.append(left_c + Vector2(cos(a), sin(a)) * r)
	return pts


func set_symbols(on: bool) -> void:
	show_symbols = on
	queue_redraw()


func _draw() -> void:
	symbols_drawn = 0
	if liquids.is_empty():
		return
	for i: int in layers.size():
		var c: int = int(layers[i]) % liquids.size()
		var rect: Rect2 = layer_rect(size, capacity, i)
		draw_colored_polygon(layer_polygon(rect, i == 0, BOTTOM_RADIUS), liquids[c])
		if show_symbols:
			var tint: Color = SYMBOL_LIGHT
			if (liquids[c] as Color).get_luminance() > SYMBOL_DARK_LUMINANCE:
				tint = SYMBOL_DARK
			draw_colored_polygon(ColorSymbols.polygon(c, rect), tint)
			symbols_drawn += 1
