extends GdUnitTestSuite
## LevelOffers bez sceny: brak srodkow na podpowiedz -> sklep + nieudany zakup.


func test_buy_hint_without_coins_requests_shop() -> void:
	var state := GameState.new()
	state.coins = 0
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(1, 2))
	var offers := LevelOffers.new()
	offers.bind(state, r, RewardedPlacements.new(), LevelOffers.MODE_CAMPAIGN, 2)
	var reasons: Array[String] = []
	var results: Array[bool] = []
	offers.shop_requested.connect(func(reason: String) -> void: reasons.append(reason))
	offers.purchase_finished.connect(func(ok: bool) -> void: results.append(ok))
	assert_bool(offers.buy_hint()).is_false()
	assert_array(reasons).contains_exactly([Economy.SINK_HINT])
	assert_array(results).contains_exactly([false])


func _poor_offers() -> LevelOffers:
	var state := GameState.new()
	state.coins = 0
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(1, 2))
	var offers := LevelOffers.new()
	offers.bind(state, r, RewardedPlacements.new(), LevelOffers.MODE_CAMPAIGN, 2)
	return offers


func test_buy_hint_without_coins_keeps_balance() -> void:
	var offers := _poor_offers()
	var reasons: Array[String] = []
	offers.shop_requested.connect(func(reason: String) -> void: reasons.append(reason))
	assert_bool(offers.buy_hint()).is_false()
	assert_array(reasons).contains_exactly([Economy.SINK_HINT])
	assert_int(offers.state.coins).is_equal(0)


func test_buy_undo_refill_without_coins_requests_shop() -> void:
	var offers := _poor_offers()
	var reasons: Array[String] = []
	offers.shop_requested.connect(func(reason: String) -> void: reasons.append(reason))
	assert_bool(offers.buy_undo_refill()).is_false()
	assert_array(reasons).contains_exactly([Economy.SINK_UNDO_REFILL])
	assert_int(offers.state.coins).is_equal(0)
