extends Node
## Autoload "Ads": owns the provider and enforces interstitial caps from GameConfig.

signal interstitial_shown(round_index: int)
signal rewarded_granted(placement_id: String)

var provider: AdProvider
## Seconds source; tests and the playtest bot replace it to simulate time.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var interstitials_shown: int = 0

var _last_interstitial_s: float = -INF
var _rewarded_in_break: bool = false


func _ready() -> void:
	if provider == null:
		provider = _make_default_provider()
	provider.initialize()


## True when an interstitial was shown. Needs: ads not removed, level >= min level,
## level hits the every-N cap, min-seconds gap, no rewarded ad in this break, ad ready.
func maybe_show_interstitial(level_no: int, ads_removed: bool = false) -> bool:
	var every_n: int = int(GameConfig.get_value("interstitial_every_n_rounds", 5))
	var min_seconds: float = float(GameConfig.get_value("interstitial_min_seconds", 120))
	var min_level: int = int(GameConfig.get_value("interstitial_min_level", 8))
	# Every call marks the end of a break, so the flag is always consumed.
	var rewarded_in_break: bool = _rewarded_in_break
	_rewarded_in_break = false
	if provider == null or ads_removed or level_no < min_level:
		return false
	if every_n <= 0 or level_no <= 0 or level_no % every_n != 0:
		return false
	var now: float = clock.call()
	if now - _last_interstitial_s < min_seconds:
		return false
	if rewarded_in_break:
		return false
	if not provider.is_interstitial_ready():
		return false
	provider.show_interstitial()
	_last_interstitial_s = now
	interstitials_shown += 1
	Analytics.track_design("ads:interstitial:shown", float(level_no))
	interstitial_shown.emit(level_no)
	return true


## Clears the "rewarded already shown in this break" flag (tests / bot).
func reset_break() -> void:
	_rewarded_in_break = false


func is_rewarded_ready() -> bool:
	return provider != null and provider.is_rewarded_ready()


## Shows a rewarded ad; on_reward is called (no args) only if the reward was earned.
func request_rewarded(placement_id: String, on_reward: Callable) -> bool:
	if provider == null or not provider.is_rewarded_ready():
		Analytics.track_design("ads:rewarded:%s:unavailable" % placement_id)
		return false
	_rewarded_in_break = true
	provider.show_rewarded(
		func(granted: bool) -> void:
			if granted:
				Analytics.track_design("ads:rewarded:%s:granted" % placement_id)
				rewarded_granted.emit(placement_id)
				on_reward.call()
			else:
				Analytics.track_design("ads:rewarded:%s:skipped" % placement_id)
	)
	return true


## Consent outcome (kind: ump|att); called by the SDK layer from Phase 5.
func report_consent(kind: String, status: String) -> void:
	Analytics.track_design("consent:%s:%s" % [kind, status])


func _make_default_provider() -> AdProvider:
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if OS.has_feature("editor") or "--no-ads" in args or DisplayServer.get_name() == "headless":
		return FakeAdProvider.new()
	# TODO: real AdMob provider; until then fall back to the fake one.
	return FakeAdProvider.new()
