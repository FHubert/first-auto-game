extends GdUnitTestSuite

const W: int = 720
const H: int = 1280


func _host() -> Control:
	var host: Control = auto_free(Control.new())
	host.size = Vector2(W, H)
	host.theme = ScreenHeader.UI_THEME
	add_child(host)
	return host


func _round() -> GameRound:
	var r := GameRound.new()
	r.start(
		{
			"seed": 1,
			"level": 1,
			"difficulty": 0.0,
			"payload":
			{"capacity": 4, "colors": 2, "tubes": [[0, 1, 0, 1], [1, 0, 1, 0]], "min_moves": 1}
		}
	)
	return r


func _stuck() -> StuckPanel:
	var panel: StuckPanel = (load("res://src/ui/stuck_panel.tscn") as PackedScene).instantiate()
	_host().add_child(panel)
	panel.show_for(_round(), true, {"extra_tube": true, "undo_refill": true, "skip": true})
	return panel


func _wide_labels(n: Node, limit: float, out: Array[String]) -> void:
	if n is Label and (n as Label).is_visible_in_tree():
		var l := n as Label
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > limit:
			out.append(l.text)
	for c in n.get_children():
		_wide_labels(c, limit, out)


func test_overlay_fx_disabled_returns_null() -> void:
	var panel: Control = auto_free(Control.new())
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	add_child(panel)
	assert_object(OverlayFx.enter(panel, false)).is_null()
	assert_vector(panel.scale).is_equal(Vector2.ONE)
	assert_float(panel.modulate.a).is_equal(1.0)
	panel.scale = Vector2(0.5, 0.5)
	assert_object(OverlayFx.enter(panel, true)).is_null()
	assert_vector(panel.scale).is_equal(Vector2.ONE)


func test_stuck_panel_rows_touch_size() -> void:
	var panel := _stuck()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(panel.close_button.text).is_empty()
	assert_object(panel.close_button.icon).is_not_null()
	panel.hint_button.visible = true
	for b: Button in [
		panel.undo_button,
		panel.extra_tube_ad_button,
		panel.undo_refill_ad_button,
		panel.hint_button,
		panel.restart_button,
		panel.close_button,
	]:
		assert_bool(b.is_visible_in_tree()).is_true()
		assert_int(int(b.size.y)).is_greater_equal(UiTokens.TOUCH_MIN)
	# Pomin: widoczny tylko gdy runda go dopuszcza (can_skip) - tu nie.
	assert_bool(panel.skip_button.visible).is_false()
	assert_str(panel.undo_desc_label.text).contains(str(_round().counters.undo_charges))
	assert_bool(Rect2(0, 0, W, H).encloses(_panel_rect(panel))).is_true()


func test_close_button_circle_inside_panel() -> void:
	var panel := _stuck()
	await get_tree().process_frame
	await get_tree().process_frame
	var b: Button = panel.close_button
	assert_str(str(b.theme_type_variation)).is_equal("ButtonClose")
	assert_vector(b.size).is_equal_approx(Vector2(81, 81), Vector2(1, 1))
	assert_bool(_panel_rect(panel).encloses(b.get_global_rect())).is_true()
	assert_vector(b.get_theme_stylebox("normal").get_minimum_size()).is_equal(Vector2.ZERO)


func _panel_rect(panel: StuckPanel) -> Rect2:
	return (panel.get_node("Panel") as Control).get_global_rect()


func test_german_labels_not_clipped() -> void:
	var prev: String = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var panel := _stuck()
	panel.show_sample_rows()
	await get_tree().process_frame
	await get_tree().process_frame
	var limit: float = W - 2.0 * 22 - 2.0 * UiTokens.SCREEN_PAD
	var wide: Array[String] = []
	_wide_labels(panel, limit, wide)
	TranslationServer.set_locale(prev)
	assert_array(wide).is_empty()


func test_offer_rows_are_ad_or_price() -> void:
	var panel := _stuck()
	panel.show_for(_round(), true, {"extra_tube": true, "undo_refill": false})
	assert_bool(panel.extra_tube_ad_button.visible).is_true()
	assert_bool(panel.extra_tube_button.visible).is_false()
	assert_bool(panel.undo_refill_ad_button.visible).is_false()
	assert_bool(panel.undo_refill_button.visible).is_true()
	panel.show_for(_round(), true, {"extra_tube": false, "undo_refill": true})
	assert_bool(panel.extra_tube_ad_button.visible).is_false()
	assert_bool(panel.extra_tube_button.visible).is_true()
	assert_bool(panel.undo_refill_ad_button.visible).is_true()
	assert_bool(panel.undo_refill_button.visible).is_false()


func test_at_most_four_action_rows_visible() -> void:
	var panel := _stuck()
	for tube in [true, false]:
		for refill in [true, false]:
			panel.show_for(_round(), true, {"extra_tube": tube, "undo_refill": refill})
			panel.hint_button.visible = true
			var rows: int = 0
			for c in panel.get_node("Panel/Box").get_children():
				if c is Button and c != panel.close_button and (c as Button).visible:
					rows += 1
			assert_int(rows).is_less_equal(4)


func test_hint_row_emits_and_hides() -> void:
	var panel := _stuck()
	var fired: Array[int] = [0]
	panel.hint_pressed.connect(func() -> void: fired[0] += 1)
	panel.show_sample_rows()
	assert_bool(panel.hint_button.visible).is_true()
	panel.hint_button.pressed.emit()
	assert_int(fired[0]).is_equal(1)
	assert_bool(panel.visible).is_false()


func test_hint_row_hidden_without_solution() -> void:
	var panel := _stuck()
	assert_bool(panel.hint_button.visible).is_equal(_round().moves_to_goal() >= 0)


func test_price_rows_touch_size() -> void:
	var panel := _stuck()
	panel.show_for(_round(), true, {"extra_tube": false, "undo_refill": false})
	panel.hint_button.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	for b: Button in [
		panel.undo_button, panel.extra_tube_button, panel.undo_refill_button, panel.hint_button
	]:
		assert_bool(b.is_visible_in_tree()).is_true()
		assert_int(int(b.size.y)).is_greater_equal(UiTokens.TOUCH_MIN)
