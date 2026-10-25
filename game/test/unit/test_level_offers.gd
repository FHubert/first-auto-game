extends GdUnitTestSuite
## LevelOffers bez sceny: brak srodkow na podpowiedz -> sklep + nieudany zakup.

var _prev_an: AnalyticsProvider
var _prev_ads: AdProvider
var _fake_an: FakeAnalyticsProvider


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


func before_test() -> void:
	GameConfig.reset()
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_prev_ads = Ads.provider
	Ads.provider = FakeAdProvider.new()


func after_test() -> void:
	Analytics.provider = _prev_an
	Ads.provider = _prev_ads
	GameConfig.reset()


func _assist(level_no: int, restarts: int, coins: int, mode: String = "campaign") -> LevelOffers:
	var state := GameState.new()
	state.coins = coins
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(1, 2))
	for i: int in restarts:
		r.restart()
	var offers := LevelOffers.new()
	offers.bind(state, r, RewardedPlacements.new(), mode, level_no)
	return offers


func _count(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if e.get("event_id", "") == id:
			n += 1
	return n


func test_assist_below_min_level_hidden() -> void:
	assert_bool(_assist(25, 2, 999).plateau_assist()["show"]).is_false()


func test_assist_first_attempt_hidden() -> void:
	assert_bool(_assist(26, 0, 999).plateau_assist()["show"]).is_false()


func test_assist_second_attempt_shown() -> void:
	assert_bool(_assist(26, 1, 999).plateau_assist()["show"]).is_true()


func test_assist_third_attempt_shown() -> void:
	var a: Dictionary = _assist(26, 2, 999).plateau_assist()
	assert_bool(a["show"]).is_true()
	assert_bool(a["coins"]).is_true()
	assert_bool(a["rewarded"]).is_true()


func test_assist_daily_hidden() -> void:
	assert_bool(_assist(40, 2, 999, LevelOffers.MODE_DAILY).plateau_assist()["show"]).is_false()


func test_assist_hidden_after_first_move() -> void:
	var o := _assist(26, 2, 999)
	var m: Array[Vector2i] = o.round.board().legal_moves()
	assert_bool(o.round.try_move(m[0].x, m[0].y)).is_true()
	assert_bool(o.plateau_assist()["show"]).is_false()


func test_assist_hidden_after_extra_tube() -> void:
	var o := _assist(26, 2, 999)
	o.round.add_extra_tube()
	assert_bool(o.plateau_assist()["show"]).is_false()


func test_assist_no_coins_no_ad_hidden() -> void:
	var fake := FakeAdProvider.new()
	fake.always_ready = false
	Ads.provider = fake
	var a: Dictionary = _assist(26, 2, 0).plateau_assist()
	assert_bool(a["show"]).is_false()
	assert_bool(a["coins"]).is_false()
	assert_bool(a["rewarded"]).is_false()


func test_assist_offered_tracked_once_per_attempt() -> void:
	var o := _assist(26, 2, 999)
	o.plateau_assist()
	o.plateau_assist()
	assert_int(_count("level:assist:offered")).is_equal(1)
	o.round.restart()
	o.plateau_assist()
	assert_int(_count("level:assist:offered")).is_equal(2)


func test_assist_buy_tracks_coins_event() -> void:
	var o := _assist(26, 2, 999)
	var cost: int = Economy.extra_tube_cost()
	assert_bool(o.assist_buy_extra_tube()).is_true()
	assert_int(o.state.coins).is_equal(999 - cost)
	assert_int(_count("level:assist:coins")).is_equal(1)
	assert_int(_count("booster:extra_tube:coins")).is_equal(1)


func test_assist_watch_tracks_rewarded_event() -> void:
	var o := _assist(26, 2, 0)
	assert_bool(o.assist_watch_extra_tube()).is_true()
	assert_int(_count("level:assist:rewarded")).is_equal(1)
	assert_int(_count("booster:extra_tube:rewarded")).is_equal(1)


func test_plain_watch_extra_tube_has_no_assist_event() -> void:
	var o := _assist(26, 2, 0)
	assert_bool(o.watch_extra_tube()).is_true()
	assert_int(_count("level:assist:rewarded")).is_equal(0)
	assert_int(_count("booster:extra_tube:rewarded")).is_equal(1)
