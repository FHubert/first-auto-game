class_name BoardView
extends Control
## Widok planszy: rysuje probowki z GameRound, obsluguje tap, przelew i shake.

signal tube_selected(index: int)
signal pour_finished(from: int, to: int)
signal illegal_move(from: int, to: int)
signal round_won

const THEMES_PATH: String = "res://assets/themes.json"
const TEXTURE_DIR: String = "res://assets/sprites/tubes/"
const COLUMNS_PER_ROW: int = 5
const TUBE_WIDTH: float = 90.0
const TUBE_HEIGHT: float = 300.0
const GAP_X: float = 24.0
const GAP_Y: float = 40.0
const LIFT_PX: float = 30.0
const SHAKE_PX: float = 12.0

var round: GameRound
var theme_data: Dictionary = {}
var animate: bool = true

var _views: Array[TubeView] = []
var _rest: Array[Vector2] = []
var _selected: int = -1
var _busy: bool = false
var _bg: ColorRect
var _slice: Dictionary = {}


static func load_theme(theme_id: String) -> Dictionary:
	return ThemeCatalog.theme(theme_id).duplicate()


func _ready() -> void:
	animate = DisplayServer.get_name() != "headless"
	resized.connect(_layout)


func pour_duration() -> float:
	return float(GameConfig.get_value("pour_anim_seconds", 0.4))


func setup(round_in: GameRound, theme_id: String) -> void:
	round = round_in
	theme_data = load_theme(theme_id)
	_slice = theme_data.get("nine_slice", {})
	if _bg == null:
		_bg = ColorRect.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_bg)
		move_child(_bg, 0)
	_bg.color = Color(theme_data.get("background", "#000000"))
	_selected = -1
	_rebuild()


func tap(index: int) -> void:
	if _busy or round == null or index < 0 or index >= _views.size():
		return
	if _selected == -1:
		_selected = index
		_move_to(_views[index], _rest[index] + Vector2(0, -LIFT_PX), _lift_time())
		tube_selected.emit(index)
	elif _selected == index:
		_deselect()
	else:
		var from: int = _selected
		if round.try_move(from, index):
			await _pour(from, index)
		else:
			_deselect()
			_shake(_views[from])
			illegal_move.emit(from, index)


func refresh() -> void:
	if round == null:
		return
	if round.board().tube_count() != _views.size():
		_rebuild()
		return
	for i: int in _views.size():
		_views[i].set_layers(round.board().tubes[i])


func selected_index() -> int:
	return _selected


func tube_rect(index: int) -> Rect2:
	return Rect2(global_position + _rest[index], Vector2(TUBE_WIDTH, TUBE_HEIGHT))


func _lift_time() -> float:
	return float(GameConfig.get_value("tube_lift_seconds", 0.1))


func _deselect() -> void:
	if _selected >= 0 and _selected < _views.size():
		_move_to(_views[_selected], _rest[_selected], _lift_time())
	_selected = -1


func _pour(from: int, to: int) -> void:
	_busy = true
	if animate:
		var v: TubeView = _views[from]
		var target: Vector2 = _rest[to] + Vector2(0, -LIFT_PX)
		var half: float = pour_duration() * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(v, "position", target, half)
		tw.tween_property(v, "position", _rest[from], half)
		await tw.finished
	_selected = -1
	_views[from].position = _rest[from]
	refresh()
	_busy = false
	pour_finished.emit(from, to)
	if round.is_done():
		round_won.emit()


func _move_to(v: Control, pos: Vector2, seconds: float) -> void:
	if animate:
		create_tween().tween_property(v, "position", pos, seconds)
	else:
		v.position = pos


func _shake(v: Control) -> void:
	if not animate:
		return
	var base: Vector2 = v.position
	var part: float = float(GameConfig.get_value("shake_seconds", 0.2)) / 4.0
	var tw: Tween = create_tween()
	tw.tween_property(v, "position:x", base.x + SHAKE_PX, part)
	tw.tween_property(v, "position:x", base.x - SHAKE_PX, part * 2.0)
	tw.tween_property(v, "position:x", base.x, part)


func _rebuild() -> void:
	for v in _views:
		v.queue_free()
	_views.clear()
	var board: SortBoard = round.board()
	var file: String = "tube_body.png"
	if theme_data.get("shape", "tube") == "flask":
		file = "flask_body.png"
	var tex: Texture2D = load(TEXTURE_DIR + file)
	var glass := Color(theme_data.get("glass", "#FFFFFF"))
	var liquids: Array = []
	for c: String in theme_data.get("liquids", []):
		liquids.append(Color(c))
	for i: int in board.tube_count():
		var v := TubeView.new()
		v.size = Vector2(TUBE_WIDTH, TUBE_HEIGHT)
		v.setup(i, board.capacity, tex, _slice, glass, liquids)
		v.tapped.connect(tap)
		add_child(v)
		_views.append(v)
	_layout()
	refresh()


func _layout() -> void:
	_rest.clear()
	var n: int = _views.size()
	if n == 0:
		return
	var cols: int = mini(COLUMNS_PER_ROW, n)
	var rows: int = ceili(float(n) / float(cols))
	var total_h: float = rows * TUBE_HEIGHT + (rows - 1) * GAP_Y
	var origin_y: float = maxf((size.y - total_h) * 0.5, LIFT_PX)
	for i: int in n:
		var row: int = i / cols
		var in_row: int = mini(cols, n - row * cols)
		var row_w: float = in_row * TUBE_WIDTH + (in_row - 1) * GAP_X
		var x: float = (size.x - row_w) * 0.5 + (i % cols) * (TUBE_WIDTH + GAP_X)
		var pos := Vector2(x, origin_y + row * (TUBE_HEIGHT + GAP_Y))
		_rest.append(pos)
		_views[i].position = pos
		_views[i].size = Vector2(TUBE_WIDTH, TUBE_HEIGHT)
	_selected = -1
