class_name TubeView
extends Control
## Pojedyncza probowka: szklo rysowane w _draw() + warstwy plynu rysowane w _draw().

signal tapped(index: int)

## Geometria wg UiTokens (px dla TUBE_W x TUBE_H); przy innym rozmiarze skaluje k = size.x / TUBE_W.
const LIQUID_MARGIN: float = float(UiTokens.TUBE_OUTLINE + UiTokens.TUBE_PAD)
const LIQUID_MARGIN_TOP: float = float(
	UiTokens.TUBE_H - UiTokens.TUBE_OUTLINE - UiTokens.TUBE_PAD - 4 * UiTokens.TUBE_LAYER_H
)
const BOTTOM_RADIUS: float = float(UiTokens.TUBE_RADIUS) - LIQUID_MARGIN
const ARC_SEGMENTS: int = 8
const GLASS_ARC_SEGMENTS: int = 14

var index: int = 0
var capacity: int = 4
var layers: Array = []
var liquids: Array = []
var glass: Color = Color.WHITE
var selected: bool = false
var show_symbols: bool = false
var symbols_drawn: int = 0


func setup(
	index_in: int,
	capacity_in: int,
	_texture: Texture2D,
	_slice: Dictionary,
	glass_in: Color,
	liquids_in: Array
) -> void:
	index = index_in
	capacity = capacity_in
	liquids = liquids_in
	glass = glass_in
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_selected(on: bool) -> void:
	selected = on
	queue_redraw()


static func scale_for(view_size: Vector2) -> float:
	return view_size.x / float(UiTokens.TUBE_W)


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
	var k: float = scale_for(view_size)
	var top: float = LIQUID_MARGIN_TOP * k
	return Rect2(
		LIQUID_MARGIN * k,
		top,
		view_size.x - 2.0 * LIQUID_MARGIN * k,
		view_size.y - top - LIQUID_MARGIN * k
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


## Sciezka od lewej-gornej krawedzi, w dol, luk dna, w gore do prawej-gornej (gora prosta).
static func bottom_round_path(rect: Rect2, radius: float) -> PackedVector2Array:
	var r: float = minf(radius, rect.size.x * 0.5)
	var pts := PackedVector2Array()
	pts.append(rect.position)
	var left_c := Vector2(rect.position.x + r, rect.end.y - r)
	var right_c := Vector2(rect.end.x - r, rect.end.y - r)
	for k: int in GLASS_ARC_SEGMENTS + 1:
		var a: float = PI - (PI * 0.5) * float(k) / float(GLASS_ARC_SEGMENTS)
		pts.append(left_c + Vector2(cos(a), sin(a)) * r)
	for k: int in GLASS_ARC_SEGMENTS + 1:
		var a: float = PI * 0.5 - (PI * 0.5) * float(k) / float(GLASS_ARC_SEGMENTS)
		pts.append(right_c + Vector2(cos(a), sin(a)) * r)
	pts.append(Vector2(rect.end.x, rect.position.y))
	return pts


func _draw_glass(k: float) -> void:
	var edge: Color = glass
	edge.a = UiTokens.GLASS_ALPHA_SELECTED if selected else UiTokens.GLASS_ALPHA
	var fill: Color = glass
	fill.a = UiTokens.GLASS_INNER_ALPHA
	var o: float = float(UiTokens.TUBE_OUTLINE) * k
	var radius: float = float(UiTokens.TUBE_RADIUS) * k
	draw_colored_polygon(
		bottom_round_path(Rect2(o, 0.0, size.x - 2.0 * o, size.y - o), radius - o), fill
	)
	var half: float = o * 0.5
	var line := bottom_round_path(Rect2(half, 0.0, size.x - o, size.y - half), radius - half)
	draw_polyline(line, edge, o, true)
	var rim := StyleBoxFlat.new()
	rim.bg_color = edge
	rim.set_corner_radius_all(int(ceil(float(UiTokens.TUBE_RIM_H) * k * 0.5)))
	var rw: float = float(UiTokens.TUBE_RIM_W) * k
	var rh: float = float(UiTokens.TUBE_RIM_H) * k
	draw_style_box(
		rim, Rect2((size.x - rw) * 0.5, -(rh - float(UiTokens.TUBE_RIM_OVERLAP) * k), rw, rh)
	)


func _draw_highlight(k: float) -> void:
	var hl := Color(1.0, 1.0, 1.0, UiTokens.TUBE_HIGHLIGHT_ALPHA)
	var x: float = float(UiTokens.TUBE_OUTLINE + UiTokens.TUBE_HIGHLIGHT_X) * k
	var top: float = float(UiTokens.TUBE_HIGHLIGHT_TOP) * k
	var bottom: float = size.y - float(UiTokens.TUBE_OUTLINE + UiTokens.TUBE_HIGHLIGHT_BOTTOM) * k
	var box := StyleBoxFlat.new()
	box.bg_color = hl
	box.set_corner_radius_all(int(ceil(float(UiTokens.TUBE_HIGHLIGHT_RADIUS) * k)))
	draw_style_box(box, Rect2(x, top, float(UiTokens.TUBE_HIGHLIGHT_W) * k, bottom - top))


func _draw() -> void:
	symbols_drawn = 0
	var k: float = scale_for(size)
	_draw_glass(k)
	if not liquids.is_empty():
		for i: int in layers.size():
			var c: int = int(layers[i]) % liquids.size()
			var rect: Rect2 = layer_rect(size, capacity, i)
			draw_colored_polygon(layer_polygon(rect, i == 0, BOTTOM_RADIUS * k), liquids[c])
			if show_symbols:
				var tint: Color = ColorSymbols.symbol_color(liquids[c])
				tint.a = ColorSymbols.SYMBOL_ALPHA
				draw_colored_polygon(ColorSymbols.polygon(c, rect), tint)
				symbols_drawn += 1
	_draw_highlight(k)
