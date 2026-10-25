class_name FakeConsentProvider
extends ConsentProvider
## Scripted consent provider for tests and headless runs. Callbacks fire synchronously.

var region_eea: bool = false
var form_required: bool = false
## Status after the form (before the form: "required" when a form is pending).
var ump_status: String = UMP_NOT_REQUIRED
var att_supported: bool = false
## Result of request_att.
var att_status: String = ATT_NOT_DETERMINED
var privacy_options_required: bool = false
## When false the SDK "hangs": no callback is ever called.
var respond: bool = true
## When true the form stays open: its callback is stored, not called.
var hold_form: bool = false
## When false request_consent_info_update reports a failure (ok=false).
var info_update_ok: bool = true
## When true the ATT prompt stays open: its callback is stored, not called.
var hold_att: bool = false
var pending_form_callback: Callable
var pending_att_callback: Callable
var pending_info_callback: Callable
var info_update_calls: int = 0
var form_shown: int = 0
var att_requests: int = 0
var privacy_options_shown: int = 0
## UMP status after the privacy options form closes ("" = unchanged).
var privacy_options_status: String = ""

var _current_ump: String = UMP_UNKNOWN
var _att_current: String = ATT_NOT_DETERMINED


func request_consent_info_update(on_done: Callable) -> void:
	info_update_calls += 1
	if not respond:
		pending_info_callback = on_done
		return
	if not info_update_ok:
		_current_ump = UMP_UNKNOWN
		on_done.call(false)
		return
	if region_eea and form_required:
		_current_ump = UMP_REQUIRED
	else:
		_current_ump = UMP_NOT_REQUIRED
	on_done.call(true)


func is_form_required() -> bool:
	return region_eea and form_required and _current_ump == UMP_REQUIRED


func show_consent_form(on_closed: Callable) -> void:
	form_shown += 1
	if hold_form:
		pending_form_callback = func(status: String) -> void:
			_current_ump = status
			on_closed.call(status)
		return
	if not respond:
		return
	_current_ump = ump_status
	on_closed.call(_current_ump)


func get_ump_status() -> String:
	return _current_ump


func can_request_ads() -> bool:
	return _current_ump in [UMP_OBTAINED, UMP_NOT_REQUIRED, UMP_DENIED]


func is_privacy_options_required() -> bool:
	return privacy_options_required


func show_privacy_options(on_closed: Callable) -> void:
	privacy_options_shown += 1
	if privacy_options_status != "":
		_current_ump = privacy_options_status
	if respond:
		on_closed.call(_current_ump)


func is_att_supported() -> bool:
	return att_supported


func get_att_status() -> String:
	return _att_current


func request_att(on_done: Callable) -> void:
	att_requests += 1
	if hold_att:
		pending_att_callback = func(status: String) -> void:
			_att_current = status
			on_done.call(status)
		return
	if not respond:
		return
	_att_current = att_status
	on_done.call(_att_current)


## Test hook: answers a held UMP form (hold_form mode).
func release_form(status: String) -> void:
	pending_form_callback.call(status)


## Test hook: answers a held ATT prompt (hold_att mode).
func release_att(status: String) -> void:
	pending_att_callback.call(status)
