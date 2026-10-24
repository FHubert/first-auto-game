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


func _play_days(days: Array) -> void:
	for d: int in days:
		DailyRewards.register_play(_state, d)


func _has_design(event_id: String) -> bool:
	for e: Dictionary in _fake.events:
		if e["type"] == "design" and e["event_id"] == event_id:
			return true
	return false


func test_config_keys() -> void:
	assert_array(GameConfig.get_value("daily_reward_multipliers")).is_equal([1, 1, 2, 2, 3, 3, 6])
	assert_int(GameConfig.get_value("streak_save_max_per_week")).is_equal(1)
	assert_int(GameConfig.get_value("streak_save_window_days")).is_equal(7)
	assert_int(GameConfig.get_value("streak_grace_days")).is_equal(1)
	GameConfig._values["daily_reward_multipliers"] = [1, 2, 3]  # not 7 long: direct inject
	assert_int(DailyRewards.reward_for_cycle_day(3)).is_equal(150)


func test_utc_day_from_unix() -> void:
	assert_int(DailyRewards.utc_day_from_unix(86399)).is_equal(0)
	assert_int(DailyRewards.utc_day_from_unix(86400 * 5 + 10)).is_equal(5)
	assert_int(DailyRewards.utc_day_from_unix(-1)).is_equal(-1)


func test_seven_days_rewards() -> void:
	_state.coins = 0
	var got: Array[int] = []
	for d in range(100, 107):
		got.append(DailyRewards.claim(_state, d))
	assert_array(got).is_equal([50, 50, 100, 100, 150, 150, 300])
	assert_int(_state.streak_days).is_equal(7)
	assert_int(_state.streak_best).is_equal(7)
	assert_int(_state.coins).is_equal(900)
	assert_int(DailyRewards.claim(_state, 107)).is_equal(50)
	assert_int(_state.streak_days).is_equal(8)


func test_claim_twice_same_day_rejected() -> void:
	assert_int(DailyRewards.claim(_state, 100)).is_equal(50)
	var coins: int = _state.coins
	assert_int(DailyRewards.claim(_state, 100)).is_equal(0)
	assert_int(_state.coins).is_equal(coins)
	assert_bool(DailyRewards.can_claim(_state, 100)).is_false()


func test_doubled_claim() -> void:
	assert_int(DailyRewards.claim(_state, 100, true)).is_equal(100)


func test_gap_one_day_grace_and_save() -> void:
	_play_days([10, 11, 12])
	assert_int(_state.streak_days).is_equal(3)
	assert_str(DailyRewards.streak_status(_state, 14)).is_equal("grace")
	assert_bool(DailyRewards.can_save_streak(_state, 14)).is_true()
	assert_bool(DailyRewards.save_streak(_state, 14)).is_true()
	assert_int(_state.streak_saves_used).is_equal(1)
	assert_int(_state.streak_save_window_day).is_equal(14)
	var r: Dictionary = DailyRewards.register_play(_state, 14)
	assert_int(_state.streak_days).is_equal(4)
	assert_str(r["reason"]).is_equal("continue")
	# second gap within window: no save, reset
	assert_bool(DailyRewards.can_save_streak(_state, 16)).is_false()
	assert_bool(DailyRewards.save_streak(_state, 16)).is_false()
	r = DailyRewards.register_play(_state, 16)
	assert_int(_state.streak_days).is_equal(1)
	assert_str(r["reason"]).is_equal("reset")
	# window (7 days from day 14) expired
	_play_days([21, 22])
	assert_bool(DailyRewards.can_save_streak(_state, 24)).is_true()


func test_save_window_boundary() -> void:
	_play_days([10, 11, 12])
	assert_bool(DailyRewards.save_streak(_state, 14)).is_true()
	_play_days([14, 15, 16, 17, 18])
	assert_str(DailyRewards.streak_status(_state, 20)).is_equal("grace")
	assert_bool(DailyRewards.can_save_streak(_state, 20)).is_false()


func test_clock_back_cannot_reclaim() -> void:
	assert_int(DailyRewards.claim(_state, 100)).is_equal(50)
	var coins: int = _state.coins
	assert_int(DailyRewards.claim(_state, 99)).is_equal(0)
	assert_int(_state.coins).is_equal(coins)
	assert_int(DailyRewards.claim(_state, 100)).is_equal(0)


func test_grace_without_save_resets() -> void:
	_play_days([10, 11])
	var r: Dictionary = DailyRewards.register_play(_state, 13)
	assert_int(_state.streak_days).is_equal(1)
	assert_str(r["reason"]).is_equal("reset")


func test_gap_two_days_resets() -> void:
	_play_days([1, 2, 3, 4, 5])
	assert_str(DailyRewards.streak_status(_state, 8)).is_equal("reset")
	assert_bool(DailyRewards.can_save_streak(_state, 8)).is_false()
	var r: Dictionary = DailyRewards.register_play(_state, 8)
	assert_int(_state.streak_days).is_equal(1)
	assert_str(r["reason"]).is_equal("reset")
	assert_int(_state.streak_best).is_equal(5)


func test_same_day_no_change() -> void:
	_play_days([10, 11])
	var r: Dictionary = DailyRewards.register_play(_state, 11)
	assert_str(r["reason"]).is_equal("same_day")
	assert_int(_state.streak_days).is_equal(2)
	assert_int(_state.last_play_utc_day).is_equal(11)


func test_first_play() -> void:
	assert_str(DailyRewards.streak_status(_state, 50)).is_equal("first")
	var r: Dictionary = DailyRewards.register_play(_state, 50)
	assert_int(r["from"]).is_equal(0)
	assert_int(r["to"]).is_equal(1)
	assert_str(r["reason"]).is_equal("first")
	assert_int(_state.last_play_utc_day).is_equal(50)
	assert_int(_state.streak_best).is_equal(1)


func test_clock_went_back_is_same_day() -> void:
	_play_days([10, 11, 12])
	assert_str(DailyRewards.streak_status(_state, 5)).is_equal("same_day")
	var r: Dictionary = DailyRewards.register_play(_state, 5)
	assert_str(r["reason"]).is_equal("same_day")
	assert_int(_state.streak_days).is_equal(3)
	assert_int(_state.last_play_utc_day).is_equal(12)


func test_preview_matches_claim() -> void:
	# fresh, continuing, and reset states
	var days: Array = [100, 101, 110]
	for d: int in days:
		var p: Dictionary = DailyRewards.preview(_state, d)
		var before_streak: int = _state.streak_days
		assert_int(_state.streak_days).is_equal(before_streak)
		assert_bool(p["can_claim"]).is_true()
		assert_int(DailyRewards.claim(_state, d)).is_equal(p["amount"])


func test_preview_does_not_mutate() -> void:
	_play_days([1, 2])
	var before: Dictionary = _state.to_dict()
	DailyRewards.preview(_state, 3)
	assert_dict(_state.to_dict()).is_equal(before)


func test_analytics_events() -> void:
	DailyRewards.claim(_state, 100)
	assert_bool(_has_design("daily_reward:day_1")).is_true()
	assert_bool(_has_design("streak:first")).is_true()
	DailyRewards.claim(_state, 101, true)
	assert_bool(_has_design("daily_reward:day_2:x2")).is_true()
	_play_days([103])
	assert_bool(_has_design("streak:reset")).is_true()
	_state.last_play_utc_day = 200
	_state.streak_days = 3
	assert_bool(DailyRewards.save_streak(_state, 202)).is_true()
	assert_bool(_has_design("streak:saved")).is_true()
