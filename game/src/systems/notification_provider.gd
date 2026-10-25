class_name NotificationProvider
extends RefCounted
## Local notification interface. Base methods are no-ops; real plugin in Phase 5 (ADR-012).

const PERMISSION_GRANTED: String = "granted"
const PERMISSION_DENIED: String = "denied"
const PERMISSION_NOT_DETERMINED: String = "not_determined"
const PERMISSION_NOT_REQUIRED: String = "not_required"


func is_available() -> bool:
	return false


## Schedules one notification at fire_unix (UTC seconds); id is stable per kind.
func schedule(_id: int, _fire_unix: int, _title: String, _body: String) -> void:
	pass


## Cancels every pending notification scheduled by the app.
func cancel_all() -> void:
	pass


## System permission status (Android 13+ POST_NOTIFICATIONS, iOS). The base needs no
## permission, so it reports NOT_REQUIRED (the app then schedules as before).
func permission_status() -> String:
	return PERMISSION_NOT_REQUIRED


## Asks the OS for permission; callback(status: String) gets PERMISSION_GRANTED or
## PERMISSION_DENIED asynchronously. The base has nothing to ask, so it answers
## PERMISSION_NOT_REQUIRED at once, consistent with permission_status().
func request_permission(callback: Callable) -> void:
	callback.call(PERMISSION_NOT_REQUIRED)
