extends GdUnitTestSuite

const OCT_31: int = 20757
const NOV_1: int = 20758
const DEC_1: int = 20788

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


func _goal_events() -> int:
	var n: int = 0
	for e in _fake.events:
		if e.get("event_id", "") == "daily:month_goal":
			n += 1
	return n


func test_month_id_boundaries() -> void:
	assert_int(DailyChallenge.month_id(OCT_31)).is_not_equal(DailyChallenge.month_id(NOV_1))
	assert_int(DailyChallenge.month_id(NOV_1)).is_equal(DailyChallenge.month_id(OCT_31) + 1)
	assert_int(DailyChallenge.month_id(20818) + 1).is_equal(DailyChallenge.month_id(20819))


func test_goal_reached_on_20th_completion() -> void:
	var bonus: int = int(GameConfig.get_value("daily_month_goal_coins"))
	for d in range(NOV_1, NOV_1 + 19):
		assert_int(DailyChallenge.complete(_state, d, {"won": true})).is_equal(50)
	assert_int(_goal_events()).is_equal(0)
	assert_int(DailyChallenge.complete(_state, NOV_1 + 19, {"won": true})).is_equal(50 + bonus)
	assert_int(_goal_events()).is_equal(1)
	assert_int(_state.coins).is_equal(50 * 20 + bonus)
	assert_int(DailyChallenge.complete(_state, NOV_1 + 20, {"won": true})).is_equal(50)
	assert_int(_goal_events()).is_equal(1)
	assert_int(DailyChallenge.month_progress(_state, NOV_1 + 20)).is_equal(21)


func test_new_month_resets_counter() -> void:
	DailyChallenge.complete(_state, DEC_1 - 2, {"won": true})
	DailyChallenge.complete(_state, DEC_1 - 1, {"won": true})
	assert_int(DailyChallenge.month_progress(_state, DEC_1 - 1)).is_equal(2)
	assert_int(DailyChallenge.month_progress(_state, DEC_1)).is_equal(0)
	DailyChallenge.complete(_state, DEC_1, {"won": true})
	assert_int(DailyChallenge.month_progress(_state, DEC_1)).is_equal(1)
	assert_int(_state.daily_month_id).is_equal(DailyChallenge.month_id(DEC_1))


func test_old_save_without_keys_is_zero() -> void:
	var d: Dictionary = GameState.new().to_dict()
	d.erase("daily_month_id")
	d.erase("daily_month_count")
	var s: GameState = GameState.from_dict(d)
	assert_int(s.daily_month_id).is_equal(0)
	assert_int(s.daily_month_count).is_equal(0)
	assert_int(DailyChallenge.month_progress(s, NOV_1)).is_equal(0)


func test_same_day_twice_keeps_counter() -> void:
	DailyChallenge.complete(_state, NOV_1, {"won": true})
	assert_int(DailyChallenge.complete(_state, NOV_1, {"won": true})).is_equal(0)
	assert_int(DailyChallenge.month_progress(_state, NOV_1)).is_equal(1)


func test_state_roundtrip_and_ranges() -> void:
	DailyChallenge.complete(_state, NOV_1, {"won": true})
	var s: GameState = GameState.from_dict(_state.to_dict())
	assert_int(DailyChallenge.month_progress(s, NOV_1)).is_equal(1)
