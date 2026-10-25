class_name UiFx
extends RefCounted
## UI v2 (T-235): mikroanimacje na przekazanym wezle. Statyczne; przy `enabled=false`
## ustawiaja stan koncowy od razu i zwracaja null. Tweeny rejestrowane w meta wezla.

const META: String = "ui_fx_tweens"
const PRESS_SCALE: float = 0.94
const PRESS_SECONDS: float = 0.08
const POP_SCALE: float = 1.3
const POP_SECONDS: float = 0.15
const COUNT_SECONDS: float = 0.6
const PULSE_SCALE: float = 1.08
const PULSE_SECONDS: float = 0.45
const COIN_COUNT: int = 5
const COIN_SECONDS: float = 0.5
const COIN_SIZE: float = 40.0
const COIN_SPREAD: float = 30.0
const COIN_DELAY: float = 0.05
const COIN_FADE: float = 0.1


static func _register(node: Node, tw: Tween) -> Tween:
	var list: Array = node.get_meta(META, []) as Array
	list = list.filter(func(t: Variant) -> bool: return t != null and (t as Tween).is_valid())
	list.append(tw)
	node.set_meta(META, list)
	return tw


static func kill_all(node: Control) -> void:
	for t: Variant in node.get_meta(META, []) as Array:
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()
	node.set_meta(META, [])


static func active_count(node: Control) -> int:
	var n: int = 0
	for t: Variant in node.get_meta(META, []) as Array:
		if t != null and (t as Tween).is_valid() and (t as Tween).is_running():
			n += 1
	return n


static func _center(node: Control) -> void:
	var s: Vector2 = node.size
	if s.x <= 0.0 or s.y <= 0.0:
		s = node.get_combined_minimum_size()
	node.pivot_offset = s / 2.0


static func press(button: Control, enabled: bool) -> Tween:
	if not enabled or not button.is_inside_tree():
		button.scale = Vector2.ONE
		return null
	kill_all(button)
	_center(button)
	var tw: Tween = button.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(button, "scale", Vector2.ONE * PRESS_SCALE, PRESS_SECONDS)
	tw.tween_property(button, "scale", Vector2.ONE, PRESS_SECONDS)
	return _register(button, tw)


static func attach_press(button: Button, enabled_getter: Callable) -> void:
	button.button_down.connect(func() -> void: press(button, bool(enabled_getter.call())))


static func pop(node: Control, enabled: bool) -> Tween:
	if not enabled or not node.is_inside_tree():
		node.scale = Vector2.ONE
		return null
	kill_all(node)
	_center(node)
	node.scale = Vector2.ONE * POP_SCALE
	var tw: Tween = node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, POP_SECONDS)
	return _register(node, tw)


## `force` ignoruje headless (testy sciezki tweena).
static func count_up(
	label: Label, to: int, seconds: float, fmt: String, enabled: bool, force: bool = false
) -> Tween:
	var headless: bool = DisplayServer.get_name() == "headless" and not force
	if not enabled or headless or not label.is_inside_tree():
		label.text = fmt % to
		return null
	kill_all(label)
	label.text = fmt % 0
	var tw: Tween = label.create_tween()
	tw.tween_method(func(v: float) -> void: label.text = fmt % int(v), 0.0, float(to), seconds)
	tw.finished.connect(func() -> void: label.text = fmt % to)
	return _register(label, tw)


static func pulse(node: Control, enabled: bool) -> Tween:
	if not enabled or not node.is_inside_tree():
		return null
	kill_all(node)
	_center(node)
	var tw: Tween = node.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2.ONE * PULSE_SCALE, PULSE_SECONDS)
	tw.tween_property(node, "scale", Vector2.ONE, PULSE_SECONDS)
	return _register(node, tw)


static func stop_pulse(node: Control) -> void:
	kill_all(node)
	node.scale = Vector2.ONE


static func fly_coins(
	parent: Control,
	from: Vector2,
	to: Vector2,
	enabled: bool,
	count: int = COIN_COUNT,
	seconds: float = COIN_SECONDS
) -> void:
	if not enabled or DisplayServer.get_name() == "headless" or not parent.is_inside_tree():
		return
	var tex: Texture2D = UiTokens.icon("coin")
	for i in count:
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.size = Vector2(COIN_SIZE, COIN_SIZE)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jitter := Vector2(
			randf_range(-COIN_SPREAD, COIN_SPREAD), randf_range(-COIN_SPREAD, COIN_SPREAD)
		)
		c.position = from + jitter - c.size / 2.0
		parent.add_child(c)
		var tw: Tween = c.create_tween()
		tw.set_parallel(true)
		var delay: float = float(i) * COIN_DELAY
		var move := tw.tween_property(c, "position", to - c.size / 2.0, seconds)
		move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(delay)
		var fade := tw.tween_property(c, "modulate:a", 0.0, COIN_FADE)
		fade.set_delay(delay + seconds - COIN_FADE)
		tw.chain().tween_callback(c.queue_free)
