class_name DailyRewards
extends RefCounted
## Pure daily reward + streak logic. The UTC day is always injected.

const SECONDS_PER_DAY: int = 86400

const REASON_FIRST: String = "first"
const REASON_SAME_DAY: String = "same_day"
const REASON_CONTINUE: String = "continue"
const REASON_GRACE: String = "grace"
const REASON_RESET: String = "reset"
const REASON_SAVED: String = "saved"


static func utc_day_from_unix(unix: int) -> int:
	return unix / SECONDS_PER_DAY


static func streak_status(state: GameState, utc_day: int) -> String:
	var last: int = state.last_play_utc_day
	if last == 0 or state.streak_days == 0:
		return REASON_FIRST
	if utc_day == last:
		return REASON_SAME_DAY
	if utc_day == last + 1:
		return REASON_CONTINUE
	if utc_day < last:
		return REASON_SAME_DAY
	var grace_days: int = int(GameConfig.get_value("streak_grace_days"))
	if utc_day - last - 1 <= grace_days:
		return REASON_GRACE
	return REASON_RESET


static func can_save_streak(state: GameState, utc_day: int) -> bool:
	return streak_status(state, utc_day) == REASON_GRACE and _saves_left(state, utc_day) > 0


static func save_streak(state: GameState, utc_day: int) -> bool:
	if not can_save_streak(state, utc_day):
		return false
	if _window_expired(state, utc_day):
		state.streak_saves_used = 0
		state.streak_save_window_day = utc_day
	state.streak_saves_used += 1
	state.last_play_utc_day = utc_day - 1
	Analytics.track_design("streak:" + REASON_SAVED, float(state.streak_days))
	return true


## Registers a play on utc_day. Returns {from, to, reason}.
static func register_play(state: GameState, utc_day: int) -> Dictionary:
	var result: Dictionary = _next_streak(state, utc_day)
	var to: int = result["to"]
	state.streak_days = to
	if result["reason"] != REASON_SAME_DAY:
		state.last_play_utc_day = utc_day
	state.streak_best = maxi(state.streak_best, state.streak_days)
	if result["from"] != to:
		Analytics.track_design("streak:" + String(result["reason"]), float(to))
	return result


static func cycle_day(streak_days: int) -> int:
	var size: int = _multipliers().size()
	return ((maxi(streak_days, 1) - 1) % size) + 1


static func reward_for_cycle_day(day: int) -> int:
	var multipliers: Array = _multipliers()
	var index: int = clampi(day, 1, multipliers.size()) - 1
	return int(GameConfig.get_value("daily_reward_base")) * int(multipliers[index])


static func can_claim(state: GameState, utc_day: int) -> bool:
	return utc_day > 0 and state.daily_reward_last_claim_day != utc_day


## Read-only view: {cycle_day, amount, can_claim, status}. Amount is for the streak after play.
static func preview(state: GameState, utc_day: int) -> Dictionary:
	var next: Dictionary = _next_streak(state, utc_day)
	var day: int = cycle_day(int(next["to"]))
	return {
		"cycle_day": day,
		"amount": reward_for_cycle_day(day),
		"can_claim": can_claim(state, utc_day),
		"status": streak_status(state, utc_day),
	}


## Claims today's reward (also registers the play). Returns coins granted, 0 if rejected.
static func claim(state: GameState, utc_day: int, doubled: bool = false) -> int:
	if not can_claim(state, utc_day):
		return 0
	register_play(state, utc_day)
	var day: int = cycle_day(state.streak_days)
	var amount: int = reward_for_cycle_day(day)
	if doubled:
		amount = int(round(amount * float(GameConfig.get_value("rewarded_multiplier"))))
	Economy.earn(state, amount, Economy.SOURCE_DAILY_REWARD)
	state.daily_reward_last_claim_day = utc_day
	var suffix: String = ":x2" if doubled else ""
	Analytics.track_design("daily_reward:day_%d%s" % [day, suffix], float(amount))
	return amount


## Pure computation of the streak transition without mutating state.
static func _next_streak(state: GameState, utc_day: int) -> Dictionary:
	var status: String = streak_status(state, utc_day)
	var from: int = state.streak_days
	var to: int = from
	var reason: String = status
	match status:
		REASON_FIRST:
			to = 1
		REASON_CONTINUE:
			to = from + 1
		REASON_GRACE, REASON_RESET:
			to = 1
			reason = REASON_RESET
	return {"from": from, "to": to, "reason": reason}


static func _multipliers() -> Array:
	var multipliers: Array = GameConfig.get_value("daily_reward_multipliers")
	if multipliers.is_empty():
		return [1]
	return multipliers


static func _window_expired(state: GameState, utc_day: int) -> bool:
	var window: int = int(GameConfig.get_value("streak_save_window_days"))
	return state.streak_save_window_day == 0 or utc_day - state.streak_save_window_day >= window


static func _saves_left(state: GameState, utc_day: int) -> int:
	var max_saves: int = int(GameConfig.get_value("streak_save_max_per_week"))
	if _window_expired(state, utc_day):
		return max_saves
	return max_saves - state.streak_saves_used
