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


func initialize() -> void:
	initialize_calls += 1


func is_rewarded_ready() -> bool:
	return always_ready


func show_rewarded(callback: Callable) -> void:
	rewarded_shown += 1
	if callback.is_valid():
		callback.call(reward_on_show)
	rewarded_closed.emit(reward_on_show)


func is_interstitial_ready() -> bool:
	return always_ready


func show_interstitial() -> void:
	interstitials_shown += 1
	interstitial_closed.emit()


func set_personalized(enabled: bool) -> void:
	personalized = enabled
	set_personalized_calls += 1
