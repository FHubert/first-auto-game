extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_consent_ui.json"

var _ads: Node
var _provider: FakeAdProvider
var _now: Array[float] = [0.0]
var _old_path: String


func before_test() -> void:
	GameConfig.reset()
	_now[0] = 0.0
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	Ads.reset_consent()
	_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _provider
	_ads.clock = func() -> float: return _now[0]


func after_test() -> void:
	Ads.reset_consent()
	SaveSystem.save_path = _old_path
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
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
	app.state = GameState.new()
	app.state.settings["tutorial_done"] = true
	add_child(app)
	assert_int(Ads.consent_state).is_equal(Ads.ConsentState.DONE)
