extends GdUnitTestSuite

var _fake: FakeAnalyticsProvider
var _prev_analytics: AnalyticsProvider
var _provider: FakeConsentProvider
var _flow: ConsentFlow
var _now: Array[float] = [0.0]
var _finished_count: int = 0


func before_test() -> void:
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	GameConfig.reset()
	_provider = FakeConsentProvider.new()
	_flow = ConsentFlow.new(_provider)
	_now[0] = 100.0
	_finished_count = 0
	_flow.clock = TestClock.ticking_float(_now)
	_flow.finished.connect(func(_r: Dictionary) -> void: _finished_count += 1)


func after_test() -> void:
	# Break flow <-> provider reference cycles (held callbacks) so RefCounted objects are freed.
	_provider.pending_info_callback = Callable()
	_provider.pending_form_callback = Callable()
	_flow.provider = null
	Analytics.provider = _prev_analytics
	GameConfig.reset()


func _count(prefix: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake.events:
		if e["type"] == "design" and str(e["event_id"]).begins_with(prefix):
			n += 1
	return n


func _has(event_id: String) -> bool:
	for e: Dictionary in _fake.events:
		if e.get("event_id", "") == event_id:
			return true
	return false


func _eea(status: String) -> void:
	_provider.region_eea = true
	_provider.form_required = true
	_provider.ump_status = status


func test_eea_consent_obtained() -> void:
	_eea("obtained")
	_flow.start()
	assert_bool(_flow.is_finished).is_true()
	assert_bool(_flow.result["personalized"]).is_true()
	assert_bool(_flow.result["can_request_ads"]).is_true()
	assert_int(_provider.form_shown).is_equal(1)
	assert_int(_finished_count).is_equal(1)
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_int(_count("consent:att:")).is_equal(0)


func test_eea_consent_denied() -> void:
	_eea("denied")
	_flow.start()
	assert_bool(_flow.result["can_request_ads"]).is_true()
	assert_bool(_flow.result["personalized"]).is_false()
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_int(_count("consent:att:")).is_equal(0)


func test_outside_eea_no_form() -> void:
	_provider.form_required = true
	_flow.start()
	assert_int(_provider.form_shown).is_equal(0)
	assert_str(_flow.result["ump_status"]).is_equal("not_required")
	assert_bool(_flow.result["personalized"]).is_true()
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_int(_count("consent:att:")).is_equal(0)


func test_timeout_finishes_unpersonalized() -> void:
	_provider.respond = false
	_flow.start()
	_now[0] = 107.9
	_flow.poll()
	assert_bool(_flow.is_finished).is_false()
	_now[0] = 108.0
	_flow.poll()
	assert_bool(_flow.is_finished).is_true()
	assert_bool(_flow.result["timed_out"]).is_true()
	assert_bool(_flow.result["personalized"]).is_false()
	assert_bool(_flow.result["can_request_ads"]).is_true()
	_now[0] = 200.0
	_flow.poll()
	assert_int(_finished_count).is_equal(1)
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_bool(_has("consent:ump:timeout")).is_true()


func test_ios_att_denied() -> void:
	_eea("obtained")
	_provider.att_supported = true
	_provider.att_status = "denied"
	_flow.start()
	assert_bool(_flow.result["personalized"]).is_false()
	assert_int(_provider.att_requests).is_equal(1)
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_int(_count("consent:att:")).is_equal(1)


func test_ios_att_authorized() -> void:
	_eea("obtained")
	_provider.att_supported = true
	_provider.att_status = "authorized"
	_flow.start()
	assert_bool(_flow.result["personalized"]).is_true()
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_int(_count("consent:att:")).is_equal(1)


func test_ios_ump_denied_skips_att() -> void:
	_eea("denied")
	_provider.att_supported = true
	_flow.start()
	assert_int(_provider.att_requests).is_equal(0)
	assert_bool(_has("consent:att:skipped")).is_true()
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_int(_count("consent:att:")).is_equal(1)


func test_timeout_ios_reports_both_once() -> void:
	_provider.respond = false
	_provider.att_supported = true
	_flow.start()
	_now[0] = 120.0
	_flow.poll()
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_int(_count("consent:att:")).is_equal(1)


func test_timeout_config_default() -> void:
	assert_int(int(GameConfig.get_value("consent_timeout_seconds"))).is_equal(8)


func test_user_reading_form_is_not_timeout() -> void:
	_eea("obtained")
	_provider.hold_form = true
	_flow.start()
	_now[0] = 200.0
	_flow.poll()
	assert_bool(_flow.is_finished).is_false()
	_provider.pending_form_callback.call("obtained")
	assert_bool(_flow.is_finished).is_true()
	assert_bool(_flow.result["personalized"]).is_true()
	assert_bool(_flow.result["timed_out"]).is_false()
	assert_bool(_has("consent:ump:timeout")).is_false()
	assert_int(_count("consent:ump:")).is_equal(1)


func test_late_callback_after_timeout_ignored() -> void:
	_eea("obtained")
	_provider.respond = false
	_flow.start()
	_now[0] = 120.0
	_flow.poll()
	_flow.poll()
	var before: Dictionary = _flow.result.duplicate()
	_provider.pending_info_callback.call(true)
	assert_dict(_flow.result).is_equal(before)
	assert_int(_finished_count).is_equal(1)
	assert_int(_provider.form_shown).is_equal(0)
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_bool(_has("consent:ump:timeout")).is_true()


func _assert_error_result() -> void:
	assert_int(_finished_count).is_equal(1)
	assert_bool(_flow.result["can_request_ads"]).is_true()
	assert_bool(_flow.result["personalized"]).is_false()
	assert_bool(_flow.result["timed_out"]).is_false()
	assert_str(_flow.result["ump_status"]).is_equal("error")
	assert_int(_provider.form_shown).is_equal(0)
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_bool(_has("consent:ump:error")).is_true()


func test_info_update_error_eea() -> void:
	_eea("obtained")
	_provider.info_update_ok = false
	_flow.start()
	_assert_error_result()
	assert_int(_count("consent:att:")).is_equal(0)


func test_info_update_error_outside_eea() -> void:
	_provider.info_update_ok = false
	_flow.start()
	_assert_error_result()
	assert_int(_count("consent:att:")).is_equal(0)


func test_info_update_error_ios_reports_att_skipped() -> void:
	_provider.att_supported = true
	_provider.info_update_ok = false
	_flow.start()
	_assert_error_result()
	assert_int(_provider.att_requests).is_equal(0)
	assert_int(_count("consent:att:")).is_equal(1)
	assert_bool(_has("consent:att:skipped")).is_true()
	assert_str(_flow.result["att_status"]).is_equal("skipped")


func test_info_update_error_then_poll_no_timeout() -> void:
	_provider.info_update_ok = false
	_flow.start()
	_now[0] = 200.0
	_flow.poll()
	assert_int(_count("consent:ump:")).is_equal(1)
	assert_bool(_has("consent:ump:timeout")).is_false()
	assert_int(_finished_count).is_equal(1)
