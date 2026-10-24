class_name NotificationProvider
extends RefCounted
## Local notification interface. Base methods are no-ops; real plugin in Phase 5 (ADR-012).


func is_available() -> bool:
	return false


## Schedules one notification at fire_unix (UTC seconds); id is stable per kind.
func schedule(_id: int, _fire_unix: int, _title: String, _body: String) -> void:
	pass


## Cancels every pending notification scheduled by the app.
func cancel_all() -> void:
	pass
