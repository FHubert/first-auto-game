extends GdUnitTestSuite

var _state: GameState
var _fake: FakeAnalyticsProvider
var _old_provider: AnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_state = GameState.new()
	_fake = FakeAnalyticsProvider.new()
	_old_provider = Analytics.provider
	Analytics.provider = _fake


func after_test() -> void:
	Analytics.provider = _old_provider
	GameConfig.reset()


func test_config_values_match_gdd() -> void:
	assert_int(GameConfig.get_value("starting_coins")).is_equal(100)
	assert_int(GameConfig.get_value("par_bonus_coins")).is_equal(10)
	assert_int(GameConfig.get_value("hint_cost_coins")).is_equal(25)
	assert_int(GameConfig.get_value("extra_tube_cost_coins")).is_equal(60)
	assert_int(GameConfig.get_value("undo_refill_cost_coins")).is_equal(20)
	assert_int(GameConfig.get_value("undo_refill_amount")).is_equal(3)
	assert_int(GameConfig.get_value("par_slack_moves")).is_equal(2)
	assert_int(GameConfig.get_value("theme_cost_base")).is_equal(600)
	assert_float(GameConfig.get_value("theme_cost_growth")).is_equal(1.8)
	assert_int(GameConfig.get_value("daily_challenge_coins")).is_equal(50)
	assert_int(GameConfig.get_value("daily_unlock_level")).is_equal(3)


func test_earn_increases_and_ignores_nonpositive() -> void:
	_state.coins = 10
	assert_int(Economy.earn(_state, 5, Economy.SOURCE_WIN)).is_equal(15)
	assert_int(Economy.earn(_state, 0, Economy.SOURCE_WIN)).is_equal(15)
	assert_int(Economy.earn(_state, -3, Economy.SOURCE_WIN)).is_equal(15)
	assert_int(_state.coins).is_equal(15)


func test_spend_success_and_insufficient() -> void:
	_state.coins = 50
	assert_bool(Economy.spend(_state, 60, Economy.SINK_HINT)).is_false()
	assert_int(_state.coins).is_equal(50)
	assert_bool(Economy.spend(_state, 50, Economy.SINK_HINT)).is_true()
	assert_int(_state.coins).is_equal(0)
	assert_bool(Economy.spend(_state, 1, Economy.SINK_HINT)).is_false()
	assert_bool(Economy.spend(_state, 0, Economy.SINK_HINT)).is_true()
	assert_bool(Economy.spend(_state, -5, Economy.SINK_HINT)).is_false()
	assert_int(_state.coins).is_equal(0)


func test_balance_never_negative_random_walk() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	_state.coins = 100
	for i: int in range(500):
		var amount: int = rng.randi_range(-20, 200)
		if rng.randf() < 0.5:
			Economy.earn(_state, amount, Economy.SOURCE_WIN)
		else:
			Economy.spend(_state, amount, Economy.SINK_HINT)
		assert_int(_state.coins).is_greater_equal(0)


func test_win_reward_values() -> void:
	assert_int(Economy.win_reward({"won": true, "perfect": true})).is_equal(25)
	assert_int(Economy.win_reward({"won": true, "perfect": false})).is_equal(15)
	assert_int(Economy.win_reward({"won": false, "perfect": true})).is_equal(0)
	_state.coins = 0
	assert_int(Economy.apply_win(_state, {"won": true, "perfect": true})).is_equal(25)
	assert_int(_state.coins).is_equal(25)
	assert_int(Economy.apply_win(_state, {"won": false})).is_equal(0)
	assert_int(_state.coins).is_equal(25)


func test_theme_costs() -> void:
	assert_int(Economy.theme_cost(1)).is_equal(600)
	assert_int(Economy.theme_cost(2)).is_equal(1080)
	assert_int(Economy.theme_cost(3)).is_equal(1944)
	assert_int(Economy.theme_cost(0)).is_equal(0)
	GameConfig.apply_remote({"theme_cost_growth": 2.0})
	assert_int(Economy.theme_cost(1)).is_equal(600)
	assert_int(Economy.theme_cost(2)).is_equal(1200)
	assert_int(Economy.theme_cost(3)).is_equal(2400)


func test_buy_booster() -> void:
	_state.coins = 100
	assert_bool(Economy.buy_booster(_state, Economy.SINK_HINT)).is_true()
	assert_int(_state.coins).is_equal(75)
	assert_bool(Economy.buy_booster(_state, Economy.SINK_EXTRA_TUBE)).is_true()
	assert_int(_state.coins).is_equal(15)
	assert_bool(Economy.buy_booster(_state, Economy.SINK_UNDO_REFILL)).is_false()
	assert_int(_state.coins).is_equal(15)
	assert_bool(Economy.buy_booster(_state, "bogus")).is_false()
	assert_int(_state.coins).is_equal(15)


func test_rewarded_bonus() -> void:
	assert_int(Economy.rewarded_bonus(10)).is_equal(10)
	GameConfig.apply_remote({"rewarded_multiplier": 3.0})
	assert_int(Economy.rewarded_bonus(10)).is_equal(20)


func test_rewarded_bonus_never_negative() -> void:
	GameConfig.set_for_test("rewarded_multiplier", 0.5)  # below RANGES
	assert_int(Economy.rewarded_bonus(10)).is_equal(0)
	GameConfig.set_for_test("rewarded_multiplier", 0.0)
	assert_int(Economy.rewarded_bonus(10)).is_equal(0)
	GameConfig.apply_remote({"rewarded_multiplier": 1.0})
	assert_int(Economy.rewarded_bonus(10)).is_equal(0)


func test_can_afford_boundaries() -> void:
	_state.coins = 50
	assert_bool(Economy.can_afford(_state, 50)).is_true()
	assert_bool(Economy.can_afford(_state, 51)).is_false()
	assert_bool(Economy.can_afford(_state, 0)).is_true()
	assert_bool(Economy.can_afford(_state, -1)).is_false()


func test_apply_win_perfect_records_two_resource_events() -> void:
	Economy.apply_win(_state, {"won": true, "perfect": true})
	assert_int(_fake.events.size()).is_equal(2)
	var win_ev: Dictionary = _fake.events[0]
	var perfect_ev: Dictionary = _fake.events[1]
	assert_str(win_ev["type"]).is_equal("resource")
	assert_str(perfect_ev["type"]).is_equal("resource")
	assert_str(win_ev["flow"]).is_equal("Source")
	assert_str(perfect_ev["flow"]).is_equal("Source")
	assert_str(win_ev["currency"]).is_equal("coins")
	assert_str(perfect_ev["currency"]).is_equal("coins")
	assert_str(win_ev["item_type"]).is_equal("economy")
	assert_str(perfect_ev["item_type"]).is_equal("economy")
	assert_str(win_ev["item_id"]).is_equal(Economy.SOURCE_WIN)
	assert_float(win_ev["amount"]).is_equal(float(GameConfig.get_value("win_reward_coins")))
	assert_str(perfect_ev["item_id"]).is_equal(Economy.SOURCE_PERFECT)
	assert_float(perfect_ev["amount"]).is_equal(float(GameConfig.get_value("par_bonus_coins")))


func test_apply_win_without_perfect_records_one_event() -> void:
	Economy.apply_win(_state, {"won": true})
	assert_int(_fake.events.size()).is_equal(1)
	assert_str(_fake.events[0]["item_id"]).is_equal(Economy.SOURCE_WIN)


func test_analytics_events_recorded() -> void:
	_state.coins = 0
	Economy.earn(_state, 30, Economy.SOURCE_DAILY_REWARD)
	Economy.spend(_state, 10, Economy.SINK_HINT)
	Economy.spend(_state, 999, Economy.SINK_HINT)
	assert_int(_fake.events.size()).is_equal(2)
	assert_str(_fake.events[0]["flow"]).is_equal("Source")
	assert_str(_fake.events[0]["item_id"]).is_equal("daily_reward")
	assert_str(_fake.events[1]["flow"]).is_equal("Sink")
	assert_float(_fake.events[1]["amount"]).is_equal(10.0)
