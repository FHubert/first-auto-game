class_name ConsentFlow
extends RefCounted
## Boot consent sequence: UMP first, then ATT on iOS. Pure logic: the clock is injected
## and the timeout is checked via poll() (no Node, no timers, no await).

signal finished(result: Dictionary)

const ATT_SKIPPED := "skipped"
const UMP_TIMEOUT := "timeout"

var provider: ConsentProvider
var ads: Node
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var result: Dictionary = {}
var is_finished: bool = false

var _started_at: float = 0.0
var _ump_reported: bool = false
var _att_reported: bool = false
var _awaiting_user: bool = false


func _init(p_provider: ConsentProvider = null) -> void:
	provider = p_provider


func start() -> void:
	_started_at = clock.call()
	provider.request_consent_info_update(_on_info_updated)


## Call every frame from Boot; finishes the flow once the timeout elapsed.
func poll() -> void:
	# Timeout only covers waiting for the SDK, not the user reading a form/dialog.
	if is_finished or _awaiting_user:
		return
	var timeout: float = float(GameConfig.get_value("consent_timeout_seconds"))
	if clock.call() - _started_at < timeout:
		return
	_report("ump", UMP_TIMEOUT)
	if provider.is_att_supported():
		_report("att", ATT_SKIPPED)
	_finish(UMP_TIMEOUT, "", true)


func _on_info_updated(ok: bool) -> void:
	if is_finished:
		return
	if ok and provider.is_form_required():
		_awaiting_user = true
		provider.show_consent_form(_after_ump)
	else:
		_after_ump(provider.get_ump_status())


func _after_ump(status: String) -> void:
	if is_finished:
		return
	_report("ump", status)
	if not provider.is_att_supported():
		_finish(status, "", false)
	elif status == ConsentProvider.UMP_DENIED:
		_report("att", ATT_SKIPPED)
		_finish(status, ATT_SKIPPED, false)
	elif provider.get_att_status() == ConsentProvider.ATT_NOT_DETERMINED:
		_awaiting_user = true
		provider.request_att(
			func(att: String) -> void:
				if is_finished:
					return
				_report("att", att)
				_finish(status, att, false)
		)
	else:
		var att_now: String = provider.get_att_status()
		_report("att", att_now)
		_finish(status, att_now, false)


func _report(kind: String, status: String) -> void:
	if kind == "ump":
		if _ump_reported:
			return
		_ump_reported = true
	else:
		if _att_reported:
			return
		_att_reported = true
	var service: Node = ads if ads != null else Ads
	service.report_consent(kind, status)


func _finish(ump: String, att: String, timed_out: bool) -> void:
	var att_ok: bool = att == "" or att == ConsentProvider.ATT_AUTHORIZED
	result = {
		"can_request_ads": timed_out or provider.can_request_ads(),
		"personalized":
		not timed_out and ump != ConsentProvider.UMP_DENIED and att_ok and _ump_ok(ump),
		"ump_status": ump,
		"att_status": att,
		"timed_out": timed_out,
		"privacy_options_required": provider.is_privacy_options_required(),
	}
	is_finished = true
	finished.emit(result)


func _ump_ok(ump: String) -> bool:
	return ump in [ConsentProvider.UMP_OBTAINED, ConsentProvider.UMP_NOT_REQUIRED]
