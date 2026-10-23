class_name TubeView
extends Control
## Pojedyncza probowka: szklo (9-slice) + warstwy plynu rysowane w _draw().

signal tapped(index: int)

const LIQUID_MARGIN_X: float = 10.0
const LIQUID_MARGIN_BOTTOM: float = 14.0
const LIQUID_MARGIN_TOP: float = 40.0

var index: int = 0
var capacity: int = 4
var layers: Array = []
var liquids: Array = []

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


func _draw() -> void:
	var inner_h: float = size.y - LIQUID_MARGIN_TOP - LIQUID_MARGIN_BOTTOM
	var layer_h: float = inner_h / float(maxi(capacity, 1))
	var w: float = size.x - 2.0 * LIQUID_MARGIN_X
	for i: int in layers.size():
		var c: int = int(layers[i]) % liquids.size()
		var y: float = size.y - LIQUID_MARGIN_BOTTOM - layer_h * float(i + 1)
		draw_rect(Rect2(LIQUID_MARGIN_X, y, w, layer_h), liquids[c])
