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
