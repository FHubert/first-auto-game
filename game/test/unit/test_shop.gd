extends GdUnitTestSuite

const T0: int = 1_000_000

var _old_save: Callable
var _old_products: Dictionary
var _old_state: GameState
var _now: Array[int] = [T0]


func before_test() -> void:
	GameConfig.reset()
	_old_save = Purchases.save_callback
	_old_products = Purchases.products.duplicate()
	_old_state = Purchases.state
	Purchases.save_callback = func() -> void: pass
	_now[0] = T0
	Purchases.provider.query_products(Purchases.ALL_SKUS)


func after_test() -> void:
	Purchases.save_callback = _old_save
	Purchases.products = _old_products
	Purchases.state = _old_state
	var fake: FakeIapProvider = Purchases.provider
	fake.purchase_result = IapProvider.STATE_PURCHASED
	fake.owned_for_restore = []


func _shop(level: int = 12) -> ShopScreen:
	var s: ShopScreen = auto_free(load("res://src/ui/shop_screen.tscn").instantiate())
	s.state = GameState.new()
	s.state.level = level
	s.clock = func() -> int: return _now[0]
	add_child(s)
	return s


func test_backdrop_is_opaque_first_child() -> void:
	var s := _shop()
	assert_object(s.get_child(0)).is_same(s.backdrop)
	assert_float(s.backdrop.anchor_right).is_equal(1.0)
	assert_float(s.backdrop.anchor_bottom).is_equal(1.0)
	var box := s.backdrop.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(box).is_not_null()
	assert_float(box.bg_color.a).is_equal(1.0)


func test_starter_window() -> void:
	var s := _shop(12)
	assert_bool(s.has_card("starter_pack")).is_true()
	assert_bool(s.has_card("remove_ads")).is_true()
	assert_bool(s.has_card("coins_small")).is_true()
	assert_bool(s.has_card("coins_large")).is_true()
	_now[0] = T0 + 71 * 3600
	s.refresh()
	assert_bool(s.has_card("starter_pack")).is_true()
	_now[0] = T0 + 73 * 3600
	s.refresh()
	assert_bool(s.has_card("starter_pack")).is_false()


func test_no_starter_below_min_level() -> void:
	var s := _shop(5)
	assert_bool(s.has_card("starter_pack")).is_false()
	assert_bool(s.has_card("coins_large")).is_true()


func test_starter_disappears_after_purchase() -> void:
	var s := _shop(12)
	s.card_button("starter_pack").pressed.emit()
	assert_bool(s.has_card("starter_pack")).is_false()
	assert_bool(s.state.owns_theme("neon")).is_true()


func test_prices_come_from_provider() -> void:
	var s := _shop(12)
	assert_str(s.card_button("remove_ads").text).is_equal("$3.99")
	Purchases.products = {}
	s.refresh()
	assert_str(s.card_button("remove_ads").text).is_equal(tr("shop_price_unknown"))
	assert_bool(s.card_button("remove_ads").disabled).is_true()


func test_buy_coins_and_remove_ads() -> void:
	var s := _shop(5)
	s.card_button("coins_small").pressed.emit()
	assert_int(s.state.coins).is_equal(500)
	s.card_button("remove_ads").pressed.emit()
	assert_bool(s.state.settings.get("ads_removed", false)).is_true()
	assert_str(s.card_button("remove_ads").text).is_equal(tr("btn_owned"))
	assert_bool(s.card_button("remove_ads").disabled).is_true()


func test_restore() -> void:
	var s := _shop(5)
	var fake: FakeIapProvider = Purchases.provider
	s.restore_button.pressed.emit()
	assert_str(s.status_label.text).is_equal(tr("shop_restore_none"))
	fake.owned_for_restore = ["remove_ads"]
	s.restore_button.pressed.emit()
	assert_bool(s.state.settings.get("ads_removed", false)).is_true()
	assert_str(s.status_label.text).is_equal(tr("shop_restored") % 1)


func test_reason_label() -> void:
	var s := _shop(5)
	assert_bool(s.reason_label.visible).is_false()
	s.reason = "extra_tube"
	s.refresh()
	assert_bool(s.reason_label.visible).is_true()


func test_settings_restore() -> void:
	var st: SettingsScreen = auto_free(load("res://src/ui/settings_screen.tscn").instantiate())
	st.state = GameState.new()
	add_child(st)
	assert_object(st.restore_button).is_not_null()
	var fake: FakeIapProvider = Purchases.provider
	fake.owned_for_restore = ["remove_ads"]
	st.restore_button.pressed.emit()
	assert_bool(st.state.settings.get("ads_removed", false)).is_true()


func test_format_hms() -> void:
	assert_str(ShopScreen.format_hms(0)).is_equal("00:00:00")
	assert_str(ShopScreen.format_hms(3599)).is_equal("00:59:59")
	assert_str(ShopScreen.format_hms(71 * 3600 + 59 * 60 + 12)).is_equal("71:59:12")
	assert_str(ShopScreen.format_hms(-5)).is_equal("00:00:00")


func test_starter_card_t278() -> void:
	var s := _shop(12)
	_now[0] = T0 + 3600
	s.refresh()
	var c: Dictionary = s.cards["starter_pack"]
	var sb := (c["panel"] as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(sb.bg_color).is_equal(UiTokens.CARD_ICON)
	assert_that(sb.border_color).is_equal(UiTokens.ACCENT)
	assert_str((c["badge"] as Label).text).is_equal(tr("shop_starter_badge"))
	assert_str((c["extra"] as Label).text).is_equal(str(tr("shop_offer_left") % "71:00:00"))
	assert_str((c["button"] as Button).text).is_equal(str(tr("shop_buy_for") % "$1.99"))


func test_product_subtitles_and_order() -> void:
	var s := _shop(12)
	var tubes_expected: int = (
		int(GameConfig.get_value("iap_coins_small"))
		/ int(GameConfig.get_value("extra_tube_cost_coins"))
	)
	assert_str((s.cards["coins_small"]["desc"] as Label).text).is_equal(
		tr("shop_desc_tubes") % tubes_expected
	)
	var bonus := s.cards["coins_large"]["desc"] as Label
	assert_str(bonus.text).is_equal(
		tr("shop_desc_bonus") % int(GameConfig.get_value("iap_coins_large_bonus_pct"))
	)
	assert_that(bonus.get_theme_color("font_color")).is_equal(UiTokens.PRIMARY)
	var parent: Node = (s.cards["coins_small"]["panel"] as Node).get_parent()
	assert_array(ShopScreen.SKU_ORDER).is_equal(
		["starter_pack", "coins_small", "coins_large", "remove_ads"]
	)
	var idx: Array[int] = []
	for sku: String in ShopScreen.SKU_ORDER:
		idx.append((s.cards[sku]["panel"] as Node).get_index())
	var strictly_increasing := true
	for i: int in range(1, idx.size()):
		if idx[i] <= idx[i - 1]:
			strictly_increasing = false
	assert_bool(strictly_increasing).is_true()
	assert_object(parent).is_same(s.cards["starter_pack"]["panel"].get_parent())


func test_restore_is_underlined_link() -> void:
	var s := _shop(5)
	assert_object(s.restore_button).is_instanceof(LinkButton)
	assert_int(s.restore_button.underline).is_equal(LinkButton.UNDERLINE_MODE_ALWAYS)
	assert_str(s.restore_button.text).is_equal(tr("btn_restore"))
	assert_float(s.restore_button.custom_minimum_size.y).is_greater_equal(UiTokens.TOUCH_MIN)


func test_geometry_de_with_starter() -> void:
	TranslationServer.set_locale("de")
	for size: Vector2 in [Vector2(720, 1280), Vector2(720, 1560)]:
		var s := _shop(12)
		s.size = size
		await get_tree().process_frame
		await get_tree().process_frame
		assert_bool(s.scroll.get_global_rect().end.y <= size.y).is_true()
		assert_bool(s.restore_button.get_global_rect().end.y <= size.y).is_true()
		var tall: bool = size.y > 1500
		var last := s.cards["remove_ads"]["panel"] as Control
		if tall:
			assert_bool(last.get_global_rect().end.y <= s.scroll.get_global_rect().end.y).is_true()
		for sku: String in s.cards:
			var b := s.cards[sku]["button"] as Button
			var d := s.cards[sku]["desc"] as Label
			if sku != "starter_pack":
				(
					assert_bool(d.get_global_rect().end.x <= b.get_global_rect().position.x + 1.0)
					. is_true()
				)
		s.queue_free()
	TranslationServer.set_locale("en")
