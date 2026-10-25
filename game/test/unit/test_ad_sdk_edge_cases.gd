extends GdUnitTestSuite
## T-258: SDK callbacks arriving "out of turn" (late, doubled, stale) on the Ads singleton.
## Uses only the existing AdProvider contract (signals + show_rewarded callback).

var _fake: FakeAdProvider
var _fake_an: FakeAnalyticsProvider
var _prev_an: AnalyticsProvider
var _prev_provider: AdProvider
var _prev_clock: Callable
var _now: Array[float] = [0.0]
var _rewards: Array[int] = [0]


func before_test() -> void:
	GameConfig.reset()
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_prev_provider = Ads.provider
	_prev_clock = Ads.clock
	_now[0] = 0.0
	_rewards[0] = 0
	Ads.reset_for_test()
	_fake = FakeAdProvider.new()
	_fake.clock = TestClock.ticking_float(_now)
	Ads.provider = _fake
	Ads.clock = TestClock.ticking_float(_now)


func after_test() -> void:
	Ads.reset_for_test()
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	Analytics.provider = _prev_an
	GameConfig.reset()


func _count(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if str(e.get("event_id", "")) == id:
			n += 1
	return n


func _on_reward() -> void:
	_rewards[0] += 1


func _interstitial_level() -> int:
	var every_n: int = int(GameConfig.get_value("interstitial_every_n_rounds"))
	return every_n * maxi(1, ceili(float(GameConfig.get_value("interstitial_min_level")) / every_n))


func _double_close(cb: Callable) -> void:
	_fake.release(true)
	cb.call(true)
	_fake.rewarded_closed.emit(true)


func _stray_closes() -> void:
	_fake.rewarded_closed.emit(true)
	_fake.rewarded_closed.emit(false)


## Fails the rewarded load until giveup (max retries failures, backoff capped at the max wait).
func _give_up_rewarded() -> void:
	var cap: float = float(GameConfig.get_value("ad_load_retry_max_seconds"))
	for i in int(GameConfig.get_value("ad_load_max_retries")) + 1:
		if (Ads._policies["rewarded"] as AdLoadPolicy).gave_up():
			break
		_now[0] += cap
		Ads.poll_loads()


## Contract: AdProvider.rewarded_loaded may arrive after AdService gave up (late SDK answer).
## Guarantee: the format is ready again without an extra load_*, and a later giveup in the
## new series is reported once more (`ads:load:giveup:rewarded` total 2, not 1).
func test_1_rewarded_loaded_after_giveup_ready_and_next_giveup_reported() -> void:
	var max_retries: int = int(GameConfig.get_value("ad_load_max_retries"))
	_fake.fail_next_loads(max_retries * 2)
	Ads.poll_loads()
	_give_up_rewarded()
	assert_int(_count("ads:load:giveup:rewarded")).is_equal(1)
	var calls: int = _fake.rewarded_load_calls
	_fake._rewarded_loaded = true
	_fake.rewarded_loaded.emit()
	assert_bool(Ads.is_rewarded_ready()).is_true()
	_now[0] += float(GameConfig.get_value("ad_load_retry_max_seconds"))
	Ads.poll_loads()
	assert_int(_fake.rewarded_load_calls).is_equal(calls)
	# New series: show, close, every reload fails until the next giveup.
	_fake.fail_next_loads(max_retries * 2)
	assert_bool(Ads.request_rewarded("a", _on_reward)).is_true()
	_give_up_rewarded()
	assert_int(_count("ads:load:giveup:rewarded")).is_equal(2)


## Contract: show_rewarded(callback) may call back twice for one break (rewarded_closed(true) x2).
## Guarantee: reward and `ads:rewarded:<placement>:granted` exactly once, no extra load.
func test_2_double_rewarded_callback_grants_once() -> void:
	_fake.hold_show = true
	Ads.poll_loads()
	assert_bool(Ads.request_rewarded("a", _on_reward)).is_true()
	var cb: Callable = _fake.held[0]["cb"]
	var loads: int = _fake.rewarded_load_calls
	await assert_error(_double_close.bind(cb)).is_success()
	assert_int(_rewards[0]).is_equal(1)
	assert_int(_count("ads:rewarded:a:granted")).is_equal(1)
	assert_int(_fake.rewarded_load_calls).is_equal(loads + 1)
	assert_bool(Audio.is_app_muted()).is_false()


## Contract: interstitial_closed(ad_id) with an id from before Ads.reset_for_test().
## Guarantee: unknown id only warns; the current break stays open (audio muted), nothing breaks.
func test_3_stale_interstitial_close_after_reset_is_ignored() -> void:
	_fake.hold_show = true
	Ads.poll_loads()
	assert_bool(Ads.maybe_show_interstitial(_interstitial_level())).is_true()
	var stale_id: int = Ads._break_id
	Ads.reset_for_test()
	_fake.hold_show = true
	_fake.load_interstitial()
	assert_bool(Ads.maybe_show_interstitial(_interstitial_level())).is_true()
	assert_bool(Audio.is_app_muted()).is_true()
	var loads: int = _fake.interstitial_load_calls
	_fake.emit_interstitial_closed(stale_id)
	assert_bool(Audio.is_app_muted()).is_true()
	assert_bool(Ads._ad_break_open).is_true()
	assert_int(Ads._open_interstitials.size()).is_equal(1)
	assert_int(_fake.interstitial_load_calls).is_equal(loads)


## Contract: rewarded_load_failed(code) while a rewarded ad is on screen.
## Guarantee: the policy counts exactly 1 failure, closing the ad starts no second parallel
## load (backoff first), then exactly 1 retry when due.
func test_4_load_failed_during_show_counts_once_no_parallel_load() -> void:
	_fake.hold_show = true
	Ads.poll_loads()
	assert_bool(Ads.request_rewarded("a", _on_reward)).is_true()
	var loads: int = _fake.rewarded_load_calls
	_fake.rewarded_load_failed.emit(3)
	var policy: AdLoadPolicy = Ads._policies["rewarded"]
	assert_int(policy.failures()).is_equal(1)
	_fake.release(true)
	assert_int(_rewards[0]).is_equal(1)
	assert_int(_fake.rewarded_load_calls).is_equal(loads)
	assert_int(_count("ads:load:fail:rewarded")).is_equal(1)
	_now[0] += float(GameConfig.get_value("ad_load_retry_base_seconds"))
	Ads.poll_loads()
	Ads.poll_loads()
	assert_int(_fake.rewarded_load_calls).is_equal(loads + 1)
	assert_int(policy.failures()).is_equal(0)


## Contract: interstitial_loaded arriving although ads_removed (late answer of an old load).
## Guarantee: the interstitial is never shown and never reloaded, even after it would go stale.
func test_5_interstitial_loaded_when_ads_removed_never_shown_or_reloaded() -> void:
	Ads.set_ads_removed(true)
	Ads.poll_loads()
	assert_int(_fake.interstitial_load_calls).is_equal(0)
	_fake.interstitial_loaded.emit()
	var level: int = _interstitial_level()
	assert_bool(Ads.maybe_show_interstitial(level, true)).is_false()
	_now[0] += float(GameConfig.get_value("ad_max_age_seconds")) * 2.0
	Ads.poll_loads()
	Ads.on_app_resumed()
	assert_bool(Ads.maybe_show_interstitial(level, true)).is_false()
	assert_int(_fake.interstitials_shown).is_equal(0)
	assert_int(Ads.interstitials_shown).is_equal(0)
	assert_int(_fake.interstitial_load_calls).is_equal(0)


## Contract: AdProvider.rewarded_closed(granted) emitted with no open break. Deviation from KA:
## AdService does NOT listen to this signal (only the show_rewarded callback), so the stray
## emission is a no-op, not a warning. Guarantee: 0 rewards, 0 granted events, 0 errors, 0 loads,
## and an open interstitial break is not closed by it.
func test_6_stray_rewarded_closed_without_break_is_ignored() -> void:
	Ads.poll_loads()
	var loads: int = _fake.rewarded_load_calls
	await assert_error(_stray_closes).is_success()
	assert_int(_rewards[0]).is_equal(0)
	assert_int(_count("ads:rewarded:a:granted")).is_equal(0)
	assert_int(_fake.rewarded_load_calls).is_equal(loads)
	assert_bool(Audio.is_app_muted()).is_false()
	_fake.hold_show = true
	assert_bool(Ads.maybe_show_interstitial(_interstitial_level())).is_true()
	_fake.rewarded_closed.emit(true)
	assert_bool(Audio.is_app_muted()).is_true()
	assert_int(_rewards[0]).is_equal(0)
