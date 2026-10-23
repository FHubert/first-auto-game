class_name GameState
extends RefCounted
## Pure persistent player state (no Node). Serialised by SaveSystem.

const SCHEMA_VERSION: int = 2
const DEFAULT_THEME: String = "classic"
const DEFAULT_SETTINGS: Dictionary = {
	"music_on": true,
	"sfx_on": true,
	"haptics_on": true,
	"ads_removed": false,
	"tutorial_done": false,
	"locale": "",
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
var purchases: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)


## Upgrades an older save dict to SCHEMA_VERSION. Returns a copy.
static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var version: int = int(out.get("schema_version", 1))
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
	out["schema_version"] = version
	return out


## Returns a GameState, or null when the dict is invalid (bad types, newer schema).
static func from_dict(d: Dictionary) -> GameState:
	var data: Dictionary = migrate(d)
	if int(data["schema_version"]) != SCHEMA_VERSION:
		return null
	var state := GameState.new()
	for entry: Array in INT_FIELDS:
		var field: String = entry[0]
		var v: Variant = _as_int(data.get(field, state.get(field)))
		if v == null or int(v) < int(entry[1]):
			return null
		state.set(field, int(v))
	var settings_v: Variant = _merge_settings(data.get("settings", {}))
	var themes_v: Variant = _clean_themes(data.get("themes_owned", state.themes_owned))
	var purchases_v: Variant = data.get("purchases", {})
	if settings_v == null or themes_v == null or not _valid_purchases(purchases_v):
		return null
	var active_v: Variant = data.get("theme_active", state.theme_active)
	if typeof(active_v) != TYPE_STRING or not (themes_v as Array).has(active_v):
		return null
	state.settings = settings_v
	state.themes_owned = themes_v
	state.theme_active = active_v
	state.purchases = (purchases_v as Dictionary).duplicate(true)
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
	return out


## Accepts ints and integral floats (JSON parses all numbers as float); else null.
static func _as_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value)):
		return int(value)
	return null


## Defaults + saved values (unknown keys kept); null on wrong type of a known key.
static func _merge_settings(value: Variant) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var merged: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	merged.merge(value, true)
	for key: String in DEFAULT_SETTINGS:
		if typeof(merged[key]) != typeof(DEFAULT_SETTINGS[key]):
			return null
	return merged


## Validates, de-duplicates and guarantees the free default theme; null if invalid.
static func _clean_themes(value: Variant) -> Variant:
	if typeof(value) != TYPE_ARRAY:
		return null
	var out: Array = []
	for item: Variant in value:
		if typeof(item) != TYPE_STRING or (item as String).is_empty():
			return null
		if not out.has(item):
			out.append(item)
	if not out.has(DEFAULT_THEME):
		out.append(DEFAULT_THEME)
	return out


static func _valid_purchases(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or typeof(value[key]) != TYPE_BOOL:
			return false
	return true
