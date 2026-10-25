extends GdUnitTestSuite
## T-240: Ads.reset_for_test() returns the singleton to its post-startup state.

var _prev_provider: AdProvider
var _prev_clock: Callable
var _now: Array[float] = [0.0]


func before_test() -> void:
	GameConfig.reset()
	_prev_provider = Ads.provider
	_prev_clock = Ads.clock
	_now[0] = 0.0
	Ads.reset_for_test()
	Ads.clock = TestClock.ticking_float(_now)


func after_test() -> void:
	Ads.reset_for_test()
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	GameConfig.reset()


func test_reset_clears_dirty_state() -> void:
	var fake := FakeAdProvider.new()
	fake.hold_show = true
	Ads.provider = fake
	Ads.set_ads_removed(true)
	Ads.poll_loads()
	Ads.set_ads_removed(false)
	var level: int = int(GameConfig.get_value("interstitial_every_n_rounds"))
	level *= maxi(1, ceili(float(GameConfig.get_value("interstitial_min_level")) / level))
	assert_bool(Ads.maybe_show_interstitial(level)).is_true()
	assert_bool(Ads._ad_break_open).is_true()
	fake.fail_next_loads(1)
	Ads._on_load_done("rewarded", false)
	assert_int((Ads._policies["rewarded"] as AdLoadPolicy).failures()).is_greater(0)
	Ads.set_ads_removed(true)

	Ads.reset_for_test()

	assert_bool(Ads.ads_removed).is_false()
	assert_bool(Ads._open_interstitials.is_empty()).is_true()
	assert_bool(Ads._ad_break_open).is_false()
	assert_int((Ads._policies["rewarded"] as AdLoadPolicy).failures()).is_equal(0)
	assert_bool(Ads._preload_started).is_false()
	assert_object(Ads._signals_provider).is_null()
	assert_int(Ads.interstitials_shown).is_equal(0)
	assert_bool(Audio.is_app_muted()).is_false()
	assert_int(fake.rewarded_loaded.get_connections().size()).is_equal(0)


func test_poll_loads_after_reset_connects_signals_once() -> void:
	var fake := FakeAdProvider.new()
	Ads.provider = fake
	Ads.poll_loads()
	assert_int(fake.rewarded_loaded.get_connections().size()).is_equal(1)
	Ads.reset_for_test()
	Ads.provider = fake
	Ads.poll_loads()
	assert_int(fake.rewarded_loaded.get_connections().size()).is_equal(1)
	assert_int(fake.interstitial_load_failed.get_connections().size()).is_equal(1)
	assert_int(fake.rewarded_load_calls).is_equal(2)
