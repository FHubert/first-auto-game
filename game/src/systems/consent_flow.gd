class_name ConsentFlow
extends RefCounted
## Boot consent sequence: UMP first, then ATT on iOS. Pure logic: the clock is injected
## and the timeout is checked via poll() (no Node, no timers, no await).
## A failed consent info update ends the flow unpersonalized (UMP_ERROR), without a form.

signal finished(result: Dictionary)
## A form/prompt answered after form_timeout ended the flow: kind is "ump" or "att".
signal late_result(kind: String, status: String)

const ATT_SKIPPED := "skipped"
const UMP_TIMEOUT := "timeout"
const UMP_ERROR := "error"
const FORM_TIMEOUT := "form_timeout"

var provider: ConsentProvider
var ads: Node
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var result: Dictionary = {}
var is_finished: bool = false

var _started_at: float = 0.0
var _ump_reported: bool = false
var _att_reported: bool = false
var _awaiting_user: bool = false
var _form_kind: String = ""
var _form_opened_at: float = 0.0
var _late_kind: String = ""
var _ump_final: String = ""


func _init(p_provider: ConsentProvider = null) -> void:
	provider = p_provider


func start() -> void:
	_started_at = clock.call()
	provider.request_consent_info_update(_on_info_updated)


## Call every frame from Boot; finishes the flow once the timeout elapsed.
func poll() -> void:
	if is_finished:
		return
	if _awaiting_user:
		# The SDK timeout does not cover a form/dialog; it has its own limit from opening.
		var form_limit: float = float(GameConfig.get_value("consent_form_timeout_seconds"))
		if clock.call() - _form_opened_at >= form_limit:
			_form_timed_out()
		return
	var timeout: float = float(GameConfig.get_value("consent_timeout_seconds"))
	if clock.call() - _started_at < timeout:
		return
	_report("ump", UMP_TIMEOUT)
	if provider.is_att_supported():
		_report("att", ATT_SKIPPED)
	_finish(UMP_TIMEOUT, "", true)


func _form_timed_out() -> void:
	_late_kind = _form_kind
	_report(_form_kind, FORM_TIMEOUT)
	if _form_kind == "ump":
		var att: String = ""
		if provider.is_att_supported():
			att = ATT_SKIPPED
			_report("att", att)
		_finish(FORM_TIMEOUT, att, true)
	else:
		_finish(_ump_final, FORM_TIMEOUT, true)


func _open_form(kind: String) -> void:
	_awaiting_user = true
	_form_kind = kind
	_form_opened_at = clock.call()


func _on_info_updated(ok: bool) -> void:
	if is_finished:
		return
	if not ok:
		_report("ump", UMP_ERROR)
		var att: String = ""
		if provider.is_att_supported():
			att = ATT_SKIPPED
			_report("att", att)
		_finish(UMP_ERROR, att, false)
	elif provider.is_form_required():
		_open_form("ump")
		provider.show_consent_form(_after_ump)
	else:
		_after_ump(provider.get_ump_status())


func _after_ump(status: String) -> void:
	if is_finished:
		_emit_late("ump", status)
		return
	_ump_final = status
	_report("ump", status)
	if not provider.is_att_supported():
		_finish(status, "", false)
	elif status == ConsentProvider.UMP_DENIED:
		_report("att", ATT_SKIPPED)
		_finish(status, ATT_SKIPPED, false)
	elif provider.get_att_status() == ConsentProvider.ATT_NOT_DETERMINED:
		_open_form("att")
		provider.request_att(
			func(att: String) -> void:
				if is_finished:
					_emit_late("att", att)
					return
				_report("att", att)
				_finish(status, att, false)
		)
	else:
		var att_now: String = provider.get_att_status()
		_report("att", att_now)
		_finish(status, att_now, false)


func _emit_late(kind: String, status: String) -> void:
	if _late_kind != kind:
		return
	_late_kind = ""
	late_result.emit(kind, status)


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
		"can_request_ads": timed_out or ump == UMP_ERROR or provider.can_request_ads(),
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
