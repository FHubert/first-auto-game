class_name FakeAdProvider
extends AdProvider
## Deterministic provider for editor, headless runs and tests.

var always_ready: bool = true
var reward_on_show: bool = true
var initialize_calls: int = 0
var rewarded_shown: int = 0
var interstitials_shown: int = 0
var personalized: bool = true
var set_personalized_calls: int = 0
## Show without callback/closed signal until release() (simulates a lost SDK callback).
var hold_show: bool = false
## Show completes on a later frame (like the real SDK), unless hold_show is set.
var deferred: bool = false
var releases: int = 0
var _held_callback: Callable
var _held_kind: String = ""


func initialize() -> void:
	initialize_calls += 1


func is_rewarded_ready() -> bool:
	return always_ready


func show_rewarded(callback: Callable) -> void:
	rewarded_shown += 1
	if hold_show:
		_held_callback = callback
		_held_kind = "rewarded"
		return
	if deferred:
		_held_callback = callback
		_held_kind = "rewarded"
		release.call_deferred(reward_on_show)
		return
	if callback.is_valid():
		callback.call(reward_on_show)
	rewarded_closed.emit(reward_on_show)


func is_interstitial_ready() -> bool:
	return always_ready


func show_interstitial() -> void:
	interstitials_shown += 1
	if hold_show:
		_held_kind = "interstitial"
		return
	if deferred:
		_held_kind = "interstitial"
		release.call_deferred(reward_on_show)
		return
	interstitial_closed.emit()


func release(granted: bool) -> void:
	releases += 1
	var kind: String = _held_kind
	var cb: Callable = _held_callback
	_held_kind = ""
	_held_callback = Callable()
	if kind == "rewarded":
		if cb.is_valid():
			cb.call(granted)
		rewarded_closed.emit(granted)
	elif kind == "interstitial":
		interstitial_closed.emit()


func set_personalized(enabled: bool) -> void:
	personalized = enabled
	set_personalized_calls += 1
