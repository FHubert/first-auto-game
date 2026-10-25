extends GdUnitTestSuite
## T-225: ladowanie reklam w AdService (preload, ponawianie wg AdLoadPolicy, eventy ads:load:*).

var _ads: Node
var _provider: FakeAdProvider
var _now: Array[int] = [0]
var _fake_an: FakeAnalyticsProvider
var _prev_an: AnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_now[0] = 0
	_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = TestClock.ticking(_now)


func after_test() -> void:
	Analytics.provider = _prev_an
	Audio.set_app_muted(false)
	GameConfig.reset()


func _events(id: String) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in _fake_an.events:
		if str(e.get("event_id", "")) == id:
			out.append(float(e.get("value", 0.0)))
	return out


func _show_rewarded() -> void:
	assert_bool(_ads.request_rewarded("p", func() -> void: pass)).is_true()


func test_rewarded_not_ready_after_show_until_loaded() -> void:
	_provider.hold_loads = true
	_show_rewarded()
	assert_bool(_ads.is_rewarded_ready()).is_false()
	assert_int(_provider.rewarded_load_calls).is_equal(1)
	_provider.release_load(true)
	assert_bool(_ads.is_rewarded_ready()).is_true()


func test_three_failures_retry_after_2_4_8_seconds_then_ready() -> void:
	_ads.poll_loads()  # initial preload (succeeds)
	_provider.fail_next_loads(3)
	_show_rewarded()
	var base: int = _provider.rewarded_load_calls
	assert_int(base).is_equal(2)
	_now[0] = 1
	_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(base)
	_now[0] = 2
	_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(base + 1)
	_now[0] = 5
	_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(base + 1)
	_now[0] = 6
	_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(base + 2)
	assert_bool(_ads.is_rewarded_ready()).is_false()
	_now[0] = 13
	_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(base + 2)
	_now[0] = 14
	_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(base + 3)
	assert_bool(_ads.is_rewarded_ready()).is_true()
	assert_array(_events("ads:load:fail:rewarded")).is_equal([1.0, 2.0, 3.0])


func test_six_failures_give_up_once_and_stop_retrying() -> void:
	_ads.poll_loads()  # initial preload (succeeds)
	_provider.fail_next_loads(99)
	_show_rewarded()
	var base: int = _provider.rewarded_load_calls
	for i: int in 200:
		_now[0] = i * 10
		_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(base + 5)
	assert_int(_events("ads:load:giveup:rewarded").size()).is_equal(1)
	assert_int(_events("ads:load:fail:rewarded").size()).is_equal(6)
	_ads.request_rewarded("p", func() -> void: pass)
	assert_int(_provider.rewarded_load_calls).is_equal(base + 5)


func test_ads_removed_skips_interstitial_loading() -> void:
	_ads.set_ads_removed(true)
	_ads.poll_loads()
	assert_int(_provider.interstitial_load_calls).is_equal(0)
	assert_int(_provider.rewarded_load_calls).is_equal(1)
	_ads.set_ads_removed(false)
	_provider.hold_show = true
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	_provider.release(true)
	assert_int(_provider.interstitial_load_calls).is_equal(1)


func test_two_closes_in_same_frame_load_once() -> void:
	_provider.hold_show = true
	_provider.hold_loads = true
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	_provider.interstitial_closed.emit()
	_provider.interstitial_closed.emit()
	assert_int(_provider.interstitial_load_calls).is_equal(1)


func test_late_callback_after_watchdog_loads_once() -> void:
	_provider.hold_show = true
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	_now[0] = int(GameConfig.get_value("ad_unmute_timeout_seconds"))
	_ads.poll_watchdog()
	assert_int(_provider.interstitial_load_calls).is_equal(1)
	_provider.release(true)
	assert_int(_provider.interstitial_load_calls).is_equal(1)
	assert_int(_provider.rewarded_load_calls).is_equal(0)
