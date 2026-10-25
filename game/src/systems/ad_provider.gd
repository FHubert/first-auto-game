class_name AdProvider
extends RefCounted
## Base ad interface. Real SDK wrappers (AdMob) extend this.

## Emitted when a rewarded ad closes; granted tells if the reward was earned.
signal rewarded_closed(granted: bool)
## ad_id is the break number AdService passed to show_interstitial; the adapter echoes it back.
signal interstitial_closed(ad_id: int)
## Load results (T-225, ADR-013); code is the SDK error code. Retry policy lives in AdService.
signal rewarded_loaded
signal rewarded_load_failed(code: int)
signal interstitial_loaded
signal interstitial_load_failed(code: int)


func initialize() -> void:
	pass


## Starts loading a rewarded ad; result arrives as rewarded_loaded / rewarded_load_failed.
func load_rewarded() -> void:
	pass


## Starts loading an interstitial; result arrives as interstitial_loaded / ..._load_failed.
func load_interstitial() -> void:
	pass


func is_rewarded_ready() -> bool:
	return false


## callback is called as callback.call(granted: bool) when the ad closes.
func show_rewarded(_callback: Callable) -> void:
	pass


func is_interstitial_ready() -> bool:
	return false


## ad_id: break number assigned by AdService; send it back in interstitial_closed(ad_id).
func show_interstitial(_ad_id: int) -> void:
	pass


## Consent result: false = non-personalized ads (AdMob "npa"). Real SDK sets it in Phase 5.
func set_personalized(_enabled: bool) -> void:
	pass
