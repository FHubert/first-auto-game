class_name PlaytestBot
extends RefCounted
## Headless bot: plays N rounds with a random strategy and reports anomalies.
## GDScript cannot catch runtime errors, so "crash" detection is contract validation.

const MODE_SOLVER: String = "solver"
const MODE_RANDOM: String = "random"
const MAX_STEPS: int = 600
## Random walk may cycle forever without ever being stuck; restart after this many steps.
const ATTEMPT_STEPS: int = 150
const SIM_SECONDS_PER_ROUND: float = 30.0

var max_restarts_per_round: int = 50


func run(rounds: int, run_seed: int, mode: String = MODE_SOLVER) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var generator := ContentGenerator.new()
	var state := GameState.new()
	state.coins = int(GameConfig.get_value("starting_coins", 0))
	var win_reward: int = int(GameConfig.get_value("win_reward_coins", 10))
	var report: Dictionary = {
		"mode": mode,
		"rounds": 0,
		"wins": 0,
		"losses": 0,
		"softlocks": 0,
		"stuck_count": 0,
		"restarts_total": 0,
		"avg_moves": 0.0,
		"avg_steps": 0.0,
		"perfect_count": 0,
		"coins_end": 0,
		"interstitials_shown": 0,
		"errors": [],
		"elapsed_ms": 0,
	}
	var errors: Array = report["errors"]
	var total_steps: int = 0
	var total_moves: int = 0
	var finished_rounds: int = 0

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
		var gave_up: bool = false
		if mode == MODE_RANDOM:
			var out: Dictionary = _play_random(game_round, rng, round_index, errors, report)
			steps = int(out["steps"])
			gave_up = bool(out["gave_up"])
		else:
			steps = _play_solution(game_round, level_data, round_index, errors)
		var finished: bool = game_round.is_done()
		report["rounds"] += 1
		total_steps += steps
		if not finished and not gave_up:
			report["softlocks"] += 1
			errors.append("round %d: softlock (> %d steps)" % [round_index, MAX_STEPS])
			continue
		if gave_up:
			# Random player lost (restart limit): not a bug. Advance a level (no coins)
			# so the bot does not sit on one hard level for all rounds.
			report["losses"] += 1
			state.level += 1
		else:
			var res: Dictionary = game_round.result()
			if not (res.has("won") and res.has("moves") and res.has("perfect")):
				errors.append("round %d: malformed result" % round_index)
				continue
			finished_rounds += 1
			total_moves += int(res["moves"])
			if res["perfect"]:
				report["perfect_count"] += 1
			if res["won"]:
				report["wins"] += 1
				state.coins += win_reward
				state.level += 1
			else:
				report["losses"] += 1
		if state.coins < 0:
			errors.append("round %d: negative coins (%d)" % [round_index, state.coins])
		sim_time[0] += SIM_SECONDS_PER_ROUND
		Ads.maybe_show_interstitial(state.level - 1)

	report["interstitials_shown"] = Ads.interstitials_shown - shown_before
	Ads.clock = old_clock
	report["coins_end"] = state.coins
	if report["rounds"] > 0:
		report["avg_steps"] = float(total_steps) / float(report["rounds"])
	if finished_rounds > 0:
		report["avg_moves"] = float(total_moves) / float(finished_rounds)
	report["elapsed_ms"] = Time.get_ticks_msec() - started_ms
	return report


func _play_solution(
	game_round: GameRound, level_data: Dictionary, round_index: int, errors: Array
) -> int:
	var steps: int = 0
	var finished: bool = game_round.is_done()
	var solution: Array = level_data["payload"].get("solution", [])
	for m: Vector2i in solution:
		if finished or steps >= MAX_STEPS:
			break
		steps += 1
		finished = game_round.step(GameRound.encode_action(m.x, m.y))
	if not finished and steps < MAX_STEPS:
		errors.append("round %d: solution did not win" % round_index)
	return steps


## Random legal moves; restart when stuck. Returns {steps, gave_up}.
func _play_random(
	game_round: GameRound,
	rng: RandomNumberGenerator,
	round_index: int,
	errors: Array,
	report: Dictionary
) -> Dictionary:
	var steps: int = 0
	var restarts: int = 0
	var attempt_steps: int = 0
	while not game_round.is_done():
		if steps >= MAX_STEPS:
			# Budget exhausted by a wandering random player: a loss, not a softlock.
			return {"steps": steps, "gave_up": true}
		var moves: Array[Vector2i] = game_round.board().legal_moves()
		var stuck: bool = moves.is_empty()
		if stuck or attempt_steps >= ATTEMPT_STEPS:
			if stuck:
				report["stuck_count"] += 1
			report["restarts_total"] += 1
			attempt_steps = 0
			restarts += 1
			if restarts > max_restarts_per_round:
				return {"steps": steps, "gave_up": true}
			game_round.restart()
			continue
		var m: Vector2i = moves[rng.randi_range(0, moves.size() - 1)]
		if not game_round.try_move(m.x, m.y):
			errors.append("round %d: legal move rejected (%d->%d)" % [round_index, m.x, m.y])
			return {"steps": steps, "gave_up": true}
		steps += 1
		attempt_steps += 1
	return {"steps": steps, "gave_up": false}


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
