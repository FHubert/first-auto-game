class_name TutorialOverlay
extends Control
## Nakladka tutorialu: komunikat na dole i "dlon" (kwadrat) nad wskazana probowka.

const ACCENT: Color = Color("#FFD166")
const HAND_SIZE: Vector2 = Vector2(40, 40)
const HAND_GAP: float = 8.0
const PULSE_SECONDS: float = 0.5
const PULSE_SHIFT: float = 12.0
const TEXT_BOTTOM: float = 160.0
const FONT_SIZE: int = 32

var hand: ColorRect
var label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hand = ColorRect.new()
	hand.color = ACCENT
	hand.size = HAND_SIZE
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand)
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -TEXT_BOTTOM
	label.offset_bottom = -TEXT_BOTTOM + 60.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", ACCENT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	visible = false


func point_at(rect: Rect2, text: String) -> void:
	var base := Vector2(rect.position.x + (rect.size.x - HAND_SIZE.x) * 0.5, 0.0)
	base.y = rect.position.y - HAND_SIZE.y - HAND_GAP
	hand.position = base - global_position
	label.text = text
	visible = true
	if _tween != null:
		_tween.kill()
	if DisplayServer.get_name() != "headless":
		_tween = create_tween().set_loops()
		_tween.tween_property(hand, "position:y", hand.position.y + PULSE_SHIFT, PULSE_SECONDS)
		_tween.tween_property(hand, "position:y", hand.position.y, PULSE_SECONDS)


func hide_hand() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	visible = false
