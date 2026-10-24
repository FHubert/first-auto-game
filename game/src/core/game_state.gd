class_name GameState
extends RefCounted
## Pure persistent player state (no Node). Serialised by SaveSystem.

const SCHEMA_VERSION: int = 3
const DEFAULT_THEME: String = "classic"
## Upper bound for any persisted int; larger saved values are clamped to it.
const MAX_SAVE_INT: int = 1_000_000_000
## Klucze `settings` (wartości = nazwy zapisane w save; nie zmieniać bez migracji).
const SETTING_MUSIC_ON: String = "music_on"
const SETTING_SFX_ON: String = "sfx_on"
const SETTING_HAPTICS_ON: String = "haptics_on"
const SETTING_TUTORIAL_DONE: String = "tutorial_done"
const SETTING_COLORBLIND_SYMBOLS: String = "colorblind_symbols"
const SETTING_DAILY_INTRO_SEEN: String = "daily_intro_seen"
const SETTING_NOTIFICATIONS_ON: String = "notifications_on"
const DEFAULT_SETTINGS: Dictionary = {
	SETTING_MUSIC_ON: true,
	SETTING_SFX_ON: true,
	SETTING_HAPTICS_ON: true,
	"ads_removed": false,
	SETTING_TUTORIAL_DONE: false,
	"locale": "",
	SETTING_DAILY_INTRO_SEEN: false,
	SETTING_NOTIFICATIONS_ON: true,
}
## Int fields as [name, minimum]; default is the initial value of the member.
const INT_FIELDS: Array = [
	["coins", 0],
	["level", 1],
	["streak_days", 0],
	["last_play_utc_day", 0],
	["daily_reward_last_claim_day", 0],
	["daily_last_completed_day", 0],
	["daily_completed_total", 0],
	["streak_best", 0],
	["streak_saves_used", 0],
	["streak_save_window_day", 0],
	["levels_completed", 0],
	["level_restarts", 0],
	["starter_offer_start_day", 0],
	["daily_month_id", 0],
	["daily_month_count", 0],
]

var coins: int = 0
var level: int = 1
var streak_days: int = 0
var last_play_utc_day: int = 0
var daily_reward_last_claim_day: int = 0
var daily_last_completed_day: int = 0
var daily_completed_total: int = 0
var streak_best: int = 0
var streak_saves_used: int = 0
var streak_save_window_day: int = 0
var themes_owned: Array = [DEFAULT_THEME]
var theme_active: String = DEFAULT_THEME
var levels_completed: int = 0
var level_restarts: int = 0
var starter_offer_start_day: int = 0
var daily_month_id: int = 0
var daily_month_count: int = 0
var purchases: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
## Snapshot rundy w toku (round_snapshot); pusty = brak rundy do wznowienia.
var round_in_progress: Dictionary = {}


## Upgrades an older save dict to SCHEMA_VERSION. Returns a copy.
static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var v_raw: Variant = _as_int(out.get("schema_version"))
	var version: int = 1 if v_raw == null else maxi(int(v_raw), 1)
	if version < 2:
		var defaults: Dictionary = GameState.new().to_dict()
		for key: String in defaults:
			if key != "settings" and not out.has(key):
				out[key] = defaults[key]
		var old_settings: Variant = out.get("settings", {})
		if typeof(old_settings) == TYPE_DICTIONARY:
			var merged: Dictionary = DEFAULT_SETTINGS.duplicate(true)
			merged.merge(old_settings, true)
			out["settings"] = merged
		version = 2
	if version < 3:
		if typeof(out.get("round_in_progress")) != TYPE_DICTIONARY:
			out["round_in_progress"] = {}
		version = 3
	out["schema_version"] = version
	return out


## Metadane wrappera + GameRound.to_dict() do zapisu w round_in_progress.
static func round_snapshot(
	mode: String, level_no: int, utc_day: int, round: GameRound
) -> Dictionary:
	return {"mode": mode, "level_no": level_no, "utc_day": utc_day, "round": round.to_dict()}


## Returns a GameState, or null only for a newer schema_version.
## A bad type/range of a single key resets just that key to its default: losing the
## whole save because of one corrupt key is the worst case for retention (T-074).
static func from_dict(d: Dictionary) -> GameState:
	var data: Dictionary = migrate(d)
	if int(data["schema_version"]) != SCHEMA_VERSION:
		return null
	var state := GameState.new()
	for entry: Array in INT_FIELDS:
		var field: String = entry[0]
		var v: Variant = _as_int(data.get(field, state.get(field)))
		if v != null and int(v) >= int(entry[1]):
			state.set(field, int(v))
	state.settings = _merge_settings(data.get("settings", {}))
	state.themes_owned = _clean_themes(data.get("themes_owned", state.themes_owned))
	state.purchases = _clean_purchases(data.get("purchases", {}))
	var active_v: Variant = data.get("theme_active", state.theme_active)
	if typeof(active_v) == TYPE_STRING and state.themes_owned.has(active_v):
		state.theme_active = active_v
	var rip: Variant = data.get("round_in_progress", {})
	if typeof(rip) == TYPE_DICTIONARY:
		state.round_in_progress = (rip as Dictionary).duplicate(true)
	return state


func owns_theme(id: String) -> bool:
	return themes_owned.has(id)


func has_purchase(sku: String) -> bool:
	return purchases.get(sku, false) == true


func to_dict() -> Dictionary:
	var out: Dictionary = {"schema_version": SCHEMA_VERSION}
	for entry: Array in INT_FIELDS:
		out[entry[0]] = get(entry[0])
	out["themes_owned"] = themes_owned.duplicate()
	out["theme_active"] = theme_active
	out["purchases"] = purchases.duplicate(true)
	out["settings"] = settings.duplicate(true)
	out["round_in_progress"] = round_in_progress.duplicate(true)
	return out


## Accepts ints and integral finite floats (JSON parses all numbers as float),
## capped at MAX_SAVE_INT; else null.
static func _as_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return mini(value, MAX_SAVE_INT)
	if typeof(value) == TYPE_FLOAT and is_finite(value):
		if value > float(MAX_SAVE_INT):
			return MAX_SAVE_INT
		if value < -float(MAX_SAVE_INT):
			return null
		if is_equal_approx(value, roundf(value)):
			return mini(int(value), MAX_SAVE_INT)
	return null


## Defaults + saved values (unknown keys kept); a known key of wrong type -> its default.
static func _merge_settings(value: Variant) -> Dictionary:
	var merged: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	if typeof(value) != TYPE_DICTIONARY:
		return merged
	merged.merge(value, true)
	for key: String in DEFAULT_SETTINGS:
		if typeof(merged[key]) != typeof(DEFAULT_SETTINGS[key]):
			merged[key] = DEFAULT_SETTINGS[key]
	return merged


## De-duplicates, skips invalid items and guarantees the free default theme.
static func _clean_themes(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			if (
				typeof(item) == TYPE_STRING
				and not (item as String).is_empty()
				and not out.has(item)
			):
				out.append(item)
	if not out.has(DEFAULT_THEME):
		out.append(DEFAULT_THEME)
	return out


## Keeps only String -> bool entries; anything else is skipped.
static func _clean_purchases(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for key: Variant in value:
		if typeof(key) == TYPE_STRING and typeof(value[key]) == TYPE_BOOL:
			out[key] = value[key]
	return out
