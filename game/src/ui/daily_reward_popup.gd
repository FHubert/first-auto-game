class_name DailyRewardPopup
extends Control
## Popup nagrody dziennej: 7 kafelkow, "Odbierz", wariant "Uratuj streak".
## MVP: "Uratuj streak" dziala bez reklamy (wprost DailyRewards.save_streak);
## G-010 podmieni to na Ads.request_rewarded i odkryje claim_x2_button.

signal claimed(amount: int)
signal streak_saved
signal closed

const FONT_SIZE: int = 32
const TILE_FONT_SIZE: int = 24
const BUTTON_HEIGHT: int = 90
const TILE_COUNT: int = 7
const ACTIVE_TINT: Color = Color(1.0, 0.85, 0.3)
const SAMPLE_DAY: int = 20750

var state: GameState
var rewarded: RewardedPlacements = RewardedPlacements.new()
var title_label: Label
var streak_label: Label
var claim_button: Button
var claim_x2_button: Button
var save_streak_button: Button
var close_button: Button
var tiles: Array[PanelContainer] = []

var _utc_day: int = 0


func _ready() -> void:
	Locale.ensure_installed()
	_build()
	if get_parent() == get_tree().root:
		show_sample()


func show_for(state_in: GameState, utc_day: int) -> void:
	state = state_in
	_utc_day = utc_day
	var pv: Dictionary = DailyRewards.preview(state, utc_day)
	var active: int = int(pv["cycle_day"])
	for i in tiles.size():
		tiles[i].modulate = ACTIVE_TINT if i + 1 == active else Color.WHITE
	title_label.text = tr("daily_title")
	streak_label.text = tr("daily_streak") % state.streak_days
	claim_button.disabled = not bool(pv["can_claim"])
	save_streak_button.visible = (
		pv["status"] == DailyRewards.REASON_GRACE and DailyRewards.can_save_streak(state, utc_day)
	)
	visible = true


func show_sample() -> void:
	show_for(GameState.new(), SAMPLE_DAY)


func _on_claim() -> void:
	var amount: int = DailyRewards.claim(state, _utc_day)
	SaveSystem.save(state)
	claimed.emit(amount)
	visible = false


func claim_x2() -> bool:
	if not DailyRewards.can_claim(state, _utc_day):
		return false
	return rewarded.offer(
		RewardedPlacements.DAILY_X2,
		func() -> void:
			var amount: int = DailyRewards.claim(state, _utc_day, true)
			SaveSystem.save(state)
			claimed.emit(amount)
			visible = false
	)


func save_streak_rewarded() -> bool:
	if not DailyRewards.can_save_streak(state, _utc_day):
		return false
	return rewarded.offer(
		RewardedPlacements.STREAK_SAVE,
		func() -> void:
			if DailyRewards.save_streak(state, _utc_day):
				SaveSystem.save(state)
				streak_saved.emit()
			show_for(state, _utc_day)
	)


func preview_x2_amount() -> int:
	var amount: int = int(DailyRewards.preview(state, _utc_day)["amount"])
	return int(round(amount * float(GameConfig.get_value("rewarded_multiplier"))))


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(680, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	title_label = _label(box, FONT_SIZE)
	streak_label = _label(box, FONT_SIZE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for d in range(1, TILE_COUNT + 1):
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		tile.add_child(col)
		_label(col, TILE_FONT_SIZE).text = str(d)
		_label(col, TILE_FONT_SIZE).text = str(DailyRewards.reward_for_cycle_day(d))
		row.add_child(tile)
		tiles.append(tile)
	claim_button = _button(box, "btn_claim", _on_claim)
	claim_x2_button = _button(box, "btn_claim_x2", claim_x2)
	claim_x2_button.visible = false
	save_streak_button = _button(box, "btn_save_streak", save_streak_rewarded)
	save_streak_button.visible = false
	close_button = _button(box, "btn_close", _on_close)


func _on_close() -> void:
	visible = false
	closed.emit()


func _label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _button(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b
