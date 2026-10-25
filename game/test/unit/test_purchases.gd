extends GdUnitTestSuite

var _p: Node
var _prov: FakeIapProvider
var _state: GameState
var _fake: FakeAnalyticsProvider
var _old: AnalyticsProvider
var _granted: Array = []
var _failed: Array = []


func before_test() -> void:
	GameConfig.reset()
	_fake = FakeAnalyticsProvider.new()
	_old = Analytics.provider
	Analytics.provider = _fake
	_granted = []
	_failed = []
	_prov = FakeIapProvider.new()
	_state = GameState.new()
	_state.coins = 0
	_p = auto_free(load("res://src/systems/purchases.gd").new())
	_p.provider = _prov
	_p.state = _state
	_p.save_callback = func() -> void: pass
	_p.purchase_granted.connect(func(sku: String) -> void: _granted.append(sku))
	_p.purchase_failed.connect(func(sku: String, _s: String) -> void: _failed.append(sku))
	_p._ready()


func after_test() -> void:
	Analytics.provider = _old
	GameConfig.reset()


func test_purchased_coins_granted_and_acknowledged() -> void:
	assert_bool(_p.buy("coins_small")).is_true()
	assert_int(_state.coins).is_equal(500)
	assert_int(_granted.size()).is_equal(1)
	assert_array(_prov.acknowledged_tokens).contains(["tok_coins_small_1"])


func test_coins_large() -> void:
	_p.buy("coins_large")
	assert_int(_state.coins).is_equal(1500)


func test_pending_does_not_grant_until_purchased() -> void:
	_prov.purchase_result = IapProvider.STATE_PENDING
	_p.buy("coins_small")
	assert_int(_state.coins).is_equal(0)
	assert_array(_prov.acknowledged_tokens).is_empty()
	_prov.purchase_updated.emit("coins_small", IapProvider.STATE_PURCHASED, "tok_x")
	assert_int(_state.coins).is_equal(500)
	assert_array(_prov.acknowledged_tokens).contains(["tok_x"])


func test_canceled_fails() -> void:
	_prov.purchase_result = IapProvider.STATE_CANCELED
	_p.buy("coins_small")
	assert_int(_state.coins).is_equal(0)
	assert_int(_failed.size()).is_equal(1)
	assert_int(_granted.size()).is_equal(0)


func test_remove_ads_once() -> void:
	assert_bool(_p.buy("remove_ads")).is_true()
	assert_bool(_state.settings["ads_removed"]).is_true()
	assert_bool(_state.has_purchase("remove_ads")).is_true()
	assert_bool(_p.buy("remove_ads")).is_false()


func test_unknown_sku_rejected() -> void:
	assert_bool(_p.buy("nope")).is_false()
	assert_bool(_p.grant("nope")).is_false()


func test_starter_pack_only_once() -> void:
	assert_bool(_p.grant("starter_pack")).is_true()
	assert_int(_state.coins).is_equal(800)
	assert_bool(_state.owns_theme("neon")).is_true()
	assert_bool(_p.grant("starter_pack")).is_false()
	assert_int(_state.coins).is_equal(800)
	assert_int(_state.themes_owned.count("neon")).is_equal(1)


func test_restore_brings_back_remove_ads_without_duplicating() -> void:
	_prov.owned_for_restore = ["remove_ads"]
	_p.restore()
	assert_bool(_state.settings["ads_removed"]).is_true()
	assert_bool(_state.has_purchase("remove_ads")).is_true()
	_p.restore()
	assert_int(_granted.size()).is_equal(1)


func test_starter_offer_window() -> void:
	var t0: int = 1000000
	assert_bool(_p.starter_offer_visible(11, t0)).is_false()
	assert_bool(_p.starter_offer_visible(12, t0)).is_true()
	assert_bool(_p.starter_offer_visible(12, t0 + 71 * 3600)).is_true()
	assert_bool(_p.starter_offer_visible(12, t0 + 73 * 3600)).is_false()


func test_starter_offer_hidden_after_purchase() -> void:
	assert_bool(_p.starter_offer_visible(12, 1000)).is_true()
	_p.grant("starter_pack")
	assert_bool(_p.starter_offer_visible(12, 1000)).is_false()


func test_price_text_from_store() -> void:
	assert_str(_p.price_text("remove_ads")).is_equal("$3.99")
	assert_str(_p.price_text("coins_small")).is_equal("$1.99")
	assert_str(_p.price_text("unknown")).is_equal("")


func _business_count() -> int:
	return _fake.events.filter(func(e: Dictionary) -> bool: return e["type"] == "business").size()


func test_same_token_twice_grants_once_acks_twice() -> void:
	var saves: Array = [0]
	_p.save_callback = func() -> void: saves[0] += 1
	_prov.redeliver("coins_small", "tok_a")
	_prov.redeliver("coins_small", "tok_a")
	assert_int(_state.coins).is_equal(int(GameConfig.get_value("iap_coins_small")))
	assert_int(_business_count()).is_equal(1)
	assert_int(saves[0]).is_equal(1)
	assert_array(_prov.acknowledged_tokens).is_equal(["tok_a", "tok_a"])
	assert_array(_state.iap_tokens).is_equal(["tok_a"])


func test_two_tokens_grant_twice() -> void:
	_prov.redeliver("coins_small", "tok_a")
	_prov.redeliver("coins_small", "tok_b")
	assert_int(_state.coins).is_equal(2 * int(GameConfig.get_value("iap_coins_small")))
	assert_int(_business_count()).is_equal(2)


func test_redelivered_remove_ads_tracks_business_once() -> void:
	_prov.redeliver("remove_ads", "tok_r1")
	_prov.redeliver("remove_ads", "tok_r2")
	assert_int(_business_count()).is_equal(1)
	assert_array(_state.iap_tokens).is_equal(["tok_r1", "tok_r2"])
	assert_array(_prov.acknowledged_tokens).is_equal(["tok_r1", "tok_r2"])


func test_empty_token_not_deduped() -> void:
	_prov.redeliver("coins_small", "")
	_prov.redeliver("coins_small", "")
	assert_int(_state.coins).is_equal(2 * int(GameConfig.get_value("iap_coins_small")))
	assert_array(_state.iap_tokens).is_empty()


func test_token_list_capped_at_64_newest() -> void:
	for i: int in range(GameState.IAP_TOKENS_MAX + 1):
		_prov.redeliver("coins_small", "t%d" % i)
	assert_int(_state.iap_tokens.size()).is_equal(GameState.IAP_TOKENS_MAX)
	assert_bool(_state.iap_tokens.has("t0")).is_false()
	assert_str(_state.iap_tokens.back()).is_equal("t64")


func test_duplicate_rejected_after_save_load_new_purchases() -> void:
	_prov.redeliver("coins_small", "tok_a")
	var loaded: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	var coins_before: int = loaded.coins
	var p2: Node = auto_free(_p.get_script().new())
	var prov2 := FakeIapProvider.new()
	p2.provider = prov2
	p2.state = loaded
	p2.save_callback = func() -> void: pass
	p2._ready()
	prov2.redeliver("coins_small", "tok_a")
	assert_int(loaded.coins).is_equal(coins_before)
	assert_array(prov2.acknowledged_tokens).is_equal(["tok_a"])


func test_bad_iap_tokens_reset() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d["iap_tokens"] = ["ok", 5]
	assert_array(GameState.from_dict(d).iap_tokens).is_empty()
	d["iap_tokens"] = "x"
	assert_array(GameState.from_dict(d).iap_tokens).is_empty()
	d.erase("iap_tokens")
	assert_array(GameState.from_dict(d).iap_tokens).is_empty()
