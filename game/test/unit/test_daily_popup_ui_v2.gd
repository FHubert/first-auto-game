extends GdUnitTestSuite

const W: int = 720
const DAY: int = 20750


func _popup(lang: String = "en", state: GameState = null) -> DailyRewardPopup:
	TranslationServer.set_locale(lang)
	var host: Control = auto_free(Control.new())
	host.size = Vector2(W, 1280)
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
	assert_str(str(popup.close_button.theme_type_variation)).is_equal("ButtonIcon")


func test_day7_wider() -> void:
	var popup := _popup()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(popup.tiles[6].size.x).is_greater(popup.tiles[4].size.x)
