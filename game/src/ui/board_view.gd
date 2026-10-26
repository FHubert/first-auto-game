class_name BoardView
extends Control
## Widok planszy: rysuje probowki z GameRound, obsluguje tap, przelew i shake.

signal tube_selected(index: int)
signal tube_deselected(index: int)
signal pour_finished(from: int, to: int)
signal illegal_move(from: int, to: int)
signal round_won
signal tube_pulsed(index: int)

const TEXTURE_DIR: String = "res://assets/sprites/tubes/"
const COLUMNS_PER_ROW: int = UiTokens.BOARD_MAX_COLS
const TUBE_WIDTH: float = float(UiTokens.TUBE_W)
const TUBE_HEIGHT: float = float(UiTokens.TUBE_H)
const GAP_X: float = float(UiTokens.TUBE_GAP_X)
const GAP_Y: float = float(UiTokens.TUBE_GAP_Y)
const LIFT_PX: float = float(UiTokens.TUBE_LIFT)
const SHAKE_PX: float = 12.0
const POUR_LIFT_RATIO: float = 0.25
const POUR_TRANSFER_RATIO: float = 0.5
const POUR_RETURN_RATIO: float = 0.25
const TILT_DEG: float = 35.0
const TUBE_FULL_PULSE_SCALE: float = 1.08

var round: GameRound
var theme_data: Dictionary = {}
var theme_id: String = ""
var animate: bool = true
var show_symbols: bool = false
## Wszystkie probowki w jednym rzedzie (ekran wygranej); scale_for skaluje w dol.
var single_row: bool = false
## Liczba rzedow w trybie single_row (1 = jak dotad; T-316).
var win_rows: int = 1

var _views: Array[TubeView] = []
var _rest: Array[Vector2] = []
var _selected: int = -1
var _busy: bool = false
var _bg: ColorRect
var _slice: Dictionary = {}
var _scale: float = 1.0
var _pour_tween: Tween
var _pour_pending: Vector2i = Vector2i(-1, -1)
var _pulse_tween: Tween
var _pulse_index: int = -1


static func load_theme(theme_id: String) -> Dictionary:
	return ThemeCatalog.theme(theme_id).duplicate()


func _ready() -> void:
	animate = DisplayServer.get_name() != "headless"
	resized.connect(_layout)


func set_single_row(on: bool, rows: int = 1) -> void:
	single_row = on
	win_rows = maxi(rows, 1)
	if not _views.is_empty():
		_layout()


func set_show_symbols(on: bool) -> void:
	show_symbols = on
	for v: TubeView in _views:
		v.set_symbols(on)


func pour_duration() -> float:
	return float(GameConfig.get_value("pour_anim_seconds"))


func setup(round_in: GameRound, theme_id_in: String) -> void:
	_stop_pulse()
	_cancel_pour()
	round = round_in
	theme_id = theme_id_in
	theme_data = load_theme(theme_id_in)
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


## Zmienia motyw (paleta, tlo, ksztalt) bez resetu rundy.
func apply_theme(theme_id_in: String) -> void:
	if round == null:
		return
	theme_id = theme_id_in
	theme_data = load_theme(theme_id_in)
	_slice = theme_data.get("nine_slice", {})
	if _bg != null:
		_bg.color = Color(theme_data.get("background", "#000000"))
	_rebuild()


func tap(index: int) -> void:
	if _busy or round == null or index < 0 or index >= _views.size():
		return
	if _selected == -1:
		_selected = index
		_views[index].set_selected(true)
		_move_to(_views[index], _rest[index] + Vector2(0, -_lift()), _lift_time())
		tube_selected.emit(index)
	elif _selected == index:
		_deselect()
	else:
		var from: int = _selected
		if round.try_move(from, index):
			_pour(from, index)
		else:
			_deselect()
			_shake(_views[from])
			illegal_move.emit(from, index)


func refresh() -> void:
	if round == null:
		return
	_stop_pulse()
	if round.board().tube_count() != _views.size():
		_rebuild()
		return
	for i: int in _views.size():
		_views[i].set_layers(round.board().tubes[i])


func selected_index() -> int:
	return _selected


func is_busy() -> bool:
	return _busy


func view_layers(index: int) -> Array:
	return _views[index].layers


func view_liquids(index: int) -> Array:
	return _views[index].liquids


func view_scale(index: int) -> Vector2:
	return _views[index].scale


func view_rotation(index: int) -> float:
	return _views[index].rotation_degrees


func tube_rect(index: int) -> Rect2:
	return Rect2(global_position + _rest[index], _tube_size())


func _tube_size() -> Vector2:
	return Vector2(TUBE_WIDTH, TUBE_HEIGHT) * _scale


func _lift() -> float:
	return LIFT_PX * _scale


func _lift_time() -> float:
	return float(GameConfig.get_value("tube_lift_seconds"))


func _deselect() -> void:
	var prev: int = _selected
	if prev >= 0 and prev < _views.size():
		_views[prev].set_selected(false)
		_move_to(_views[prev], _rest[prev], _lift_time())
	_selected = -1
	if prev >= 0:
		tube_deselected.emit(prev)


func _pour(from: int, to: int) -> void:
	_busy = true
	_pour_pending = Vector2i(from, to)
	_selected = -1
	if not animate:
		_finish_pour()
		return
	# Widoki trzymaja referencje do tubes (stan koncowy), wiec stan "przed" odtwarzamy.
	var board: SortBoard = round.board()
	var moved: int = maxi(board.last_pour_amount, 1)
	var color: int = int(board.tubes[to][-1])
	var src_before: Array = (board.tubes[from] as Array).duplicate()
	for _k in moved:
		src_before.append(color)
	var dst_before: Array = (board.tubes[to] as Array).slice(0, board.tubes[to].size() - moved)
	var total: float = pour_duration()
	var dir: float = -1.0 if _rest[to].x < _rest[from].x else 1.0
	var target: Vector2 = _rest[to] + Vector2(dir * _tube_size().x * 0.5, -_lift())
	var v: TubeView = _views[from]
	v.set_selected(false)
	v.pivot_offset = Vector2(_tube_size().x * 0.5, _tube_size().y)
	v.z_index = 1
	var tw: Tween = create_tween()
	_pour_tween = tw
	var t1: float = total * POUR_LIFT_RATIO
	tw.tween_property(v, "position", target, t1)
	tw.parallel().tween_property(v, "rotation_degrees", dir * TILT_DEG, t1)
	for k: int in range(1, moved + 1):
		tw.tween_interval(total * POUR_TRANSFER_RATIO / float(moved))
		tw.tween_callback(_apply_transfer_step.bind(from, to, src_before, dst_before, k))
	var t3: float = total * POUR_RETURN_RATIO
	tw.tween_property(v, "position", _rest[from], t3)
	tw.parallel().tween_property(v, "rotation_degrees", 0.0, t3)
	tw.tween_callback(_finish_pour)


func _apply_transfer_step(from: int, to: int, src_before: Array, dst_before: Array, k: int) -> void:
	if from >= _views.size() or to >= _views.size():
		return
	if not is_instance_valid(_views[from]) or not is_instance_valid(_views[to]):
		return
	_views[from].set_layers(src_before.slice(0, src_before.size() - k))
	_views[to].set_layers(dst_before + src_before.slice(src_before.size() - k))


func _finish_pour() -> void:
	if _pour_pending.x < 0:
		return
	var p: Vector2i = _pour_pending
	_pour_pending = Vector2i(-1, -1)
	_pour_tween = null
	if p.x < _views.size() and is_instance_valid(_views[p.x]):
		var v: TubeView = _views[p.x]
		if p.x < _rest.size():
			v.position = _rest[p.x]
		v.rotation_degrees = 0.0
		v.z_index = 0
	_selected = -1
	refresh()
	_busy = false
	pour_finished.emit(p.x, p.y)
	if round.is_done():
		round_won.emit()


func _cancel_pour() -> void:
	if _pour_tween != null and _pour_tween.is_valid():
		_pour_tween.kill()
	var p: Vector2i = _pour_pending
	_pour_tween = null
	_pour_pending = Vector2i(-1, -1)
	_busy = false
	if p.x >= 0 and p.x < _views.size() and is_instance_valid(_views[p.x]):
		_views[p.x].rotation_degrees = 0.0
		_views[p.x].z_index = 0


## Short scale pulse on a tube that was just closed (single colour, full).
func pulse_tube(index: int) -> void:
	if index < 0 or index >= _views.size():
		return
	_stop_pulse()
	_pulse_index = index
	tube_pulsed.emit(index)
	if not animate:
		return
	var v: TubeView = _views[index]
	v.pivot_offset = v.size * 0.5
	var half: float = float(GameConfig.get_value("tube_full_pulse_seconds")) * 0.5
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(v, "scale", Vector2.ONE * TUBE_FULL_PULSE_SCALE, half)
	_pulse_tween.tween_property(v, "scale", Vector2.ONE, half)
	_pulse_tween.tween_callback(_stop_pulse)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if (
		_pulse_index >= 0
		and _pulse_index < _views.size()
		and is_instance_valid(_views[_pulse_index])
	):
		_views[_pulse_index].scale = Vector2.ONE
	_pulse_index = -1
	_pulse_tween = null


func _abort_pour() -> void:
	if _pour_tween != null and _pour_tween.is_valid():
		_pour_tween.kill()
	_finish_pour()


func _move_to(v: Control, pos: Vector2, seconds: float) -> void:
	if animate:
		create_tween().tween_property(v, "position", pos, seconds)
	else:
		v.position = pos


func _shake(v: Control) -> void:
	if not animate:
		return
	var base: Vector2 = v.position
	var part: float = float(GameConfig.get_value("shake_seconds")) / 4.0
	var tw: Tween = create_tween()
	tw.tween_property(v, "position:x", base.x + SHAKE_PX, part)
	tw.tween_property(v, "position:x", base.x - SHAKE_PX, part * 2.0)
	tw.tween_property(v, "position:x", base.x, part)


func _rebuild() -> void:
	_abort_pour()
	_stop_pulse()
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
		v.size = _tube_size()
		v.setup(i, board.capacity, tex, _slice, glass, liquids)
		v.show_symbols = show_symbols
		v.tapped.connect(tap)
		add_child(v)
		_views.append(v)
	_layout()
	refresh()


## Liczba kolumn: <= 8 probowek -> max 4 w rzedzie; wiecej -> polowa (max 7).
static func columns_for(n: int, single_row: bool = false, win_rows: int = 1) -> int:
	if single_row:
		return maxi(ceili(float(n) / float(maxi(win_rows, 1))), 1)
	if n < UiTokens.BOARD_SCALED_FROM:
		return clampi(n, 1, UiTokens.BOARD_MAX_COLS)
	return mini(UiTokens.BOARD_MAX_COLS_SCALED, ceili(n / 2.0))


## Wspolczynnik skali planszy dla n probowek w obszarze avail (px).
static func scale_for(n: int, avail: Vector2, single_row: bool = false, win_rows: int = 1) -> float:
	if avail.x <= 0.0 or avail.y <= 0.0:
		return 1.0
	var cols: int = columns_for(n, single_row, win_rows)
	var rows: int = ceili(float(n) / float(cols))
	var w: float = cols * TUBE_WIDTH + (cols - 1) * GAP_X
	var gap_y: float = float(UiTokens.WIN_ROW_GAP) if single_row else GAP_Y
	var h: float = rows * TUBE_HEIGHT + (rows - 1) * gap_y + (0.0 if single_row else LIFT_PX)
	return minf(1.0, minf(avail.x / w, avail.y / h))


## Wysokosc zawartosci (rzedy probowek z odstepami, po skalowaniu).
func content_height() -> float:
	var cols: int = columns_for(_views.size(), single_row, win_rows)
	var rows: int = maxi(ceili(float(_views.size()) / float(cols)), 1)
	var gap_y: float = float(UiTokens.WIN_ROW_GAP) if single_row else GAP_Y
	return (rows * TUBE_HEIGHT + (rows - 1) * gap_y) * _scale


func _layout() -> void:
	_abort_pour()
	var prev: int = _selected
	_rest.clear()
	var n: int = _views.size()
	if n == 0:
		return
	var cols: int = columns_for(n, single_row, win_rows)
	var rows: int = ceili(float(n) / float(cols))
	var avail := Vector2(size.x - 2.0 * UiTokens.SCREEN_PAD, size.y)
	_scale = scale_for(n, avail, single_row, win_rows)
	var tsize: Vector2 = _tube_size()
	var gap := Vector2(GAP_X, float(UiTokens.WIN_ROW_GAP) if single_row else GAP_Y) * _scale
	var total_h: float = rows * tsize.y + (rows - 1) * gap.y
	var origin_y: float = maxf((size.y - total_h) * 0.5, 0.0 if single_row else _lift())
	for i: int in n:
		var row: int = i / cols
		var in_row: int = mini(cols, n - row * cols)
		var row_w: float = in_row * tsize.x + (in_row - 1) * gap.x
		var x: float = (size.x - row_w) * 0.5 + (i % cols) * (tsize.x + gap.x)
		var pos := Vector2(x, origin_y + row * (tsize.y + gap.y))
		_rest.append(pos)
		_views[i].position = pos
		_views[i].size = tsize
		_views[i].set_selected(false)
	_selected = -1
	if prev >= 0:
		tube_deselected.emit(prev)
