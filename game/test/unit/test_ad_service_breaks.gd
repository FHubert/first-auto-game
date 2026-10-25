extends GdUnitTestSuite
## T-204: numer przerwy reklamowej - spozniony callback po watchdogu nie rusza przerwy B.

var _ads: Node
var _provider: FakeAdProvider
var _now: Array[int] = [0]
var _fake_an: FakeAnalyticsProvider
var _prev_an: AnalyticsProvider
var _rewards: Array[int] = [0]


func before_test() -> void:
	GameConfig.reset()
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_now[0] = 0
	_rewards[0] = 0
	_provider = FakeAdProvider.new()
	_provider.hold_show = true
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = TestClock.ticking(_now)


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


func _timeout() -> int:
	return int(GameConfig.get_value("ad_unmute_timeout_seconds"))


func _reward() -> void:
	_rewards[0] += 1


func _lose_a_then_start_b(a_kind: String) -> void:
	if a_kind == "rewarded":
		_ads.request_rewarded("a", _reward)
	else:
		assert_bool(_ads.maybe_show_interstitial(10)).is_true()
	_now[0] = _timeout()
	_ads.poll_watchdog()
	assert_bool(Audio.is_app_muted()).is_false()
	_now[0] += 1
	_ads.request_rewarded("b", _reward)
	assert_bool(Audio.is_app_muted()).is_true()


func test_late_rewarded_a_does_not_unmute_break_b() -> void:
	_lose_a_then_start_b("rewarded")
	_provider.release_at(0, true)
	assert_bool(Audio.is_app_muted()).is_true()
	assert_int(_rewards[0]).is_equal(1)
	assert_int(_count("ads:watchdog:late:rewarded")).is_equal(1)
	assert_int(_count("ads:rewarded:a:granted")).is_equal(1)
	# B's watchdog is still armed.
	_now[0] += _timeout()
	_ads.poll_watchdog()
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(_count("ads:watchdog:unmute")).is_equal(2)


func test_late_interstitial_a_does_not_unmute_break_b() -> void:
	_lose_a_then_start_b("interstitial")
	_provider.release_at(0, true)
	assert_bool(Audio.is_app_muted()).is_true()
	assert_int(_count("ads:watchdog:late:interstitial")).is_equal(1)
	_now[0] += _timeout()
	_ads.poll_watchdog()
	assert_bool(Audio.is_app_muted()).is_false()


func test_late_a_without_b_grants_once_and_keeps_audio() -> void:
	_ads.request_rewarded("a", _reward)
	_now[0] = _timeout()
	_ads.poll_watchdog()
	# Someone else muted meanwhile: the late callback must not switch audio again.
	Audio.set_app_muted(true)
	_provider.release(true)
	assert_bool(Audio.is_app_muted()).is_true()
	assert_int(_rewards[0]).is_equal(1)
	assert_int(_count("ads:watchdog:late:rewarded")).is_equal(1)


func test_b_ends_normally_after_late_a_unmutes_once() -> void:
	_lose_a_then_start_b("rewarded")
	_provider.release_at(0, true)
	assert_bool(Audio.is_app_muted()).is_true()
	_provider.release_at(0, true)
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(_rewards[0]).is_equal(2)
	assert_int(_count("ads:watchdog:late:rewarded")).is_equal(1)
	assert_int(_count("ads:watchdog:unmute")).is_equal(1)


func test_duplicate_callback_grants_once() -> void:
	_ads.request_rewarded("a", _reward)
	_now[0] = _timeout()
	_ads.poll_watchdog()
	var cb: Callable = _provider.held[0]["cb"]
	_provider.release_at(0, true)
	_provider.release_at(0, true)
	cb.call(true)
	assert_int(_rewards[0]).is_equal(1)
	assert_int(_count("ads:rewarded:a:granted")).is_equal(1)
	assert_int(_count("ads:watchdog:late:rewarded")).is_equal(1)


func test_release_at_picks_any_held_show() -> void:
	_ads.request_rewarded("a", _reward)
	_provider.release_at(5, true)
	assert_int(_provider.held.size()).is_equal(1)
	_provider.release_at(0, false)
	assert_int(_provider.held.size()).is_equal(0)
	assert_int(_rewards[0]).is_equal(0)
