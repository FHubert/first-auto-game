class_name ConsentProvider
extends RefCounted
## Consent SDK interface (UMP + ATT). Base methods are no-ops; real SDK in Phase 5.

const UMP_OBTAINED := "obtained"
const UMP_NOT_REQUIRED := "not_required"
const UMP_REQUIRED := "required"
const UMP_DENIED := "denied"
const UMP_UNKNOWN := "unknown"
const ATT_NOT_DETERMINED := "not_determined"
const ATT_AUTHORIZED := "authorized"
const ATT_DENIED := "denied"
const ATT_RESTRICTED := "restricted"


## on_done.call(ok: bool); getters are valid afterwards.
func request_consent_info_update(_on_done: Callable) -> void:
	pass


func is_form_required() -> bool:
	return false


## on_closed.call(status: String), status is one of the UMP_* constants.
func show_consent_form(_on_closed: Callable) -> void:
	pass


func get_ump_status() -> String:
	return UMP_UNKNOWN


func can_request_ads() -> bool:
	return false


func is_privacy_options_required() -> bool:
	return false


func show_privacy_options(_on_closed: Callable) -> void:
	pass


func is_att_supported() -> bool:
	return false


func get_att_status() -> String:
	return ATT_NOT_DETERMINED


## on_done.call(status: String), status is one of the ATT_* constants.
func request_att(_on_done: Callable) -> void:
	pass
