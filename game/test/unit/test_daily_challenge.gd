extends GdUnitTestSuite

const DAY: int = 20750

var _state: GameState
var _fake: FakeAnalyticsProvider
var _old_provider: AnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_state = GameState.new()
	_state.level = 5
	_fake = FakeAnalyticsProvider.new()
	_old_provider = Analytics.provider
	Analytics.provider = _fake


func after_test() -> void:
	Analytics.provider = _old_provider
	GameConfig.reset()


func test_same_day_identical() -> void:
	var a: Dictionary = DailyChallenge.level_for_day(DAY)
	var b: Dictionary = DailyChallenge.level_for_day(DAY)
	assert_that(a["payload"]["tubes"]).is_equal(b["payload"]["tubes"])
	assert_int(a["payload"]["min_moves"]).is_equal(b["payload"]["min_moves"])
	assert_int(a["utc_day"]).is_equal(DAY)
	assert_int(a["payload"]["colors"]).is_equal(8)


func test_30_days_distinct_and_solvable() -> void:
	var keys: Dictionary = {}
	var gen: ContentGenerator = ContentGenerator.new()
	for d in range(DAY, DAY + 30):
		var level: Dictionary = DailyChallenge.level_for_day(d)
		keys[SortBoard.from_payload(level["payload"]).canonical_key()] = true
		assert_bool(gen.is_solvable(level)).is_true()
		assert_int(level["payload"]["min_moves"]).is_greater_equal(1)
	assert_int(keys.size()).is_equal(30)


func test_complete_grants_once() -> void:
	assert_int(DailyChallenge.complete(_state, DAY, {"won": true, "moves": 20})).is_equal(50)
	assert_int(_state.coins).is_equal(50)
	assert_int(_state.daily_completed_total).is_equal(1)
	assert_int(_state.daily_last_completed_day).is_equal(DAY)
	assert_int(DailyChallenge.complete(_state, DAY, {"won": true, "moves": 20})).is_equal(0)
	assert_int(_state.coins).is_equal(50)
	assert_int(DailyChallenge.complete(_state, DAY + 1, {"won": true})).is_equal(50)
	assert_int(_state.daily_completed_total).is_equal(2)
	assert_int(_state.coins).is_equal(100)


func test_not_won_no_reward() -> void:
	assert_int(DailyChallenge.complete(_state, DAY, {"won": false})).is_equal(0)
	assert_int(_state.coins).is_equal(0)
	assert_int(_state.daily_completed_total).is_equal(0)
	assert_int(_state.daily_last_completed_day).is_equal(0)


func test_unlock_level_respected() -> void:
	for lvl in [1, 2]:
		_state.level = lvl
		assert_bool(DailyChallenge.is_unlocked(_state)).is_false()
		assert_int(DailyChallenge.complete(_state, DAY, {"won": true})).is_equal(0)
	_state.level = 3
	assert_bool(DailyChallenge.is_unlocked(_state)).is_true()
	GameConfig.apply_remote({"daily_unlock_level": 5})
	assert_bool(DailyChallenge.is_unlocked(_state)).is_false()


func test_seconds_to_next() -> void:
	assert_int(DailyChallenge.seconds_to_next(DAY * 86400 + 100)).is_equal(86300)
	assert_int(DailyChallenge.seconds_to_next(DAY * 86400)).is_equal(86400)


func test_analytics_event() -> void:
	DailyChallenge.complete(_state, DAY, {"won": true, "moves": 20})
	var found: bool = false
	for e in _fake.events:
		if e.get("event_id", "") == "daily_challenge:completed":
			found = true
	assert_bool(found).is_true()
