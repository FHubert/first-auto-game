class_name ScreenshotArgs
extends RefCounted
## Czysty parser argumentow trybu `--screenshot=<scene> --out=<png>`
## z opcjami `[--lang=xx] [--fixture=<name>] [--now=<unix>]`.

## Fixed clock for deterministic screenshots: 2026-10-24 12:00 UTC (UTC day 20750).
const SCREENSHOT_NOW_UNIX: int = 1792843200
const KNOWN_SCENES: Array[String] = [
	"res://src/core/main.tscn",
	"res://src/levels/level.tscn",
	"res://src/ui/level_complete.tscn",
	"res://src/ui/stuck_panel.tscn",
	"res://src/ui/home.tscn",
	"res://src/ui/settings_screen.tscn",
	"res://src/ui/daily_reward_popup.tscn",
	"res://src/ui/themes_screen.tscn",
	"res://src/ui/shop_screen.tscn",
]
const KNOWN_FIXTURES: Array[String] = [
	"default",
	"midgame",
	"aso_level",
	"aso_win",
	"aso_home",
	"aso_daily",
	"aso_themes",
	"symbols",
	"symbols_neon",
]
const ACTIONS: Dictionary = {
	"res://src/core/main.tscn": "home",
	"res://src/levels/level.tscn": "level",
	"res://src/ui/level_complete.tscn": "level_complete",
	"res://src/ui/stuck_panel.tscn": "stuck_panel",
	"res://src/ui/home.tscn": "home",
	"res://src/ui/settings_screen.tscn": "settings",
	"res://src/ui/daily_reward_popup.tscn": "daily_popup",
	"res://src/ui/themes_screen.tscn": "themes",
	"res://src/ui/shop_screen.tscn": "shop",
}


static func has_flag(args: PackedStringArray, key: String) -> bool:
	for arg in args:
		if arg == key or arg.begins_with(key + "="):
			return true
	return false


## Returns {ok, error, scene, out, lang, fixture, now}; first error wins.
## `now` = --now (non-negative int) or SCREENSHOT_NOW_UNIX.
static func parse(args: PackedStringArray) -> Dictionary:
	var res: Dictionary = {
		"ok": false,
		"error": "",
		"scene": "",
		"out": "",
		"lang": "",
		"fixture": "default",
		"now": SCREENSHOT_NOW_UNIX
	}
	res["scene"] = _value(args, "--screenshot", "")
	res["out"] = _value(args, "--out", "")
	res["lang"] = _value(args, "--lang", "")
	res["fixture"] = _value(args, "--fixture", "default")
	var now_raw: String = _value(args, "--now", "")
	var now_valid: bool = now_raw.is_empty() or now_raw.is_valid_int()
	if now_valid and not now_raw.is_empty():
		res["now"] = now_raw.to_int()
	if not (res["scene"] in KNOWN_SCENES):
		res["error"] = "unknown scene: '%s'" % res["scene"]
	elif str(res["out"]).is_empty() or not str(res["out"]).ends_with(".png"):
		res["error"] = "--out must be a non-empty .png path"
	elif str(res["lang"]) != "" and not (str(res["lang"]) in Locale.supported()):
		res["error"] = "unknown lang: '%s'" % res["lang"]
	elif not (res["fixture"] in KNOWN_FIXTURES):
		res["error"] = "unknown fixture: '%s'" % res["fixture"]
	elif not now_valid or int(res["now"]) < 0:
		res["error"] = "--now must be a non-negative integer"
	res["ok"] = str(res["error"]).is_empty()
	return res


## Action name for a scene path ("" when unknown).
static func action_for(scene: String) -> String:
	return str(ACTIONS.get(scene, ""))


static func _value(args: PackedStringArray, key: String, fallback: String) -> String:
	var prefix: String = key + "="
	for arg in args:
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
