class_name PlaytestBot
extends RefCounted
## Headless bot: plays N rounds with a random strategy and reports anomalies.
## GDScript cannot catch runtime errors, so "crash" detection is contract validation.

const MAX_STEPS: int = 500
const ACTION_COUNT: int = 3
const SIM_SECONDS_PER_ROUND: float = 30.0


func run(rounds: int, run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var generator := ContentGenerator.new()
	var state := GameState.new()
	state.coins = int(GameConfig.get_value("starting_coins", 0))
	var win_reward: int = int(GameConfig.get_value("win_reward_coins", 10))
	var report: Dictionary = {
		"rounds": 0,
		"wins": 0,
		"losses": 0,
		"softlocks": 0,
		"avg_steps": 0.0,
		"coins_end": 0,
		"interstitials_shown": 0,
		"errors": [],
	}
	var errors: Array = report["errors"]
	var total_steps: int = 0

	# Simulated clock so the min-seconds interstitial cap behaves like a real session.
	var sim_time: Array[float] = [0.0]
	var old_clock: Callable = Ads.clock
	var shown_before: int = Ads.interstitials_shown
	Ads.clock = func() -> float: return sim_time[0]

	for i in rounds:
		var round_index: int = i + 1
		var level_data: Dictionary = generator.generate(run_seed + i, state.level)
		if not _valid_level(level_data):
			errors.append("round %d: invalid level data" % round_index)
			break
		var game_round := GameRound.new()
		game_round.start(level_data)
		var steps: int = 0
		var finished: bool = false
		while steps < MAX_STEPS:
			steps += 1
			if game_round.step(rng.randi_range(0, ACTION_COUNT - 1)):
				finished = true
				break
		report["rounds"] += 1
		total_steps += steps
		if not finished:
			report["softlocks"] += 1
			errors.append("round %d: softlock (> %d steps)" % [round_index, MAX_STEPS])
			continue
		var res: Dictionary = game_round.result()
		if not (res.has("won") and res.has("score") and res.has("steps")):
			errors.append("round %d: malformed result" % round_index)
			continue
		if res["won"]:
			report["wins"] += 1
			state.coins += win_reward
			state.level += 1
		else:
			report["losses"] += 1
		if state.coins < 0:
			errors.append("round %d: negative coins (%d)" % [round_index, state.coins])
		sim_time[0] += SIM_SECONDS_PER_ROUND
		Ads.maybe_show_interstitial(round_index)

	report["interstitials_shown"] = Ads.interstitials_shown - shown_before
	Ads.clock = old_clock
	report["coins_end"] = state.coins
	if report["rounds"] > 0:
		report["avg_steps"] = float(total_steps) / float(report["rounds"])
	return report


## Writes the report as JSON; accepts res://, user:// or absolute paths.
func write_report(report: Dictionary, path: String) -> bool:
	var abs_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		push_error("PlaytestBot: cannot write %s" % abs_path)
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return true


func _valid_level(level_data: Dictionary) -> bool:
	return level_data.has("seed") and level_data.has("difficulty") and level_data.has("payload")
