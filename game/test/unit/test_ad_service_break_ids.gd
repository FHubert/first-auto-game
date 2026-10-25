extends GdUnitTestSuite
## T-212: interstitial closes are paired by break id (not FIFO).

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
	_provider.hold_show = true
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = TestClock.ticking_float(_now)


func after_test() -> void:
	Analytics.provider = _prev_an
	Audio.set_app_muted(false)
	GameConfig.reset()


func _count(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if str(e.get("event_id", "")) == id:
			n += 1
	return n


func _show_interstitial() -> void:
	_provider.load_interstitial()
	_ads.reset_interstitial_cooldown()
	assert_bool(_ads.maybe_show_interstitial(10)).is_true()


func test_closes_in_reverse_order_leave_no_open_breaks() -> void:
	_show_interstitial()
	_show_interstitial()
	assert_int(_provider.held.size()).is_equal(2)
	assert_int(_ads._open_interstitials.size()).is_equal(2)
	var loads: int = _provider.interstitial_load_calls
	_provider.release_at(1, true)
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(_provider.interstitial_load_calls - loads).is_equal(1)
	_provider.release_at(0, true)
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(_ads._open_interstitials.size()).is_equal(0)
	# The ad was reloaded by the first close, so the second one loads nothing.
	assert_int(_provider.interstitial_load_calls - loads).is_equal(1)
	assert_int(_count("ads:watchdog:unmute")).is_equal(0)
	assert_int(_count("ads:watchdog:late:interstitial")).is_equal(0)


func test_duplicate_close_has_no_effect() -> void:
	_show_interstitial()
	_provider.release_at(0, true)
	var loads: int = _provider.interstitial_load_calls
	var events: int = _fake_an.events.size()
	Audio.set_app_muted(true)
	_provider.emit_interstitial_closed(1)
	_provider.emit_interstitial_closed(99)
	assert_bool(Audio.is_app_muted()).is_true()
	assert_int(_provider.interstitial_load_calls).is_equal(loads)
	assert_int(_provider.rewarded_load_calls).is_equal(0)
	assert_int(_fake_an.events.size()).is_equal(events)


func test_late_close_after_watchdog_reported_once() -> void:
	_show_interstitial()
	_now[0] = float(GameConfig.get_value("ad_unmute_timeout_seconds"))
	_ads.poll_watchdog()
	assert_int(_ads._open_interstitials.size()).is_equal(0)
	assert_int(_count("ads:watchdog:unmute")).is_equal(1)
	_provider.release_at(0, true)
	assert_int(_count("ads:watchdog:late:interstitial")).is_equal(1)
	_provider.emit_interstitial_closed(1)
	assert_int(_count("ads:watchdog:late:interstitial")).is_equal(1)
	assert_int(_count("ads:watchdog:unmute")).is_equal(1)
