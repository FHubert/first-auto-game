class_name FakeNotificationProvider
extends NotificationProvider
## Test double recording scheduled notifications.

var scheduled: Array[Dictionary] = []
var cancel_calls: int = 0
## Scripted permission status; request_permission() moves it to permission_answer.
var permission: String = PERMISSION_NOT_REQUIRED
var permission_answer: String = PERMISSION_GRANTED
var permission_requests: int = 0
## hold_permission: the callback waits for release_permission(status).
var hold_permission: bool = false
var _held: Callable = Callable()


func is_available() -> bool:
	return true


func schedule(id: int, fire_unix: int, title: String, body: String) -> void:
	scheduled.append({"id": id, "fire_unix": fire_unix, "title": title, "body": body})


func cancel_all() -> void:
	scheduled.clear()
	cancel_calls += 1


func permission_status() -> String:
	return permission


func request_permission(callback: Callable) -> void:
	permission_requests += 1
	if hold_permission:
		_held = callback
		return
	permission = permission_answer
	callback.call(permission)


## Test hook: answers a held request.
func release_permission(status: String) -> void:
	permission = status
	if _held.is_valid():
		var cb: Callable = _held
		_held = Callable()
		cb.call(status)
