class_name PlaytestBot
extends RefCounted
## Headless bot: plays N rounds with a random strategy and reports anomalies.
## GDScript cannot catch runtime errors, so "crash" detection is contract validation.

const MODE_SOLVER: String = "solver"
const MODE_RANDOM: String = "random"
const MODE_GREEDY: String = "greedy"
const MAX_STEPS: int = 600
## Random walk may cycle forever without ever being stuck; restart after this many steps.
const ATTEMPT_STEPS: int = 150
const SIM_SECONDS_PER_ROUND: float = 30.0
## Level brackets [min, max] for the per-bracket report; labels in the same order.
const BRACKETS: Array = [[1, 7], [8, 25], [26, 55], [56, 1000000]]
const BRACKET_LABELS: Array = ["1-7", "8-25", "26-55", "56+"]

var max_restarts_per_round: int = 50
## true: boards from GameConfig "campaign_seed" (as Level.load_level), not run_seed + i.
var use_campaign_seed: bool = false
## Level data of the most recently generated round (test hook, e.g. to check the seed used).
var last_level_data: Dictionary = {}


func run(rounds: int, run_seed: int, mode: String = MODE_SOLVER) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var generator := ContentGenerator.new()
	var state := GameState.new()
	state.coins = int(GameConfig.get_value("starting_coins", 0))
	var win_reward: int = int(GameConfig.get_value("win_reward_coins"))
	var report: Dictionary = {
		"mode": mode,
		"rounds": 0,
		"wins": 0,
		"losses": 0,
		"softlocks": 0,
		"stuck_count": 0,
		"restarts_total": 0,
		"max_restarts_seen": 0,
		"avg_moves": 0.0,
		"avg_steps": 0.0,
		"perfect_count": 0,
		"coins_end": 0,
		"interstitials_shown": 0,
		"interstitial_calls": 0,
		"rounds_by_bracket": _zero_brackets(),
		"losses_by_bracket": _zero_brackets(),
		"errors": [],
		"elapsed_ms": 0,
	}
	var rounds_by_bracket: Dictionary = report["rounds_by_bracket"]
	var losses_by_bracket: Dictionary = report["losses_by_bracket"]
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
		var gen_seed: int = run_seed + i
		if use_campaign_seed:
			gen_seed = int(GameConfig.get_value("campaign_seed"))
		var level_data: Dictionary = generator.generate(gen_seed, state.level)
		last_level_data = level_data
		var bracket: String = _bracket_label(state.level)
		if not _valid_level(level_data):
			errors.append("round %d: invalid level data" % round_index)
			break
		var game_round := GameRound.new()
		game_round.start(level_data)
		var steps: int = 0
		var gave_up: bool = false
		if mode == MODE_RANDOM or mode == MODE_GREEDY:
			var pick: Callable = _pick_random if mode == MODE_RANDOM else pick_greedy
			var out: Dictionary = _play_heuristic(
				game_round, rng, round_index, errors, report, pick
			)
			steps = int(out["steps"])
			gave_up = bool(out["gave_up"])
		else:
			steps = _play_solution(game_round, level_data, round_index, errors)
		var finished: bool = game_round.is_done()
		report["rounds"] += 1
		rounds_by_bracket[bracket] += 1
		total_steps += steps
		if not finished and not gave_up:
			report["softlocks"] += 1
			errors.append("round %d: softlock (> %d steps)" % [round_index, MAX_STEPS])
			continue
		if gave_up:
			# Random player lost (restart limit): not a bug. Advance a level (no coins)
			# so the bot does not sit on one hard level for all rounds.
			report["losses"] += 1
			losses_by_bracket[bracket] += 1
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
				var won_level: int = state.level
				state.level += 1
				# Like Level.on_next_pressed: ad break only after a win.
				report["interstitial_calls"] += 1
				Ads.maybe_show_interstitial(won_level)
			else:
				report["losses"] += 1
				losses_by_bracket[bracket] += 1
		if state.coins < 0:
			errors.append("round %d: negative coins (%d)" % [round_index, state.coins])
		sim_time[0] += SIM_SECONDS_PER_ROUND

	report["interstitials_shown"] = Ads.interstitials_shown - shown_before
	Ads.clock = old_clock
	report["coins_end"] = state.coins
	if report["rounds"] > 0:
		report["avg_steps"] = float(total_steps) / float(report["rounds"])
	if finished_rounds > 0:
		report["avg_moves"] = float(total_moves) / float(finished_rounds)
	report["elapsed_ms"] = Time.get_ticks_msec() - started_ms
	return report


func _zero_brackets() -> Dictionary:
	var out: Dictionary = {}
	for label: String in BRACKET_LABELS:
		out[label] = 0
	return out


func _bracket_label(level: int) -> String:
	for idx in BRACKETS.size():
		if level <= int(BRACKETS[idx][1]):
			return BRACKET_LABELS[idx]
	return BRACKET_LABELS[BRACKET_LABELS.size() - 1]


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


## Heuristic for a casual player: +3 move completes the target tube, +2 pour onto the same
## colour, -2 pour of a whole uniform tube into an empty one (no progress), 0 otherwise.
static func score_move(board: SortBoard, m: Vector2i) -> int:
	var from: int = m.x
	var to: int = m.y
	if not board.is_empty(to) and board.top_color(to) == board.top_color(from):
		var amount: int = mini(board.top_run(from), board.free_space(to))
		var tube_to: Array = board.tubes[to]
		var uniform_after: bool = board.is_uniform(to)
		if uniform_after and tube_to.size() + amount == board.capacity:
			return 3
		return 2
	if board.is_empty(to) and board.is_uniform(from):
		return -2
	return 0


## Best-scored move (ties random via rng); avoids undoing `prev` unless it is the only move.
static func pick_greedy(
	board: SortBoard, moves: Array[Vector2i], prev: Vector2i, rng: RandomNumberGenerator
) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for m: Vector2i in moves:
		if prev != Vector2i(-1, -1) and m == Vector2i(prev.y, prev.x):
			continue
		candidates.append(m)
	if candidates.is_empty():
		candidates = moves
	var best: int = -1000
	var top: Array[Vector2i] = []
	for m: Vector2i in candidates:
		var sc: int = score_move(board, m)
		if sc > best:
			best = sc
			top.clear()
		if sc == best:
			top.append(m)
	return top[rng.randi_range(0, top.size() - 1)]


static func _pick_random(
	_board: SortBoard, moves: Array[Vector2i], _prev: Vector2i, rng: RandomNumberGenerator
) -> Vector2i:
	return moves[rng.randi_range(0, moves.size() - 1)]


## Plays with `pick` (board, moves, prev, rng -> move); restart when stuck.
## Returns {steps, gave_up}.
## report["max_restarts_seen"] = max restarts actually performed in one round.
func _play_heuristic(
	game_round: GameRound,
	rng: RandomNumberGenerator,
	round_index: int,
	errors: Array,
	report: Dictionary,
	pick: Callable
) -> Dictionary:
	var prev: Vector2i = Vector2i(-1, -1)
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
			prev = Vector2i(-1, -1)
			# Counted after the limit check: only restarts actually performed.
			report["max_restarts_seen"] = maxi(int(report["max_restarts_seen"]), restarts)
			continue
		var m: Vector2i = pick.call(game_round.board(), moves, prev, rng)
		prev = m
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
