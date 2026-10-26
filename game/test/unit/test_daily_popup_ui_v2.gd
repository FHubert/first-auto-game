extends GdUnitTestSuite

const W: int = 720
const DAY: int = 20750


func _popup(lang: String = "en", state: GameState = null) -> DailyRewardPopup:
	TranslationServer.set_locale(lang)
	var host: Control = auto_free(Control.new())
	host.size = Vector2(W, 1280)
	host.theme = ScreenHeader.UI_THEME
	add_child(host)
	var popup: DailyRewardPopup = load("res://src/ui/daily_reward_popup.tscn").instantiate()
	host.add_child(popup)
	if state == null:
		state = GameState.new()
		# streak 2 claimed yesterday -> today is cycle day 3
		state.streak_days = 2
		state.last_play_utc_day = DAY - 1
		state.daily_reward_last_claim_day = DAY - 1
	popup.show_for(state, DAY)
	return popup


func after_test() -> void:
	TranslationServer.set_locale("en")


func _border(popup: DailyRewardPopup, i: int) -> Color:
	var sb := popup.tiles[i].get_theme_stylebox("panel") as StyleBoxFlat
	return sb.border_color if sb.border_width_left > 0 else Color(0, 0, 0, 0)


func test_tile_states() -> void:
	var popup := _popup()
	assert_int(int(DailyRewards.preview(popup.state, DAY)["cycle_day"])).is_equal(3)
	for i in 7:
		assert_bool(popup.checks[i].visible).is_equal(i < 2)
		var expected: Color = UiTokens.ACCENT if i == 2 else Color(0, 0, 0, 0)
		assert_bool(_border(popup, i) == expected).is_true()


func test_sizes_and_fit() -> void:
	for lang in ["en", "pl", "de"]:
		var popup := _popup(lang)
		popup.save_streak_button.visible = false
		await get_tree().process_frame
		await get_tree().process_frame
		for b: Button in [popup.claim_button, popup.claim_x2_button, popup.close_button]:
			assert_int(int(b.size.y)).is_greater_equal(UiTokens.TOUCH_MIN)
		var r: Rect2 = popup._card.get_global_rect()
		assert_bool(Rect2(0, 0, W, 1280).encloses(r)).is_true()


func test_variations() -> void:
	var popup := _popup()
	assert_str(popup.close_button.text).is_equal("")
	assert_str(str(popup.claim_button.theme_type_variation)).is_equal("ButtonPrimary")
	assert_str(str(popup.claim_x2_button.theme_type_variation)).is_equal("ButtonAccent")
	assert_str(str(popup.close_button.theme_type_variation)).is_equal("ButtonClose")


func test_day7_wider() -> void:
	var popup := _popup()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(popup.tiles[6].size.x).is_greater(popup.tiles[4].size.x)


func test_close_button_circle_inside_card() -> void:
	var popup := _popup()
	await get_tree().process_frame
	await get_tree().process_frame
	var b: Button = popup.close_button
	assert_vector(b.size).is_equal_approx(Vector2(81, 81), Vector2(1, 1))
	assert_bool(popup._card.get_global_rect().encloses(b.get_global_rect())).is_true()
	assert_vector(b.get_theme_stylebox("normal").get_minimum_size()).is_equal(Vector2.ZERO)


func test_claim_x2_icon_next_to_label() -> void:
	var popup: DailyRewardPopup = _popup()
	popup.claim_x2_button.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var b: Button = popup.claim_x2_button
	var icon: TextureRect = b.get_node("InlineIcon")
	var font: Font = b.get_theme_font("font")
	var fsize: int = b.get_theme_font_size("font_size")
	var text_w: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var sb: StyleBox = b.get_theme_stylebox("normal")
	var inner_l: float = sb.get_margin(SIDE_LEFT)
	var inner_w: float = b.size.x - inner_l - sb.get_margin(SIDE_RIGHT)
	var text_left: float = inner_l + (inner_w - text_w) * 0.5
	assert_float(text_left - (icon.position.x + icon.size.x)).is_between(0.0, 16.0)
	var mid_lo: float = b.size.x * 0.25
	var mid_hi: float = b.size.x * 0.75
	assert_float(icon.position.x + icon.size.x * 0.5).is_between(mid_lo, mid_hi)
	assert_float(text_left + text_w * 0.5).is_between(mid_lo, mid_hi)


func test_active_tile_says_today() -> void:
	var popup := _popup()
	assert_str(popup._day_labels[2].text).is_equal(tr("daily_today"))
	assert_str(popup._day_labels[1].text).is_equal(tr("daily_day") % 2)
	assert_str(popup._day_labels[3].text).is_equal(tr("daily_day") % 4)
