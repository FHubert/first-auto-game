extends Control
## Entry scene. With `-- --playtest` it runs the headless bot instead of the UI.

const DEFAULT_REPORT: String = "res://test/reports/playtest.json"

@onready var _label: Label = $Build


func _ready() -> void:
	_label.text = Version.BUILD_INFO
	print("Build: ", Version.BUILD_INFO)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if ScreenshotArgs.has_flag(args, "--screenshot"):
		_run_screenshot(args)
	elif "--playtest" in args:
		_label.text = "Playtest..."
		var exit_code: int = _run_playtest(args)
		get_tree().quit(exit_code)
	else:
		_start_app()


func _start_app() -> void:
	var app := App.new()
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(app)
	_label.visible = false


## `--screenshot=<scene> --out=<png> [--lang=xx] [--fixture=<name>]`: renders one screen and quits.
func _run_screenshot(args: PackedStringArray) -> void:
	var parsed: Dictionary = ScreenshotArgs.parse(args)
	if not bool(parsed["ok"]):
		push_error("screenshot: " + str(parsed["error"]))
		get_tree().quit(2)
		return
	SaveSystem.read_only = true
	var today: int = DailyRewards.utc_day_from_unix(int(Time.get_unix_time_from_system()))
	var state: GameState = ScreenshotFixtures.make(str(parsed["fixture"]), today)
	if str(parsed["lang"]) != "":
		state.settings["locale"] = parsed["lang"]
	var action: String = ScreenshotArgs.action_for(str(parsed["scene"]))
	if action != "daily_popup":  # popup only on its own shot; keep Home clean otherwise
		state.daily_reward_last_claim_day = today
	var app := App.new()
	app.state = state
	app.effects_enabled = false
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(app)
	_label.visible = false
	_show_screenshot_screen(app, action)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out: String = str(parsed["out"])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err: int = get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit(0 if err == OK else 1)


func _show_screenshot_screen(app: App, action: String) -> void:
	match action:
		"level":
			app.show_level()
		"settings":
			app.show_settings()
		"themes":
			app.show_themes()
		"shop":
			app.show_shop()
		"level_complete":
			app.show_level()
			ScreenshotFixtures.apply_win(app.current_screen() as Level)
		"stuck_panel":
			app.show_level()
			var level := app.current_screen() as Level
			level.stuck_panel.show_for(level.round, true, level.offers.ad_offers())


func _run_playtest(args: PackedStringArray) -> int:
	var rounds: int = int(_arg_value(args, "--rounds", "200"))
	var run_seed: int = int(_arg_value(args, "--seed", "42"))
	var report_path: String = _arg_value(args, "--report", DEFAULT_REPORT)
	var bot := PlaytestBot.new()
	bot.max_restarts_per_round = int(
		_arg_value(args, "--max-restarts", str(bot.max_restarts_per_round))
	)
	var mode: String = PlaytestBot.MODE_RANDOM if "--random" in args else PlaytestBot.MODE_SOLVER
	var report: Dictionary = bot.run(rounds, run_seed, mode)
	bot.write_report(report, report_path)
	print("Playtest report: ", JSON.stringify(report))
	var errors: Array = report.get("errors", [])
	var failed: bool = int(report.get("softlocks", 0)) > 0 or not errors.is_empty()
	return 1 if failed else 0


func _arg_value(args: PackedStringArray, key: String, fallback: String) -> String:
	var prefix: String = key + "="
	for arg in args:
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback
