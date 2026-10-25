# gdlint: disable=max-public-methods
extends GdUnitTestSuite

var _ads: Node
var _provider: FakeAdProvider
var _now: Array[float] = [0.0]
var _fake_an: FakeAnalyticsProvider
var _prev_an: AnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_now[0] = 0.0
	_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = TestClock.ticking_float(_now)


func after_test() -> void:
	Analytics.provider = _prev_an
	Audio.set_app_muted(false)
	GameConfig.reset()


func test_interstitial_only_every_n_rounds() -> void:
	assert_bool(_ads.maybe_show_interstitial(5)).is_false()
	assert_bool(_ads.maybe_show_interstitial(9)).is_false()
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	assert_int(_provider.interstitials_shown).is_equal(1)


func test_interstitial_respects_min_seconds() -> void:
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	_now[0] = 30.0
	assert_bool(_ads.maybe_show_interstitial(15)).is_false()
	_now[0] = 121.0
	assert_bool(_ads.maybe_show_interstitial(15)).is_true()
	assert_int(_provider.interstitials_shown).is_equal(2)


func test_interstitial_not_shown_when_not_ready() -> void:
	_provider.always_ready = false
	assert_bool(_ads.maybe_show_interstitial(10)).is_false()
	assert_int(_provider.interstitials_shown).is_equal(0)


func test_interstitial_cap_follows_config() -> void:
	GameConfig.apply_remote({"interstitial_every_n_rounds": 2})
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()


func test_interstitial_not_when_ads_removed() -> void:
	assert_bool(_ads.maybe_show_interstitial(10, true)).is_false()
	assert_int(_ads.interstitials_shown).is_equal(0)
	assert_int(_provider.interstitials_shown).is_equal(0)


func test_interstitial_skipped_after_rewarded_in_same_break() -> void:
	_ads.request_rewarded("double_coins", func() -> void: pass)
	assert_bool(_ads.maybe_show_interstitial(10)).is_false()
	_now[0] = 121.0
	assert_bool(_ads.maybe_show_interstitial(15)).is_true()


func test_rewarded_below_min_level_does_not_block_later_interstitial() -> void:
	_ads.request_rewarded("double_coins", func() -> void: pass)
	assert_bool(_ads.maybe_show_interstitial(3)).is_false()
	_now[0] = 121.0
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()


func test_interstitial_min_level_from_config() -> void:
	assert_bool(_ads.maybe_show_interstitial(5)).is_false()
	GameConfig.apply_remote({"interstitial_min_level": 1})
	assert_bool(_ads.maybe_show_interstitial(5)).is_true()


func test_reset_break() -> void:
	_ads.request_rewarded("double_coins", func() -> void: pass)
	_ads.reset_break()
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()


func test_rewarded_calls_callback_on_reward() -> void:
	var calls: Array[int] = [0]
	var shown: bool = _ads.request_rewarded("double_coins", func() -> void: calls[0] += 1)
	assert_bool(shown).is_true()
	assert_int(calls[0]).is_equal(1)
	assert_int(_provider.rewarded_shown).is_equal(1)


func test_rewarded_no_callback_when_not_granted() -> void:
	_provider.reward_on_show = false
	var calls: Array[int] = [0]
	_ads.request_rewarded("double_coins", func() -> void: calls[0] += 1)
	assert_int(calls[0]).is_equal(0)


func test_rewarded_unavailable_returns_false() -> void:
	_provider.always_ready = false
	var calls: Array[int] = [0]
	assert_bool(_ads.request_rewarded("x", func() -> void: calls[0] += 1)).is_false()
	assert_int(calls[0]).is_equal(0)


func test_rewarded_always_unmuted_at_end() -> void:
	for reward: bool in [true, false]:
		_provider.reward_on_show = reward
		_ads.request_rewarded("x", func() -> void: pass)
		assert_bool(Audio.is_app_muted()).is_false()
	_provider.always_ready = false
	_ads.request_rewarded("x", func() -> void: pass)
	assert_bool(Audio.is_app_muted()).is_false()


func test_interstitial_unmuted_after_close() -> void:
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	assert_bool(Audio.is_app_muted()).is_false()


func _watchdog_events() -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if e.get("event_id", "") == "ads:watchdog:unmute":
			n += 1
	return n


func test_watchdog_unmutes_held_rewarded_once() -> void:
	_provider.hold_show = true
	_ads.request_rewarded("x", func() -> void: pass)
	assert_bool(Audio.is_app_muted()).is_true()
	_now[0] = 50.0
	_ads.poll_watchdog()
	assert_bool(Audio.is_app_muted()).is_true()
	assert_int(_watchdog_events()).is_equal(0)
	_now[0] = 91.0
	_ads.poll_watchdog()
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(_watchdog_events()).is_equal(1)
	_ads.poll_watchdog()
	assert_int(_watchdog_events()).is_equal(1)


func test_watchdog_interstitial_late_close_does_not_remute() -> void:
	_provider.hold_show = true
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	assert_bool(Audio.is_app_muted()).is_true()
	_now[0] = 91.0
	_ads.poll_watchdog()
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(_watchdog_events()).is_equal(1)
	_provider.release(true)
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(_watchdog_events()).is_equal(1)


func test_watchdog_not_fired_when_closed_in_time() -> void:
	var count: Array[int] = [0]
	_provider.hold_show = true
	_ads.request_rewarded("x", func() -> void: count[0] += 1)
	_now[0] = 10.0
	_provider.release(true)
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(count[0]).is_equal(1)
	_now[0] = 200.0
	_ads.poll_watchdog()
	assert_int(_watchdog_events()).is_equal(0)


func test_rewarded_after_watchdog_granted_once() -> void:
	var count: Array[int] = [0]
	_provider.hold_show = true
	_ads.request_rewarded("x", func() -> void: count[0] += 1)
	_now[0] = 91.0
	_ads.poll_watchdog()
	_provider.release(true)
	assert_int(count[0]).is_equal(1)
	assert_bool(Audio.is_app_muted()).is_false()
	_provider.release(true)
	assert_int(count[0]).is_equal(1)


func test_watchdog_timeout_follows_config() -> void:
	GameConfig.apply_remote({"ad_unmute_timeout_seconds": 5})
	_provider.hold_show = true
	_ads.request_rewarded("x", func() -> void: pass)
	_now[0] = 6.0
	_ads.poll_watchdog()
	assert_int(_watchdog_events()).is_equal(1)


func test_deferred_provider_grants_on_later_frame_once() -> void:
	_provider.deferred = true
	var calls: Array[int] = [0]
	var granted: Array[int] = [0]
	_ads.rewarded_granted.connect(func(_id: String) -> void: granted[0] += 1)
	assert_bool(_ads.request_rewarded("double_coins", func() -> void: calls[0] += 1)).is_true()
	assert_int(calls[0]).is_equal(0)
	assert_int(granted[0]).is_equal(0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(calls[0]).is_equal(1)
	assert_int(granted[0]).is_equal(1)
	assert_int(_provider.releases).is_equal(1)
