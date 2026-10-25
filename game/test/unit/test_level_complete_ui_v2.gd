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
	lc.show_result(25, true, 20, "", {"key": "lc_new_color", "args": []})
	lc.set_double_offer(25, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var limit: float = W - 2.0 * 22 - 2.0 * UiTokens.SCREEN_PAD
	var wide: Array[String] = []
	_wide_labels(lc, limit, wide)
	TranslationServer.set_locale(prev)
	assert_array(wide).is_empty()
