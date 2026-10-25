extends GdUnitTestSuite
## T-257: reklama starsza niz ad_max_age_seconds jest niegotowa i ladowana ponownie.

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
	_provider.clock = TestClock.ticking_float(_now)
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = TestClock.ticking_float(_now)
	_ads.poll_loads()  # preload both formats at t = 0


func after_test() -> void:
	Analytics.provider = _prev_an
	Audio.set_app_muted(false)
	GameConfig.reset()


func _fails() -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if str(e.get("event_id", "")).begins_with("ads:load:fail"):
			n += 1
	return n


func _level_no() -> int:
	var n: int = int(GameConfig.get_value("interstitial_every_n_rounds"))
	return maxi(n, int(GameConfig.get_value("interstitial_min_level"))) * n


func test_rewarded_fresh_just_before_limit() -> void:
	_now[0] = 3299.0
	_ads.poll_loads()
	assert_bool(_ads.is_rewarded_ready()).is_true()
	assert_int(_provider.rewarded_load_calls).is_equal(1)


func test_rewarded_stale_at_limit_reloads_once_then_ready() -> void:
	_provider.hold_loads = true
	_now[0] = 3300.0
	_ads.poll_loads()
	_ads.poll_loads()
	assert_bool(_ads.is_rewarded_ready()).is_false()
	assert_int(_provider.rewarded_load_calls).is_equal(2)
	_provider.release_load(true)
	assert_bool(_ads.is_rewarded_ready()).is_true()
	assert_int(_fails()).is_equal(0)


func test_interstitial_stale_not_shown_then_reloaded() -> void:
	_provider.hold_loads = true
	_now[0] = 3300.0
	_ads.poll_loads()
	assert_int(_provider.interstitial_load_calls).is_equal(2)
	assert_bool(_ads.maybe_show_interstitial(_level_no())).is_false()
	assert_int(_provider.interstitials_shown).is_equal(0)
	_provider.release_load(true)
	_provider.release_load(true)
	assert_bool(_ads.maybe_show_interstitial(_level_no())).is_true()


func test_interstitial_fresh_before_limit_and_removed_ads_no_load() -> void:
	_now[0] = 3299.0
	_ads.poll_loads()
	assert_int(_provider.interstitial_load_calls).is_equal(1)
	_ads.set_ads_removed(true)
	_now[0] = 7000.0
	_ads.poll_loads()
	assert_int(_provider.interstitial_load_calls).is_equal(1)


func test_resume_after_two_hours_one_load_per_format_no_giveup_double() -> void:
	_now[0] = 7200.0
	_ads.on_app_resumed()
	assert_int(_provider.rewarded_load_calls).is_equal(2)
	assert_int(_provider.interstitial_load_calls).is_equal(2)
	_ads.on_app_resumed()
	_ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(2)
	assert_bool(_ads.is_rewarded_ready()).is_true()


func test_resume_after_giveup_and_stale_loads_once() -> void:
	_provider.fail_next_loads(100)
	_provider.hold_loads = false
	for t: int in [0, 1000, 2000, 3000, 4000, 5000, 6000, 7000]:
		_now[0] = float(t)
		_ads.poll_loads()
	var calls: int = _provider.rewarded_load_calls
	_now[0] = 20000.0
	_ads.on_app_resumed()
	assert_int(_provider.rewarded_load_calls).is_equal(calls)


func test_fake_expired_show_closes_without_reward() -> void:
	_provider.expire_after_seconds = 100.0
	_now[0] = 100.0
	var got: Array[bool] = []
	_provider.show_rewarded(func(g: bool) -> void: got.append(g))
	assert_array(got).is_equal([false])
