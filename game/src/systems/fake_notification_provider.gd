class_name FakeNotificationProvider
extends NotificationProvider
## Test double recording scheduled notifications.

var scheduled: Array[Dictionary] = []
var cancel_calls: int = 0


func is_available() -> bool:
	return true


func schedule(id: int, fire_unix: int, title: String, body: String) -> void:
	scheduled.append({"id": id, "fire_unix": fire_unix, "title": title, "body": body})


func cancel_all() -> void:
	scheduled.clear()
	cancel_calls += 1
