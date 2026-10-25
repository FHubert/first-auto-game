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
## Loading (T-225): a loaded ad is ready until shown; default load succeeds at once.
var rewarded_load_calls: int = 0
var interstitial_load_calls: int = 0
## While true, load_* waits for release_load(ok) instead of finishing at once.
var hold_loads: bool = false
var pending_loads: Array[String] = []
var _fail_loads_left: int = 0
var _fail_code: int = 0
var _rewarded_loaded: bool = true
var _interstitial_loaded: bool = true


func initialize() -> void:
	initialize_calls += 1


## The next n loads (any format) fail with code instead of succeeding.
func fail_next_loads(n: int, code: int = 3) -> void:
	_fail_loads_left = n
	_fail_code = code


func load_rewarded() -> void:
	rewarded_load_calls += 1
	_finish_or_hold("rewarded")


func load_interstitial() -> void:
	interstitial_load_calls += 1
	_finish_or_hold("interstitial")


## Completes the oldest held load: ok = loaded, otherwise failed with the fail code.
func release_load(ok: bool) -> void:
	if pending_loads.is_empty():
		return
	_complete_load(pending_loads.pop_front(), ok)


func _finish_or_hold(kind: String) -> void:
	if hold_loads:
		pending_loads.append(kind)
		return
	var ok: bool = _fail_loads_left <= 0
	if not ok:
		_fail_loads_left -= 1
	_complete_load(kind, ok)


func _complete_load(kind: String, ok: bool) -> void:
	if kind == "rewarded":
		_rewarded_loaded = ok
		if ok:
			rewarded_loaded.emit()
		else:
			rewarded_load_failed.emit(_fail_code)
	else:
		_interstitial_loaded = ok
		if ok:
			interstitial_loaded.emit()
		else:
			interstitial_load_failed.emit(_fail_code)


func is_rewarded_ready() -> bool:
	return always_ready and _rewarded_loaded


func show_rewarded(callback: Callable) -> void:
	rewarded_shown += 1
	_rewarded_loaded = false
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
	return always_ready and _interstitial_loaded


func show_interstitial() -> void:
	interstitials_shown += 1
	_interstitial_loaded = false
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
