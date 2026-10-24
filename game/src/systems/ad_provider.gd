class_name AdProvider
extends RefCounted
## Base ad interface. Real SDK wrappers (AdMob) extend this.

## Emitted when a rewarded ad closes; granted tells if the reward was earned.
signal rewarded_closed(granted: bool)
signal interstitial_closed


func initialize() -> void:
	pass


func is_rewarded_ready() -> bool:
	return false


## callback is called as callback.call(granted: bool) when the ad closes.
func show_rewarded(_callback: Callable) -> void:
	pass


func is_interstitial_ready() -> bool:
	return false


func show_interstitial() -> void:
	pass


## Consent result: false = non-personalized ads (AdMob "npa"). Real SDK sets it in Phase 5.
func set_personalized(_enabled: bool) -> void:
	pass
