extends Node
## Autoload "Ads": owns the provider and enforces interstitial caps from GameConfig.

signal interstitial_shown(round_index: int)
signal rewarded_granted(placement_id: String)

var provider: AdProvider
## Seconds source; tests and the playtest bot replace it to simulate time.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var interstitials_shown: int = 0

var _last_interstitial_s: float = -INF


func _ready() -> void:
	if provider == null:
		provider = _make_default_provider()
	provider.initialize()


## True when round_index hits the every-N cap and min-seconds gap, and an ad is ready.
func maybe_show_interstitial(round_index: int) -> bool:
	var every_n: int = int(GameConfig.get_value("interstitial_every_n_rounds", 3))
	var min_seconds: float = float(GameConfig.get_value("interstitial_min_seconds", 90))
	if provider == null or every_n <= 0 or round_index <= 0 or round_index % every_n != 0:
		return false
	var now: float = clock.call()
	if now - _last_interstitial_s < min_seconds:
		return false
	if not provider.is_interstitial_ready():
		return false
	provider.show_interstitial()
	_last_interstitial_s = now
	interstitials_shown += 1
	Analytics.track_design("ads:interstitial:shown", float(round_index))
	interstitial_shown.emit(round_index)
	return true


func is_rewarded_ready() -> bool:
	return provider != null and provider.is_rewarded_ready()


## Shows a rewarded ad; on_reward is called (no args) only if the reward was earned.
func request_rewarded(placement_id: String, on_reward: Callable) -> bool:
	if provider == null or not provider.is_rewarded_ready():
		Analytics.track_design("ads:rewarded:%s:unavailable" % placement_id)
		return false
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


func _make_default_provider() -> AdProvider:
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if OS.has_feature("editor") or "--no-ads" in args or DisplayServer.get_name() == "headless":
		return FakeAdProvider.new()
	# TODO: real AdMob provider; until then fall back to the fake one.
	return FakeAdProvider.new()
