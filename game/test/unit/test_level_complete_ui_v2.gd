extends GdUnitTestSuite

const W: int = 720
const H: int = 1280


func _host() -> Control:
	var host: Control = auto_free(Control.new())
	host.size = Vector2(W, H)
	add_child(host)
	return host


func _complete() -> LevelComplete:
	var lc: LevelComplete = (load("res://src/ui/level_complete.tscn") as PackedScene).instantiate()
	_host().add_child(lc)
	return lc


func _wide_labels(n: Node, limit: float, out: Array[String]) -> void:
	if n is Label and (n as Label).is_visible_in_tree():
		var l := n as Label
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > limit:
			out.append(l.text)
	for c in n.get_children():
		_wide_labels(c, limit, out)


func test_level_complete_campaign() -> void:
	var lc := _complete()
	lc.show_result(25, true, 20)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(lc.title_label.text).is_equal(tr("lc_great"))
	assert_str(lc.level_caption.text).contains("20")
	assert_bool(lc.perfect_label.visible).is_true()
	assert_int(int(lc.next_button.size.y)).is_greater_equal(UiTokens.TOUCH_MIN)
	assert_bool(Rect2(0, 0, W, H).encloses(lc.panel_rect())).is_true()
	assert_float(lc.panel_height()).is_greater_equal(lc.panel_rect().size.y)


func test_level_complete_daily_title() -> void:
	var lc := _complete()
	lc.show_result(10, false, 3, "Poziom dnia")
	assert_str(lc.title_label.text).is_equal("Poziom dnia")
	assert_bool(lc.level_caption.visible).is_false()
	assert_bool(lc.perfect_label.visible).is_false()


func test_german_labels_not_clipped() -> void:
	var prev: String = TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var lc := _complete()
	lc.show_result(25, true, 20, "", {"key": "lc_new_color", "args": []}, _breakdown())
	lc.set_double_offer(25, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var limit: float = W - 2.0 * 22 - 2.0 * UiTokens.SCREEN_PAD
	var wide: Array[String] = []
	_wide_labels(lc, limit, wide)
	TranslationServer.set_locale(prev)
	assert_array(wide).is_empty()


func _breakdown() -> Dictionary:
	return {
		"win": 15,
		"perfect": 10,
		"moves": 19,
		"theme_name": "Pastel",
		"theme_cost": 600,
		"coins": 375,
	}


func test_breakdown_and_theme_bar() -> void:
	var lc := _complete()
	var progress: Dictionary = {"key": "lc_theme_progress", "args": [375, 600]}
	lc.show_result(25, true, 20, "", progress, _breakdown())
	assert_bool(lc.breakdown_label.visible).is_true()
	assert_str(lc.breakdown_label.text).is_equal(tr("lc_breakdown") % [15, 10])
	assert_bool(lc.theme_row.visible).is_true()
	assert_float(lc.theme_bar.value).is_equal(375.0)
	assert_float(lc.theme_bar.max_value).is_equal(600.0)
	assert_bool(lc.progress_label.visible).is_false()
	assert_str(lc.perfect_label.text).is_equal(tr("lc_perfect_moves") % 19)


func test_no_breakdown_hides_extras() -> void:
	var lc := _complete()
	lc.show_result(25, true, 20)
	assert_bool(lc.breakdown_label.visible).is_false()
	assert_bool(lc.theme_row.visible).is_false()
	assert_str(lc.perfect_label.text).is_equal(tr("lc_perfect"))


func test_no_next_theme_keeps_progress_label() -> void:
	var lc := _complete()
	var bd: Dictionary = _breakdown()
	bd["theme_cost"] = 0
	lc.show_result(25, true, 20, "", {"key": "lc_new_color", "args": []}, bd)
	assert_bool(lc.theme_row.visible).is_false()
	assert_bool(lc.progress_label.visible).is_true()
	assert_str(lc.progress_label.text).is_equal(tr("lc_new_color"))


func test_perfect_badge_has_star_before_text() -> void:
	var lc := _complete()
	lc.show_result(15, true, 2, "", {}, {"moves": 19})
	await get_tree().process_frame
	await get_tree().process_frame
	var star := lc.perfect_badge.find_child("StarIcon", true, false) as TextureRect
	assert_object(star).is_not_null()
	assert_object(star.texture).is_not_null()
	assert_bool(star.is_visible_in_tree()).is_true()
	var sr: Rect2 = star.get_global_rect()
	assert_float(sr.position.x).is_less(lc.perfect_label.get_global_rect().position.x)
	assert_bool(lc.perfect_badge.get_global_rect().encloses(sr)).is_true()
