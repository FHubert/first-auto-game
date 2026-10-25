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
## FIFO of held shows: {"kind": String, "cb": Callable}; release() frees the oldest.
var held: Array[Dictionary] = []


func initialize() -> void:
	initialize_calls += 1


func is_rewarded_ready() -> bool:
	return always_ready


func show_rewarded(callback: Callable) -> void:
	rewarded_shown += 1
	if hold_show:
		held.append({"kind": "rewarded", "cb": callback})
		return
	if deferred:
		held.append({"kind": "rewarded", "cb": callback})
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
		held.append({"kind": "interstitial", "cb": Callable()})
		return
	if deferred:
		held.append({"kind": "interstitial", "cb": Callable()})
		release.call_deferred(reward_on_show)
		return
	interstitial_closed.emit()


func release(granted: bool) -> void:
	release_at(0, granted)


## Completes the held show at queue index i (0 = oldest); out of range = nothing to release.
func release_at(i: int, granted: bool) -> void:
	releases += 1
	if i < 0 or i >= held.size():
		return
	var entry: Dictionary = held[i]
	held.remove_at(i)
	if entry["kind"] == "rewarded":
		var cb: Callable = entry["cb"]
		if cb.is_valid():
			cb.call(granted)
		rewarded_closed.emit(granted)
	else:
		interstitial_closed.emit()


func set_personalized(enabled: bool) -> void:
	personalized = enabled
	set_personalized_calls += 1
