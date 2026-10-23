extends Control
## Entry scene. With `-- --playtest` it runs the headless bot instead of the UI.

const DEFAULT_REPORT: String = "res://test/reports/playtest.json"

@onready var _label: Label = $Build


func _ready() -> void:
	_label.text = Version.BUILD_INFO
	print("Build: ", Version.BUILD_INFO)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--playtest" in args:
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
