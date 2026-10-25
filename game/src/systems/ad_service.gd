extends Node
## Autoload "Ads": owns the provider and enforces interstitial caps from GameConfig.

signal ad_about_to_show(kind: String)
signal interstitial_shown(round_index: int)
signal rewarded_granted(placement_id: String)
signal consent_finished(result: Dictionary)

## The ad gate is active only from begin_consent() until ConsentFlow.finished;
## tests and the headless bot that never start the flow (NOT_STARTED) are not gated.
enum ConsentState { NOT_STARTED, PENDING, DONE }

var provider: AdProvider
## Seconds source; tests and the playtest bot replace it to simulate time.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var interstitials_shown: int = 0
var consent_state: int = ConsentState.NOT_STARTED
var consent_provider: ConsentProvider
var consent_result: Dictionary = {}
var _consent_flow: ConsentFlow

var _last_interstitial_s: float = -INF
var _rewarded_in_break: bool = false
var _muted_at_s: float = -INF
var _ad_break_open: bool = false
var _watchdog_fired: bool = false
var _break_id: int = 0
## Breaks closed by the watchdog whose SDK callback has not arrived yet (id -> true).
var _watchdog_ids: Dictionary = {}
var _interstitial_ids: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if provider == null:
		provider = _make_default_provider()
	provider.initialize()


func _process(_delta: float) -> void:
	if consent_state == ConsentState.PENDING and _consent_flow != null:
		_consent_flow.poll()
	poll_watchdog()


## Unmutes audio when an ad break outlives ad_unmute_timeout_seconds (lost SDK callback).
func poll_watchdog() -> void:
	if not _ad_break_open or _watchdog_fired:
		return
	var limit: float = float(GameConfig.get_value("ad_unmute_timeout_seconds"))
	if float(clock.call()) - _muted_at_s >= limit:
		_watchdog_fired = true
		_ad_break_open = false
		_watchdog_ids[_break_id] = true
		Audio.set_app_muted(false)
		Analytics.track_design("ads:watchdog:unmute")


func _begin_ad_break() -> int:
	_break_id += 1
	Audio.set_app_muted(true)
	_muted_at_s = clock.call()
	_ad_break_open = true
	_watchdog_fired = false
	return _break_id


## Ends break id only if it is the open one. A late callback (watchdog already closed it)
## is reported once and returns true; it never touches the audio of the current break.
func _close_break(id: int, kind: String) -> bool:
	if _watchdog_ids.has(id):
		_watchdog_ids.erase(id)
		Analytics.track_design("ads:watchdog:late:%s" % kind)
		return true
	if _ad_break_open and id == _break_id:
		_end_ad_break()
		return true
	return false


func _end_ad_break() -> void:
	_ad_break_open = false
	Audio.set_app_muted(false)


## Starts the UMP/ATT flow once; ads stay gated until it finishes.
func begin_consent(p_provider: ConsentProvider = null) -> void:
	if consent_state != ConsentState.NOT_STARTED:
		return
	consent_provider = p_provider if p_provider != null else _make_default_consent_provider()
	_consent_flow = ConsentFlow.new(consent_provider)
	_consent_flow.ads = self
	_consent_flow.clock = clock
	consent_state = ConsentState.PENDING
	_consent_flow.finished.connect(_on_consent_finished)
	_consent_flow.late_result.connect(_on_consent_late_result)
	_consent_flow.start()


func is_privacy_options_required() -> bool:
	return (
		consent_state == ConsentState.DONE
		and bool(consent_result.get("privacy_options_required", false))
	)


func show_privacy_options() -> void:
	if consent_provider == null:
		return
	consent_provider.show_privacy_options(_on_privacy_options_closed)


## Re-applies personalization after the privacy options form closed (new UMP status).
func _on_privacy_options_closed(status: String) -> void:
	var ump: String = consent_provider.get_ump_status()
	if ump == "" or ump == ConsentProvider.UMP_UNKNOWN:
		ump = status
	var personalized: bool = ump in [ConsentProvider.UMP_OBTAINED, ConsentProvider.UMP_NOT_REQUIRED]
	var att: String = str(consent_result.get("att_status", ""))
	if att != "" and att != ConsentProvider.ATT_AUTHORIZED:
		personalized = false
	consent_result = consent_result.duplicate()
	consent_result["ump_status"] = ump
	consent_result["personalized"] = personalized
	consent_result["can_request_ads"] = consent_provider.can_request_ads()
	consent_result["privacy_options_required"] = consent_provider.is_privacy_options_required()
	if provider != null:
		provider.set_personalized(personalized)
	report_consent("ump", ump)
	consent_finished.emit(consent_result)


## Form answered after consent_form_timeout_seconds: same path as closing privacy options.
func _on_consent_late_result(kind: String, status: String) -> void:
	if kind == "ump":
		_on_privacy_options_closed(status)
		return
	var ump: String = str(consent_result.get("ump_status", ""))
	var ump_ok: bool = ump in [ConsentProvider.UMP_OBTAINED, ConsentProvider.UMP_NOT_REQUIRED]
	var personalized: bool = ump_ok and status == ConsentProvider.ATT_AUTHORIZED
	consent_result = consent_result.duplicate()
	consent_result["att_status"] = status
	consent_result["personalized"] = personalized
	if provider != null:
		provider.set_personalized(personalized)
	report_consent("att", status)
	consent_finished.emit(consent_result)


## Tests only: back to the state before begin_consent().
func reset_consent() -> void:
	consent_state = ConsentState.NOT_STARTED
	consent_provider = null
	consent_result = {}
	_consent_flow = null


func _on_consent_finished(result: Dictionary) -> void:
	consent_result = result
	consent_state = ConsentState.DONE
	if provider != null:
		provider.set_personalized(bool(result.get("personalized", false)))
	consent_finished.emit(result)


func _make_default_consent_provider() -> ConsentProvider:
	# TODO: real UMP/ATT provider in Phase 5; until then "outside EEA", instant.
	return FakeConsentProvider.new()


## True when an interstitial was shown. Needs: ads not removed, level >= min level,
## level hits the every-N cap, min-seconds gap, no rewarded ad in this break, ad ready.
func maybe_show_interstitial(level_no: int, ads_removed: bool = false) -> bool:
	var every_n: int = int(GameConfig.get_value("interstitial_every_n_rounds"))
	var min_seconds: float = float(GameConfig.get_value("interstitial_min_seconds"))
	var min_level: int = int(GameConfig.get_value("interstitial_min_level"))
	# Every call marks the end of a break, so the flag is always consumed.
	var rewarded_in_break: bool = _rewarded_in_break
	_rewarded_in_break = false
	var gated: bool = consent_state == ConsentState.PENDING
	if gated or provider == null or ads_removed or level_no < min_level:
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
	if not provider.interstitial_closed.is_connected(_on_interstitial_closed):
		provider.interstitial_closed.connect(_on_interstitial_closed)
	_interstitial_ids.append(_begin_ad_break())
	ad_about_to_show.emit("interstitial")
	provider.show_interstitial()
	_last_interstitial_s = now
	interstitials_shown += 1
	Analytics.track_design("ads:interstitial:shown", float(level_no))
	interstitial_shown.emit(level_no)
	return true


func _on_interstitial_closed() -> void:
	if _interstitial_ids.is_empty():
		return
	_close_break(_interstitial_ids.pop_front(), "interstitial")


## Clears the "rewarded already shown in this break" flag (tests / bot).
func reset_break() -> void:
	_rewarded_in_break = false


## Resets the interstitial cooldown so the next call may show at once (tests / bot).
func reset_interstitial_cooldown() -> void:
	_last_interstitial_s = -INF


func is_rewarded_ready() -> bool:
	if consent_state == ConsentState.PENDING:
		return false
	return provider != null and provider.is_rewarded_ready()


## Shows a rewarded ad; on_reward is called (no args) only if the reward was earned.
func request_rewarded(placement_id: String, on_reward: Callable) -> bool:
	if consent_state == ConsentState.PENDING:
		return false
	if provider == null or not provider.is_rewarded_ready():
		Analytics.track_design("ads:rewarded:%s:unavailable" % placement_id)
		return false
	_rewarded_in_break = true
	var break_id: int = _begin_ad_break()
	var rewarded_done: Array[bool] = [false]
	ad_about_to_show.emit("rewarded")
	provider.show_rewarded(
		func(granted: bool) -> void:
			if rewarded_done[0]:
				return
			rewarded_done[0] = true
			_close_break(break_id, "rewarded")
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
