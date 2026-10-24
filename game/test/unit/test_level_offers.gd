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
