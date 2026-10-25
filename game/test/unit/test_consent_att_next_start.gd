extends GdUnitTestSuite
## T-219: po consent:att:skipped (timeout formularza UMP) ATT pytane dopiero przy nastepnym starcie.

var _fake_an: FakeAnalyticsProvider
var _prev_an: AnalyticsProvider
var _now: Array[float] = [0.0]
var _provider: FakeConsentProvider
var _flow: ConsentFlow


func before_test() -> void:
	GameConfig.reset()
	_now[0] = 100.0
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_provider = FakeConsentProvider.new()
	_provider.att_supported = true
	_provider.region_eea = true
	_provider.form_required = true
	_provider.hold_form = true


func after_test() -> void:
	_provider.pending_form_callback = Callable()
	_provider.pending_att_callback = Callable()
	if _flow != null:
		_flow.provider = null
	Analytics.provider = _prev_an
	GameConfig.reset()


func _count(event_id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if e.get("event_id", "") == event_id:
			n += 1
	return n


func _new_flow() -> ConsentFlow:
	_flow = ConsentFlow.new(_provider)
	_flow.clock = TestClock.ticking_float(_now)
	return _flow


## Session 1: the UMP form is held until consent_form_timeout_seconds.
func _session_one_timeout() -> void:
	var flow: ConsentFlow = _new_flow()
	flow.start()
	_now[0] = 100.0 + float(GameConfig.get_value("consent_form_timeout_seconds"))
	flow.poll()
	assert_bool(flow.is_finished).is_true()
	assert_int(_count("consent:att:skipped")).is_equal(1)
	assert_int(_provider.att_requests).is_equal(0)
	_provider.pending_form_callback = Callable()
	flow.provider = null


## Session 2 = new ConsentFlow, same provider (ATT status persists in the OS).
func _session_two() -> void:
	_provider.hold_form = false
	_provider.form_required = false
	_provider.ump_status = ConsentProvider.UMP_NOT_REQUIRED
	_now[0] = 1000.0
	var flow: ConsentFlow = _new_flow()
	flow.start()


func test_att_skipped_in_session_one_is_asked_in_session_two() -> void:
	_session_one_timeout()
	_provider.att_status = ConsentProvider.ATT_AUTHORIZED
	_session_two()
	assert_int(_provider.att_requests).is_equal(1)
	assert_int(_count("consent:att:authorized")).is_equal(1)
	assert_bool(_flow.is_finished).is_true()


func test_att_denied_in_session_one_is_not_asked_again() -> void:
	_provider.hold_form = false
	_provider.form_required = false
	_provider.att_status = ConsentProvider.ATT_DENIED
	var flow: ConsentFlow = _new_flow()
	flow.start()
	assert_int(_provider.att_requests).is_equal(1)
	assert_int(_count("consent:att:denied")).is_equal(1)
	flow.provider = null
	_session_two()
	assert_int(_provider.att_requests).is_equal(1)
	assert_int(_count("consent:att:denied")).is_equal(2)
