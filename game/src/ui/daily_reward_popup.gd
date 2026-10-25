class_name DailyRewardPopup
extends Control
## Popup nagrody dziennej: 7 kafelkow, "Odbierz", wariant "Uratuj streak".
## MVP: "Uratuj streak" dziala bez reklamy (wprost DailyRewards.save_streak);
## G-010 podmieni to na Ads.request_rewarded i odkryje claim_x2_button.

signal claimed(amount: int)
signal streak_saved
signal closed

const TILE_COUNT: int = 7
const CARD_TOP: int = 220
const CARD_MARGIN: int = 30
const CARD_PAD_X: int = 33
const GAP: int = 15
const TILE_H: int = 150
const TILE_CLAIMED_BG: Color = Color("#132444")
const COIN_SIZE: int = 48
const COIN_SIZE_WIDE: int = 56
const CHECK_BADGE: int = 44
const ENTER_TIME: float = 0.18
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
var checks: Array[Control] = []

var _dim: ColorRect
var _content: Control
var _card: PanelContainer
var _coins: Array[TextureRect] = []
var _day_labels: Array[Label] = []
var _amount_labels: Array[Label] = []

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
	var was_visible: bool = visible
	for i in tiles.size():
		_style_tile(i, active)
	title_label.text = tr("daily_title")
	streak_label.text = tr("daily_streak") % state.streak_days
	claim_button.text = "%s %d" % [tr("btn_claim"), int(pv["amount"])]
	claim_button.disabled = not bool(pv["can_claim"])
	claim_x2_button.text = tr("btn_claim_x2") % preview_x2_amount()
	claim_x2_button.visible = (
		bool(pv["can_claim"]) and rewarded.can_offer(RewardedPlacements.DAILY_X2)
	)
	save_streak_button.visible = (
		pv["status"] == DailyRewards.REASON_GRACE
		and DailyRewards.can_save_streak(state, utc_day)
		and rewarded.can_offer(RewardedPlacements.STREAK_SAVE)
	)
	visible = true
	if not was_visible:
		_enter_fx()


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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(UiTokens.DIM, 0.70)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"Card"
	_card.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_card.offset_left = CARD_MARGIN
	_card.offset_right = -CARD_MARGIN
	_card.offset_top = CARD_TOP
	_card.offset_bottom = CARD_TOP
	_card.add_theme_stylebox_override("panel", _card_style())
	_content.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	_card.add_child(box)
	_build_header(box)
	_build_grid(box)
	claim_button = _button(box, &"ButtonPrimary", "", _on_claim)
	claim_x2_button = _button(box, &"ButtonAccent", "video", claim_x2)
	claim_x2_button.visible = false
	save_streak_button = _button(box, &"ButtonAccent", "video", save_streak_rewarded)
	save_streak_button.text = tr("btn_save_streak")
	save_streak_button.visible = false
	close_button = Button.new()
	close_button.theme_type_variation = &"ButtonIcon"
	close_button.icon = UiTokens.icon("close")
	close_button.expand_icon = true
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.add_theme_constant_override("icon_max_width", 40)
	close_button.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN, UiTokens.TOUCH_MIN)
	close_button.pressed.connect(_on_close)
	_content.add_child(close_button)
	_card.resized.connect(_place_close)


func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.CARD
	sb.set_corner_radius_all(UiTokens.CARD_RADIUS)
	sb.content_margin_left = CARD_PAD_X
	sb.content_margin_right = CARD_PAD_X
	sb.content_margin_top = 52
	sb.content_margin_bottom = 41
	return sb


func _place_close() -> void:
	close_button.position = Vector2(
		_card.position.x + _card.size.x - UiTokens.TOUCH_MIN - 20, _card.position.y + 20
	)


func _build_header(box: VBoxContainer) -> void:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTokens.STREAK, 0.18)
	sb.set_corner_radius_all(63)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pill.add_theme_stylebox_override("panel", sb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	pill.add_child(row)
	var icon := _icon("streak", 33)
	icon.modulate = UiTokens.STREAK
	row.add_child(icon)
	streak_label = _label(row, UiTokens.FONT_SM, UiTokens.STREAK_SOFT)
	streak_label.theme_type_variation = &"LabelCaption"
	streak_label.add_theme_color_override("font_color", UiTokens.STREAK_SOFT)
	title_label = _label(box, UiTokens.FONT_OVERLAY, UiTokens.TEXT)
	title_label.theme_type_variation = &"LabelTitle"
	title_label.add_theme_font_size_override("font_size", UiTokens.FONT_OVERLAY)
	var sub := _label(box, UiTokens.FONT_SM, UiTokens.TEXT_MUTED)
	sub.text = tr("daily_subtitle")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 100
	box.move_child(sub, title_label.get_index() + 1)


func _build_grid(box: VBoxContainer) -> void:
	var rows: Array[HBoxContainer] = []
	for r in 2:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", GAP)
		box.add_child(h)
		rows.append(h)
	for d in range(1, TILE_COUNT + 1):
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(0, TILE_H)
		if d == TILE_COUNT:
			tile.size_flags_stretch_ratio = 2.0
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		tile.add_child(col)
		var day := _label(col, UiTokens.FONT_XS, UiTokens.TEXT_MUTED)
		var wide: bool = d == TILE_COUNT
		var coin := _icon("coin", COIN_SIZE_WIDE if wide else COIN_SIZE)
		coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(coin)
		var amount := _label(col, UiTokens.FONT_SM, UiTokens.TEXT)
		amount.text = str(DailyRewards.reward_for_cycle_day(d))
		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(overlay)
		var chk := _check_badge()
		overlay.add_child(chk)
		rows[0 if d <= 4 else 1].add_child(tile)
		tiles.append(tile)
		checks.append(chk)
		_coins.append(coin)
		_day_labels.append(day)
		_amount_labels.append(amount)


func _check_badge() -> Control:
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.PRIMARY
	sb.set_corner_radius_all(CHECK_BADGE)
	sb.set_border_width_all(4)
	sb.border_color = UiTokens.CARD
	badge.add_theme_stylebox_override("panel", sb)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = 13 - CHECK_BADGE
	badge.offset_right = 13
	badge.offset_top = -13
	badge.offset_bottom = CHECK_BADGE - 13
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _icon("check", 28)
	icon.modulate = UiTokens.ON_PRIMARY
	badge.add_child(icon)
	badge.visible = false
	return badge


func _style_tile(i: int, active: int) -> void:
	var day: int = i + 1
	var claimed: bool = day < active
	var today: bool = day == active
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(UiTokens.TILE_RADIUS)
	sb.bg_color = (
		UiTokens.CARD_ICON if today else (TILE_CLAIMED_BG if claimed else UiTokens.CARD_ROW)
	)
	if today:
		sb.set_border_width_all(4)
		sb.border_color = UiTokens.ACCENT
	tiles[i].add_theme_stylebox_override("panel", sb)
	checks[i].visible = claimed
	_coins[i].modulate.a = 0.45 if claimed else 1.0
	_day_labels[i].text = tr("daily_day") % day
	_day_labels[i].add_theme_color_override(
		"font_color", UiTokens.ACCENT if today else UiTokens.TEXT_MUTED
	)
	_amount_labels[i].add_theme_color_override(
		"font_color",
		UiTokens.ACCENT if today else (UiTokens.TEXT_MUTED if claimed else UiTokens.TEXT)
	)


# T-267: do zastapienia OverlayFx.enter po merge T-233
func _enter_fx() -> void:
	var parent: Node = get_parent()
	if (
		DisplayServer.get_name() == "headless"
		or (parent != null and "effects_enabled" in parent and not parent.effects_enabled)
	):
		_content.scale = Vector2.ONE
		_content.modulate.a = 1.0
		return
	_content.pivot_offset = Vector2(
		size.x * 0.5, CARD_TOP + _card.get_combined_minimum_size().y * 0.5
	)
	_content.scale = Vector2(0.9, 0.9)
	_content.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_content, "scale", Vector2.ONE, ENTER_TIME)
	tw.tween_property(_content, "modulate:a", 1.0, ENTER_TIME)


func _on_close() -> void:
	visible = false
	closed.emit()


func _icon(name: String, px: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UiTokens.icon(name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(px, px)
	return icon


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, variation: StringName, icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, UiTokens.BTN_H)
	if icon_name != "":
		b.icon = UiTokens.icon(icon_name)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 48)
		for c in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_color_override("icon_%s_color" % c, UiTokens.ON_ACCENT)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
