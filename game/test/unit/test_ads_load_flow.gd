extends GdUnitTestSuite
## T-238: zgoda -> ladowanie reklam -> przycisk rewarded (HUD extra_tube) przez App.

const SAVE_PATH: String = "user://test_ads_load_flow.json"
const GIVEUP: String = "ads:load:giveup:rewarded"

var _old_path: String
var _prev_an: AnalyticsProvider
var _prev_provider: AdProvider
var _prev_clock: Callable
var _prev_purchases_state: GameState
var _fake_an: FakeAnalyticsProvider
var _provider: FakeAdProvider
var _consent: FakeConsentProvider
var _now: Array[float] = [0.0]
var _unix: Array[int] = [TestClock.FIXED_UNIX]


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_prev_provider = Ads.provider
	_prev_clock = Ads.clock
	_prev_purchases_state = Purchases.state
	_now[0] = 0.0
	_provider = FakeAdProvider.new()
	_consent = FakeConsentProvider.new()
	_reset_ads()
	Ads.provider = _provider
	Ads.clock = TestClock.ticking_float(_now)


func after_test() -> void:
	Analytics.provider = _prev_an
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	_reset_ads()
	# Lambda w fake'u przechwytuje self (cykl RefCounted) - bez tego wyciek przy wyjsciu (T-297).
	_consent.pending_form_callback = Callable()
	_consent.pending_att_callback = Callable()
	_consent.pending_info_callback = Callable()
	Purchases.state = _prev_purchases_state
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	GameConfig.reset()


## Back to a pristine singleton: consent, remove-ads flag and the whole load machinery.
func _reset_ads() -> void:
	Ads.reset_for_test()


func _level() -> Level:
	var state := SaveSystem.fresh_state()
	state.level = 8
	state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	var app: App = auto_free(App.new())
	app.clock = TestClock.ticking(_unix)
	app.effects_enabled = false
	app.state = state
	add_child(app)
	app.current_screen().play_pressed.emit()
	return app.current_screen() as Level


## HUD rewarded button after Level refreshes its offers.
func _button_visible(level: Level) -> bool:
	level._refresh_offers()
	return level.hud.extra_tube_ad_button.visible


func _count(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if str(e.get("event_id", "")) == id:
			n += 1
	return n


func _hold_consent() -> void:
	_consent.region_eea = true
	_consent.form_required = true
	_consent.hold_form = true


func test_no_load_before_consent_finished_then_one_of_each() -> void:
	_hold_consent()
	Ads.begin_consent(_consent)
	_level()
	Ads.poll_loads()
	assert_int(Ads.consent_state).is_equal(Ads.ConsentState.PENDING)
	assert_int(_provider.rewarded_load_calls + _provider.interstitial_load_calls).is_zero()
	_consent.pending_form_callback.call(ConsentProvider.UMP_OBTAINED)
	Ads.poll_loads()
	assert_int(Ads.consent_state).is_equal(Ads.ConsentState.DONE)
	assert_int(_provider.rewarded_load_calls).is_equal(1)
	assert_int(_provider.interstitial_load_calls).is_equal(1)


func test_button_hidden_while_load_held_and_visible_after_release() -> void:
	_provider.hold_loads = true
	Ads.begin_consent(_consent)
	var level := _level()
	assert_bool(_button_visible(level)).is_true()  # fake: gotowa od startu, dopoki nie padnie
	_provider.release_load(false)  # rewarded: blad -> niegotowa
	assert_bool(_button_visible(level)).is_false()
	_now[0] += float(GameConfig.get_value("ad_load_retry_base_seconds"))
	Ads.poll_loads()
	_provider.release_load(true)  # najpierw wisi interstitial z preloadu
	assert_bool(_button_visible(level)).is_false()
	_provider.release_load(true)
	assert_bool(_button_visible(level)).is_true()


func test_giveup_after_max_retries_hides_button_to_end() -> void:
	var max_retries: int = int(GameConfig.get_value("ad_load_max_retries"))
	_provider.fail_next_loads(max_retries * 2)  # bledy dziela oba formaty
	Ads.begin_consent(_consent)
	var level := _level()
	var cap: float = float(GameConfig.get_value("ad_load_retry_max_seconds"))
	for i in range(max_retries + 1):
		_now[0] += cap
		Ads.poll_loads()
	assert_int(_count(GIVEUP)).is_equal(1)
	assert_bool(_button_visible(level)).is_false()
	var calls: int = _provider.rewarded_load_calls
	_now[0] += cap * 10.0
	Ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(calls)
	assert_int(_count(GIVEUP)).is_equal(1)
	assert_bool(_button_visible(level)).is_false()


func test_button_hidden_after_granted_show_until_next_loaded() -> void:
	Ads.begin_consent(_consent)
	var level := _level()
	assert_bool(_button_visible(level)).is_true()
	_provider.hold_loads = true
	assert_bool(Ads.request_rewarded("p", func() -> void: pass)).is_true()
	assert_int(_provider.rewarded_load_calls).is_equal(2)
	assert_bool(_button_visible(level)).is_false()
	_provider.release_load(true)
	assert_bool(_button_visible(level)).is_true()


func test_ads_removed_purchase_stops_interstitial_loads_keeps_rewarded() -> void:
	Ads.begin_consent(_consent)
	var level := _level()
	var every_n: int = int(GameConfig.get_value("interstitial_every_n_rounds"))
	var min_level: int = int(GameConfig.get_value("interstitial_min_level"))
	_provider.hold_show = true
	(
		assert_bool(
			Ads.maybe_show_interstitial(every_n * maxi(1, ceili(float(min_level) / every_n)))
		)
		. is_true()
	)
	assert_bool(Purchases.grant(Purchases.SKU_REMOVE_ADS)).is_true()
	assert_bool(Ads.ads_removed).is_true()
	var interstitial_loads: int = _provider.interstitial_load_calls
	_provider.release(true)  # zamkniecie interstitiala
	assert_int(_provider.interstitial_load_calls).is_equal(interstitial_loads)
	var rewarded_loads: int = _provider.rewarded_load_calls
	assert_bool(Ads.request_rewarded("p", func() -> void: pass)).is_true()
	_provider.release(true)
	assert_int(_provider.rewarded_load_calls).is_equal(rewarded_loads + 1)
	assert_bool(_button_visible(level)).is_true()


## Drives both formats to giveup (max retries failures each), stopping right at it.
func _give_up() -> void:
	var cap: float = float(GameConfig.get_value("ad_load_retry_max_seconds"))
	for i in range(int(GameConfig.get_value("ad_load_max_retries")) + 1):
		if Ads._policies["rewarded"].gave_up():
			break
		_now[0] += cap
		Ads.poll_loads()


func test_resume_before_cap_after_giveup_does_not_load() -> void:
	_provider.fail_next_loads(int(GameConfig.get_value("ad_load_max_retries")) * 2)
	Ads.begin_consent(_consent)
	var level := _level()
	_give_up()
	assert_int(_count(GIVEUP)).is_equal(1)
	var calls: int = _provider.rewarded_load_calls
	_now[0] += 10.0
	Ads.on_app_resumed()
	assert_int(_provider.rewarded_load_calls).is_equal(calls)
	assert_bool(_button_visible(level)).is_false()


func test_resume_after_cap_after_giveup_loads_once_and_shows_button() -> void:
	_provider.fail_next_loads(int(GameConfig.get_value("ad_load_max_retries")) * 2)
	Ads.begin_consent(_consent)
	var level := _level()
	_give_up()
	var calls: int = _provider.rewarded_load_calls
	_now[0] += float(GameConfig.get_value("ad_load_retry_max_seconds"))
	Ads.on_app_resumed()
	assert_int(_provider.rewarded_load_calls).is_equal(calls + 1)
	assert_bool(_button_visible(level)).is_true()
	Ads.on_app_resumed()
	assert_int(_provider.rewarded_load_calls).is_equal(calls + 1)


func test_second_series_giveup_reported_once_more() -> void:
	var max_retries: int = int(GameConfig.get_value("ad_load_max_retries"))
	_provider.fail_next_loads(max_retries * 4)
	Ads.begin_consent(_consent)
	var level := _level()
	_give_up()
	_now[0] += float(GameConfig.get_value("ad_load_retry_max_seconds"))
	Ads.on_app_resumed()
	_give_up()
	assert_int(_count(GIVEUP)).is_equal(2)
	var calls: int = _provider.rewarded_load_calls
	_now[0] += 1000.0
	Ads.poll_loads()
	assert_int(_provider.rewarded_load_calls).is_equal(calls)
	assert_int(_count(GIVEUP)).is_equal(2)


func test_resume_without_giveup_loads_nothing() -> void:
	Ads.begin_consent(_consent)
	var level := _level()
	var rewarded: int = _provider.rewarded_load_calls
	var interstitial: int = _provider.interstitial_load_calls
	_now[0] += 1000.0
	Ads.on_app_resumed()
	assert_int(_provider.rewarded_load_calls).is_equal(rewarded)
	assert_int(_provider.interstitial_load_calls).is_equal(interstitial)
	assert_bool(_button_visible(level)).is_true()


func test_resume_after_giveup_skips_interstitial_when_ads_removed() -> void:
	_provider.fail_next_loads(int(GameConfig.get_value("ad_load_max_retries")) * 2)
	Ads.begin_consent(_consent)
	var level := _level()
	_give_up()
	Ads.set_ads_removed(true)
	var interstitial: int = _provider.interstitial_load_calls
	_now[0] += float(GameConfig.get_value("ad_load_retry_max_seconds"))
	Ads.on_app_resumed()
	assert_int(_provider.interstitial_load_calls).is_equal(interstitial)
