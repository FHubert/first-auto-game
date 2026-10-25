extends GdUnitTestSuite
## T-205: limit czasu formularza UMP / promptu ATT i spozniony wynik formularza.

var _ads: Node
var _ad_provider: FakeAdProvider
var _fake_an: FakeAnalyticsProvider
var _prev_an: AnalyticsProvider
var _now: Array[float] = [0.0]
var _finished: int = 0
var _consent: FakeConsentProvider


func before_test() -> void:
	GameConfig.reset()
	_now[0] = 0.0
	_finished = 0
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_ad_provider = FakeAdProvider.new()
	_ads = auto_free(load("res://src/systems/ad_service.gd").new())
	_ads.provider = _ad_provider
	_ads.clock = TestClock.ticking_float(_now)
	_ads.consent_finished.connect(func(_r: Dictionary) -> void: _finished += 1)
	_consent = FakeConsentProvider.new()
	_consent.region_eea = true
	_consent.form_required = true
	_consent.hold_form = true


func after_test() -> void:
	_consent.pending_form_callback = Callable()
	_consent.pending_att_callback = Callable()
	Analytics.provider = _prev_an
	GameConfig.reset()


func _count(event_id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if e.get("event_id", "") == event_id:
			n += 1
	return n


func _tick(t: float) -> void:
	_now[0] = t
	_ads._process(0.0)


func test_form_without_answer_times_out_at_limit() -> void:
	_ads.begin_consent(_consent)
	_tick(119.0)
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.PENDING)
	_tick(120.0)
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.DONE)
	assert_bool(_ads.consent_result["timed_out"]).is_true()
	assert_bool(_ads.consent_result["personalized"]).is_false()
	assert_bool(_ads.consent_result["can_request_ads"]).is_true()
	assert_int(_count("consent:ump:form_timeout")).is_equal(1)
	_tick(500.0)
	assert_int(_count("consent:ump:form_timeout")).is_equal(1)
	assert_int(_finished).is_equal(1)


func test_answer_within_limit_is_normal() -> void:
	_ads.begin_consent(_consent)
	_tick(60.0)
	_consent.release_form("obtained")
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.DONE)
	assert_bool(_ads.consent_result["personalized"]).is_true()
	assert_bool(_ads.consent_result["timed_out"]).is_false()
	_tick(500.0)
	assert_int(_count("consent:ump:form_timeout")).is_equal(0)
	assert_int(_count("consent:ump:obtained")).is_equal(1)


func test_late_consent_is_applied_like_privacy_options() -> void:
	_ads.begin_consent(_consent)
	_tick(120.0)
	assert_int(_finished).is_equal(1)
	_consent.release_form("obtained")
	assert_bool(_ads.consent_result["personalized"]).is_true()
	assert_bool(_ad_provider.personalized).is_true()
	assert_int(_count("consent:ump:obtained")).is_equal(1)
	assert_int(_finished).is_equal(2)
	# A repeated callback does nothing.
	_consent.release_form("obtained")
	assert_int(_count("consent:ump:obtained")).is_equal(1)
	assert_int(_finished).is_equal(2)


func test_ios_att_prompt_times_out_and_late_answer_applies() -> void:
	_consent.hold_form = false
	_consent.ump_status = "obtained"
	_consent.att_supported = true
	_consent.att_status = "authorized"
	_consent.hold_att = true
	_ads.begin_consent(_consent)
	_tick(119.0)
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.PENDING)
	_tick(120.0)
	assert_int(_ads.consent_state).is_equal(_ads.ConsentState.DONE)
	assert_bool(_ads.consent_result["personalized"]).is_false()
	assert_int(_count("consent:att:form_timeout")).is_equal(1)
	assert_int(_finished).is_equal(1)
	_consent.release_att("authorized")
	assert_bool(_ads.consent_result["personalized"]).is_true()
	assert_int(_count("consent:att:authorized")).is_equal(1)
	assert_int(_finished).is_equal(2)
