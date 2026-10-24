extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_consent_ui.json"

var _ads: Node
var _provider: FakeAdProvider
var _now: Array[float] = [0.0]
var _old_path: String
var _fake_an: FakeAnalyticsProvider
var _prev_an: AnalyticsProvider
var _prev_ads_provider: AdProvider
var _glob_ads: FakeAdProvider


func before_test() -> void:
	GameConfig.reset()
	_now[0] = 0.0
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_prev_ads_provider = Ads.provider
	_glob_ads = FakeAdProvider.new()
	Ads.provider = _glob_ads
	Ads.reset_consent()
	_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = func() -> float: return _now[0]


func after_test() -> void:
	Analytics.provider = _prev_an
	Ads.provider = _prev_ads_provider
	Ads.reset_consent()
	SaveSystem.save_path = _old_path
	TestSaveCleanup.remove(SAVE_PATH)
	GameConfig.reset()


func _settings() -> SettingsScreen:
	var s: SettingsScreen = auto_free(load("res://src/ui/settings_screen.tscn").instantiate())
	s.state = GameState.new()
	add_child(s)
	return s


func test_gate_blocks_until_timeout_then_non_personalized() -> void:
	var fake := FakeConsentProvider.new()
	fake.respond = false
	_ads.begin_consent(fake)
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.PENDING)
	assert_bool(_ads.is_rewarded_ready()).is_false()
	assert_bool(_ads.request_rewarded("x", func() -> void: pass)).is_false()
	assert_bool(_ads.maybe_show_interstitial(10)).is_false()
	_now[0] = 9.0
	_ads._process(0.0)
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.DONE)
	assert_bool(_ads.consent_result.timed_out).is_true()
	assert_bool(_ads.request_rewarded("x", func() -> void: pass)).is_true()
	assert_bool(_provider.personalized).is_false()


func test_default_fake_outside_eea_is_instant_and_personalized() -> void:
	_ads.begin_consent()
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.DONE)
	assert_bool(_ads.request_rewarded("x", func() -> void: pass)).is_true()
	assert_int(_provider.set_personalized_calls).is_equal(1)
	assert_bool(_provider.personalized).is_true()


func test_eea_denied_still_serves_non_personalized() -> void:
	var fake := FakeConsentProvider.new()
	fake.region_eea = true
	fake.form_required = true
	fake.ump_status = ConsentProvider.UMP_DENIED
	_ads.begin_consent(fake)
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.DONE)
	assert_bool(_provider.personalized).is_false()
	assert_bool(_ads.request_rewarded("x", func() -> void: pass)).is_true()


func test_begin_consent_is_idempotent() -> void:
	var fake := FakeConsentProvider.new()
	_ads.begin_consent(fake)
	_ads.begin_consent(fake)
	assert_int(fake.info_update_calls).is_equal(1)


func test_settings_privacy_button_visible_and_calls_provider() -> void:
	var fake := FakeConsentProvider.new()
	fake.privacy_options_required = true
	Ads.begin_consent(fake)
	var s := _settings()
	assert_bool(s.privacy_button.visible).is_true()
	s.privacy_button.pressed.emit()
	assert_int(fake.privacy_options_shown).is_equal(1)


func test_settings_privacy_button_hidden_when_not_required() -> void:
	var fake := FakeConsentProvider.new()
	Ads.begin_consent(fake)
	var s := _settings()
	assert_bool(s.privacy_button.visible).is_false()


func test_app_ready_starts_consent() -> void:
	var app: App = auto_free(App.new())
	app.clock = TestClock.fixed()
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	assert_int(Ads.consent_state).is_equal(Ads.ConsentState.DONE)


func _eea_fake(start: String) -> FakeConsentProvider:
	var fake := FakeConsentProvider.new()
	fake.region_eea = true
	fake.form_required = true
	fake.ump_status = start
	fake.privacy_options_required = true
	return fake


func _count(event_id: String) -> int:
	var n: int = 0
	for e in _fake_an.events:
		if e.get("event_id", "") == event_id:
			n += 1
	return n


func test_privacy_options_consent_to_denied() -> void:
	var fake := _eea_fake(ConsentProvider.UMP_OBTAINED)
	Ads.begin_consent(fake)
	assert_bool(_glob_ads.personalized).is_true()
	var calls: int = _glob_ads.set_personalized_calls
	fake.privacy_options_status = ConsentProvider.UMP_DENIED
	Ads.show_privacy_options()
	assert_bool(_glob_ads.personalized).is_false()
	assert_int(_glob_ads.set_personalized_calls).is_equal(calls + 1)
	assert_str(Ads.consent_result["ump_status"]).is_equal("denied")
	assert_bool(Ads.consent_result["personalized"]).is_false()


func test_privacy_options_denied_to_consent() -> void:
	var fake := _eea_fake(ConsentProvider.UMP_DENIED)
	Ads.begin_consent(fake)
	assert_bool(_glob_ads.personalized).is_false()
	fake.privacy_options_status = ConsentProvider.UMP_OBTAINED
	Ads.show_privacy_options()
	assert_bool(_glob_ads.personalized).is_true()
	assert_bool(Ads.consent_result["personalized"]).is_true()


func test_privacy_options_reports_single_ump_event() -> void:
	var fake := _eea_fake(ConsentProvider.UMP_OBTAINED)
	Ads.begin_consent(fake)
	var before: int = _count("consent:ump:denied")
	fake.privacy_options_status = ConsentProvider.UMP_DENIED
	Ads.show_privacy_options()
	assert_int(_count("consent:ump:denied")).is_equal(before + 1)


func test_settings_button_follows_consent_finished() -> void:
	var fake := _eea_fake(ConsentProvider.UMP_OBTAINED)
	Ads.begin_consent(fake)
	var s := _settings()
	assert_bool(s.privacy_button.visible).is_true()
	fake.privacy_options_required = false
	Ads.show_privacy_options()
	assert_bool(s.privacy_button.visible).is_false()
	fake.privacy_options_required = true
	Ads.show_privacy_options()
	assert_bool(s.privacy_button.visible).is_true()


func test_ads_process_mode_always() -> void:
	assert_int(Ads.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	add_child(_ads)
	assert_int(_ads.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_privacy_options_without_provider_is_noop() -> void:
	var before: int = _fake_an.events.size()
	Ads.show_privacy_options()
	assert_int(_fake_an.events.size()).is_equal(before)
