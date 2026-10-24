class_name NotificationPlanner
extends RefCounted
## Pure planner of local notifications (max 2: streak/daily + comeback). Time is injected.

const SECONDS_PER_DAY: int = 86400
const SECONDS_PER_HOUR: int = 3600


## Returns entries {kind, fire_unix, title_key, body_key} sorted by fire_unix.
static func plan(now_unix: int, tz_offset_minutes: int, state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not bool(state.settings.get("notifications_on", true)):
		return out
	if not bool(state.settings.get("tutorial_done", false)):
		return out
	var local: int = now_unix + tz_offset_minutes * 60
	var local_day: int = floori(float(local) / SECONDS_PER_DAY)
	var hour: int = int(GameConfig.get_value("notif_local_hour"))
	var kind: String = ""
	var today_utc: int = DailyRewards.utc_day_from_unix(now_unix)
	if (
		state.streak_days >= int(GameConfig.get_value("notif_streak_min_days"))
		and state.last_play_utc_day == today_utc
	):
		kind = "streak"
	elif DailyChallenge.is_unlocked(state):
		kind = "daily"
	if kind != "":
		out.append(_entry(kind, _fire_at(local_day + 1, hour, tz_offset_minutes)))
	var days: int = int(GameConfig.get_value("notif_comeback_days"))
	out.append(_entry("comeback", _fire_at(local_day + days, hour, tz_offset_minutes)))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.fire_unix < b.fire_unix)
	return out


static func _fire_at(local_day: int, hour: int, tz_offset_minutes: int) -> int:
	return local_day * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR - tz_offset_minutes * 60


static func _entry(kind: String, fire_unix: int) -> Dictionary:
	return {
		"kind": kind,
		"fire_unix": fire_unix,
		"title_key": "notif_%s_title" % kind,
		"body_key": "notif_%s_body" % kind,
	}
