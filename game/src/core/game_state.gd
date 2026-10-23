class_name GameState
extends RefCounted
## Pure persistent player state (no Node). Serialised by SaveSystem.

const SCHEMA_VERSION: int = 1

var coins: int = 0
var level: int = 1
var streak_days: int = 0
var last_play_utc_day: int = 0
var settings: Dictionary = {}


## Upgrades an older save dict to SCHEMA_VERSION. Returns a copy.
static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var version: int = int(out.get("schema_version", 1))
	# Add `if version < 2: ...; version = 2` steps here for future schemas.
	out["schema_version"] = version
	return out


## Returns a GameState, or null when the dict is invalid (bad types, newer schema).
static func from_dict(d: Dictionary) -> GameState:
	var data: Dictionary = migrate(d)
	if int(data["schema_version"]) != SCHEMA_VERSION:
		return null
	var state := GameState.new()
	var coins_v: Variant = _as_int(data.get("coins", state.coins))
	var level_v: Variant = _as_int(data.get("level", state.level))
	var streak_v: Variant = _as_int(data.get("streak_days", state.streak_days))
	var day_v: Variant = _as_int(data.get("last_play_utc_day", state.last_play_utc_day))
	var settings_v: Variant = data.get("settings", state.settings)
	if coins_v == null or level_v == null or streak_v == null or day_v == null:
		return null
	if typeof(settings_v) != TYPE_DICTIONARY:
		return null
	if int(coins_v) < 0 or int(level_v) < 1 or int(streak_v) < 0 or int(day_v) < 0:
		return null
	state.coins = int(coins_v)
	state.level = int(level_v)
	state.streak_days = int(streak_v)
	state.last_play_utc_day = int(day_v)
	state.settings = (settings_v as Dictionary).duplicate(true)
	return state


## Accepts ints and integral floats (JSON parses all numbers as float); else null.
static func _as_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value)):
		return int(value)
	return null


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"coins": coins,
		"level": level,
		"streak_days": streak_days,
		"last_play_utc_day": last_play_utc_day,
		"settings": settings.duplicate(true),
	}
