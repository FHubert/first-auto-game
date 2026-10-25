# gdlint: disable=max-public-methods
extends GdUnitTestSuite

const KEYS: Array = [
	"mode",
	"rounds",
	"wins",
	"losses",
	"softlocks",
	"stuck_count",
	"restarts_total",
	"max_restarts_seen",
	"avg_moves",
	"avg_steps",
	"perfect_count",
	"coins_end",
	"interstitials_shown",
	"interstitial_calls",
	"rounds_by_bracket",
	"losses_by_bracket",
	"errors",
	"elapsed_ms",
	"levels_won_by_bracket",
	"attempts_by_bracket",
	"won_first_try_by_bracket",
	"won_within_3_by_bracket",
	"skips_by_bracket",
	"median_attempts_by_bracket",
	"extra_tubes_by_bracket",
	"attempts_with_tube_by_bracket",
	"won_with_tube_by_bracket",
	"attempts_without_tube_by_bracket",
	"won_without_tube_by_bracket",
	"won_le3_pct_by_bracket",
	"won_first_pct_by_bracket",
	"stuck_attempts_by_bracket",
	"stuck_rate_pct_by_bracket",
]
## T-162 gate (26-55 within 3 tries, %), reduced sample (1 seed).
const GATE_26_55: float = 50.0

## 20 rounds is noise-level (seed 7: greedy 19 vs random 20); 50 rounds is stable.
const GREEDY_VS_RANDOM_ROUNDS: int = 50

var _old_provider: Object


func before_test() -> void:
	GameConfig.reset()
	_old_provider = Ads.provider


func after_test() -> void:
	Ads.provider = _old_provider
	GameConfig.reset()


func _loose_ad_caps() -> FakeAdProvider:
	var fake := FakeAdProvider.new()
	Ads.provider = fake
	# Earlier suites may leave a real-clock timestamp; the bot uses a simulated clock.
	Ads.reset_interstitial_cooldown()
	(
		GameConfig
		. apply_remote(
			{
				"interstitial_min_level": 1,
				"interstitial_every_n_rounds": 1,
				"interstitial_min_seconds": 0,
			}
		)
	)
	return fake


func test_solver_mode_small() -> void:
	var report: Dictionary = PlaytestBot.new().run(5, 42, PlaytestBot.MODE_SOLVER)
	assert_int(report["rounds"]).is_equal(5)
	assert_int(report["wins"]).is_equal(5)
	assert_int(report["softlocks"]).is_equal(0)
	assert_array(report["errors"]).is_empty()
	assert_float(report["avg_moves"]).is_greater(0.0)
	assert_dict(report).contains_keys(KEYS)


func test_random_mode_small() -> void:
	var bot := PlaytestBot.new()
	bot.max_restarts_per_round = 20
	var report: Dictionary = bot.run(5, 42, PlaytestBot.MODE_RANDOM)
	assert_int(report["rounds"]).is_equal(5)
	assert_int(report["softlocks"]).is_equal(0)
	assert_array(report["errors"]).is_empty()
	assert_int(report["wins"] + report["losses"]).is_equal(5)
	assert_int(report["stuck_count"]).is_greater_equal(0)
	assert_str(report["mode"]).is_equal("random")


func test_report_has_all_keys() -> void:
	var report: Dictionary = PlaytestBot.new().run(2, 7)
	assert_dict(report).contains_keys(KEYS)
	assert_str(report["mode"]).is_equal("solver")


func test_interstitial_at_most_once_per_won_round() -> void:
	var fake: FakeAdProvider = _loose_ad_caps()
	var bot := PlaytestBot.new()
	bot.max_restarts_per_round = 0
	var report: Dictionary = bot.run(8, 7, PlaytestBot.MODE_RANDOM)
	assert_int(report["losses"] + report["wins"]).is_equal(8)
	assert_int(report["interstitial_calls"]).is_equal(report["wins"])
	assert_int(report["interstitials_shown"]).is_less_equal(report["wins"])
	assert_int(report["interstitials_shown"]).is_equal(fake.interstitials_shown)


func test_interstitial_solver_every_round() -> void:
	var fake: FakeAdProvider = _loose_ad_caps()
	var report: Dictionary = PlaytestBot.new().run(6, 42)
	assert_int(report["interstitial_calls"]).is_equal(6)
	assert_int(report["interstitials_shown"]).is_equal(6)
	assert_int(fake.interstitials_shown).is_equal(6)


func test_random_gave_up_is_loss_without_softlock() -> void:
	# Seed 42 / 20 rounds: 18 wins, 2 losses. A loss = gave_up (restart limit hit):
	# the bot advances a level without coins, it is not a softlock.
	var bot := PlaytestBot.new()
	bot.max_restarts_per_round = 0
	var report: Dictionary = bot.run(20, 42, PlaytestBot.MODE_RANDOM)
	assert_int(report["rounds"]).is_equal(20)
	assert_int(report["softlocks"]).is_equal(0)
	assert_array(report["errors"]).is_empty()
	assert_int(report["wins"] + report["losses"]).is_equal(20)
	assert_int(report["losses"]).is_greater_equal(1)


func test_random_restarts_capped_per_round() -> void:
	# Seed 42 / 20 rounds: 5 restarts in total, the busiest round used all 2 allowed.
	var bot := PlaytestBot.new()
	bot.max_restarts_per_round = 2
	var report: Dictionary = bot.run(20, 42, PlaytestBot.MODE_RANDOM)
	assert_int(report["max_restarts_seen"]).is_less_equal(2)
	assert_int(report["restarts_total"]).is_greater_equal(1)


func _sum_values(d: Dictionary) -> int:
	var total: int = 0
	for v: int in d.values():
		total += v
	return total


func test_bracket_sums_match_totals() -> void:
	var bot := PlaytestBot.new()
	bot.max_restarts_per_round = 0
	var report: Dictionary = bot.run(30, 42, PlaytestBot.MODE_RANDOM)
	assert_int(_sum_values(report["rounds_by_bracket"])).is_equal(report["rounds"])
	assert_int(_sum_values(report["losses_by_bracket"])).is_equal(report["losses"])
	assert_array(report["rounds_by_bracket"].keys()).contains_exactly(
		["1-7", "8-25", "26-55", "56+"]
	)


func test_campaign_seed_uses_campaign_board() -> void:
	var bot := PlaytestBot.new()
	bot.use_campaign_seed = true
	bot.run(1, 42, PlaytestBot.MODE_SOLVER)
	var expected: Dictionary = ContentGenerator.new().generate(
		int(GameConfig.get_value("campaign_seed")), 1
	)
	assert_array(bot.last_level_data["payload"]["tubes"]).is_equal(expected["payload"]["tubes"])


func test_first_session_random_player_has_no_losses() -> void:
	var bot := PlaytestBot.new()
	bot.use_campaign_seed = true
	bot.max_restarts_per_round = 50
	var report: Dictionary = bot.run(7, 42, PlaytestBot.MODE_RANDOM)
	assert_int(report["rounds_by_bracket"]["1-7"]).is_equal(7)
	assert_int(report["losses_by_bracket"]["1-7"]).is_equal(0)


func test_score_move_completes_tube() -> void:
	var b := SortBoard.new([[1, 1, 1], [1], []], 4)
	assert_int(PlaytestBot.score_move(b, Vector2i(1, 0))).is_equal(3)


func test_score_move_same_color() -> void:
	var b := SortBoard.new([[1], [2, 1], []], 4)
	assert_int(PlaytestBot.score_move(b, Vector2i(1, 0))).is_equal(2)


func test_score_move_uniform_to_empty_is_negative() -> void:
	var b := SortBoard.new([[1, 1], [2, 1], []], 4)
	assert_int(PlaytestBot.score_move(b, Vector2i(0, 2))).is_equal(-2)


func test_score_move_neutral() -> void:
	var b := SortBoard.new([[1, 2], [3], []], 4)
	assert_int(PlaytestBot.score_move(b, Vector2i(0, 2))).is_equal(0)


func test_pick_greedy_avoids_undo() -> void:
	var b := SortBoard.new([[1, 2], [3, 2], []], 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var moves: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 2)]
	for _i in 20:
		var m: Vector2i = PlaytestBot.pick_greedy(b, moves, Vector2i(1, 0), rng)
		assert_bool(m == Vector2i(0, 1)).is_false()
	var only: Array[Vector2i] = [Vector2i(0, 1)]
	assert_bool(PlaytestBot.pick_greedy(b, only, Vector2i(1, 0), rng) == Vector2i(0, 1)).is_true()


func test_greedy_not_worse_than_random_on_campaign() -> void:
	for seed_value: int in [42, 7]:
		var greedy := PlaytestBot.new()
		greedy.use_campaign_seed = true
		var rep_g: Dictionary = greedy.run(
			GREEDY_VS_RANDOM_ROUNDS, seed_value, PlaytestBot.MODE_GREEDY
		)
		var rnd := PlaytestBot.new()
		rnd.use_campaign_seed = true
		var rep_r: Dictionary = rnd.run(
			GREEDY_VS_RANDOM_ROUNDS, seed_value, PlaytestBot.MODE_RANDOM
		)
		assert_str(rep_g["mode"]).is_equal("greedy")
		assert_int(rep_g["softlocks"]).is_equal(0)
		assert_that(rep_g["wins"] >= rep_r["wins"]).is_true()
		assert_int(rep_g["losses_by_bracket"]["1-7"]).is_equal(0)


func test_stay_lost_attempt_repeats_same_level() -> void:
	var bot := PlaytestBot.new()
	bot.stay_on_level = true
	bot.attempt_steps_limit = 1
	bot.use_campaign_seed = true
	var report: Dictionary = bot.run(3, 42, PlaytestBot.MODE_RANDOM)
	var expected: Dictionary = ContentGenerator.new().generate(
		int(GameConfig.get_value("campaign_seed")), 1
	)
	assert_array(bot.last_level_data["payload"]["tubes"]).is_equal(expected["payload"]["tubes"])
	assert_int(report["losses"]).is_equal(3)
	assert_int(report["rounds_by_bracket"]["1-7"]).is_equal(3)
	assert_int(report["attempts_by_bracket"]["1-7"]).is_equal(3)
	assert_int(report["skips_by_bracket"]["1-7"]).is_equal(0)
	# STAY_MAX_ATTEMPTS lost attempts in a row: the bot skips the level.
	var skipper := PlaytestBot.new()
	skipper.stay_on_level = true
	skipper.attempt_steps_limit = 1
	skipper.use_campaign_seed = true
	var rep_skip: Dictionary = skipper.run(
		PlaytestBot.STAY_MAX_ATTEMPTS, 42, PlaytestBot.MODE_RANDOM
	)
	assert_int(rep_skip["skips_by_bracket"]["1-7"]).is_equal(1)
	# start_level hook: plateau level 56 without playing 1..55.
	var plateau := PlaytestBot.new()
	plateau.start_level = 56
	plateau.stay_on_level = true
	plateau.use_campaign_seed = true
	plateau.attempt_steps_limit = 1
	var rep_plateau: Dictionary = plateau.run(3, 42, PlaytestBot.MODE_GREEDY)
	var expected_plateau: Dictionary = ContentGenerator.new().generate(
		int(GameConfig.get_value("campaign_seed")), 56
	)
	var tubes: Array = plateau.last_level_data["payload"]["tubes"]
	assert_array(tubes).is_equal(expected_plateau["payload"]["tubes"])
	assert_int(rep_plateau["rounds_by_bracket"]["56+"]).is_equal(3)


func _extra_tube_bot(from_attempt: int, min_level: int = 1) -> PlaytestBot:
	var bot := PlaytestBot.new()
	bot.stay_on_level = true
	bot.use_campaign_seed = true
	bot.attempt_steps_limit = 1
	bot.extra_tube_from_attempt = from_attempt
	bot.extra_tube_min_level = min_level
	return bot


func test_extra_tube_from_attempt_1_every_attempt() -> void:
	var report: Dictionary = _extra_tube_bot(1).run(4, 42, PlaytestBot.MODE_GREEDY)
	assert_int(report["rounds"]).is_equal(4)
	assert_int(report["extra_tubes_by_bracket"]["1-7"]).is_equal(4)
	assert_int(report["softlocks"]).is_equal(0)
	var rnd := GameRound.new()
	rnd.start(ContentGenerator.new().generate(1, 1))
	assert_bool(rnd.add_extra_tube()).is_true()
	assert_int(rnd.to_dict()["extra_tubes_added"]).is_equal(1)


func test_extra_tube_from_attempt_2_skips_first_attempt() -> void:
	var report: Dictionary = _extra_tube_bot(2).run(1, 42, PlaytestBot.MODE_GREEDY)
	assert_int(report["extra_tubes_by_bracket"]["1-7"]).is_equal(0)
	# attempt_steps_limit = 1 => every attempt is lost, so the level repeats: attempts 1..3.
	var three: Dictionary = _extra_tube_bot(2).run(3, 42, PlaytestBot.MODE_GREEDY)
	assert_int(three["attempts_by_bracket"]["1-7"]).is_equal(3)
	assert_int(three["extra_tubes_by_bracket"]["1-7"]).is_equal(2)


func test_tube_split_keys_and_four_brackets() -> void:
	var report: Dictionary = _extra_tube_bot(2).run(3, 42, PlaytestBot.MODE_GREEDY)
	for key: String in [
		"attempts_with_tube_by_bracket",
		"won_with_tube_by_bracket",
		"attempts_without_tube_by_bracket",
		"won_without_tube_by_bracket",
	]:
		assert_bool(report.has(key)).is_true()
		assert_int((report[key] as Dictionary).size()).is_equal(4)
	# from_attempt 2: attempt 1 without tube, attempts 2..3 with tube.
	assert_int(report["attempts_without_tube_by_bracket"]["1-7"]).is_equal(1)
	assert_int(report["attempts_with_tube_by_bracket"]["1-7"]).is_equal(2)


func test_tube_split_sums_match_attempts() -> void:
	var bot := PlaytestBot.new()
	bot.stay_on_level = true
	bot.use_campaign_seed = true
	bot.extra_tube_from_attempt = 2
	var report: Dictionary = bot.run(30, 42, PlaytestBot.MODE_GREEDY)
	for label: String in PlaytestBot.BRACKET_LABELS:
		var with_t: int = report["attempts_with_tube_by_bracket"][label]
		var without_t: int = report["attempts_without_tube_by_bracket"][label]
		assert_int(with_t + without_t).is_equal(report["attempts_by_bracket"][label])
		assert_int(report["won_with_tube_by_bracket"][label]).is_less_equal(with_t)
		assert_int(report["won_without_tube_by_bracket"][label]).is_less_equal(without_t)
		var won_sum: int = (
			int(report["won_with_tube_by_bracket"][label])
			+ int(report["won_without_tube_by_bracket"][label])
		)
		assert_int(won_sum).is_equal(report["levels_won_by_bracket"][label])


func test_extra_tube_below_min_level_not_added() -> void:
	var report: Dictionary = _extra_tube_bot(1, 5).run(3, 42, PlaytestBot.MODE_GREEDY)
	assert_int(report["extra_tubes_by_bracket"]["1-7"]).is_equal(0)
	var off: Dictionary = _extra_tube_bot(0).run(3, 42, PlaytestBot.MODE_GREEDY)
	assert_int(off["extra_tubes_by_bracket"]["1-7"]).is_equal(0)


func _stay_report() -> Dictionary:
	var bot := PlaytestBot.new()
	bot.stay_on_level = true
	bot.use_campaign_seed = true
	return bot.run(30, 42, PlaytestBot.MODE_GREEDY)


func test_stay_closed_levels_match_wins_plus_skips() -> void:
	var report: Dictionary = _stay_report()
	assert_int(report["softlocks"]).is_equal(0)
	var closed: int = (
		_sum_values(report["levels_won_by_bracket"]) + _sum_values(report["skips_by_bracket"])
	)
	assert_int(_sum_values(report["levels_won_by_bracket"])).is_equal(report["wins"])
	assert_int(closed).is_greater_equal(report["wins"])
	assert_int(_sum_values(report["attempts_by_bracket"])).is_equal(report["rounds"])
	for label: String in PlaytestBot.BRACKET_LABELS:
		assert_int(report["won_first_try_by_bracket"][label]).is_less_equal(
			report["won_within_3_by_bracket"][label]
		)
		assert_int(report["won_within_3_by_bracket"][label]).is_less_equal(
			report["levels_won_by_bracket"][label]
		)


func test_report_pct_keys_have_four_brackets() -> void:
	var report: Dictionary = PlaytestBot.new().run(2, 7)
	for key: String in ["won_le3_pct_by_bracket", "won_first_pct_by_bracket"]:
		assert_array(report[key].keys()).contains_exactly_in_any_order(PlaytestBot.BRACKET_LABELS)


func test_assist_gate_26_55_reduced_sample() -> void:
	var bot := PlaytestBot.new()
	bot.use_campaign_seed = true
	bot.stay_on_level = true
	bot.start_level = 26
	bot.extra_tube_min_level = int(GameConfig.get_value("plateau_assist_min_level"))
	bot.extra_tube_from_attempt = int(GameConfig.get_value("plateau_assist_from_attempt"))
	var report: Dictionary = bot.run(100, 42, PlaytestBot.MODE_GREEDY)
	assert_array(report["errors"]).is_empty()
	assert_float(report["won_le3_pct_by_bracket"]["26-55"]).is_greater_equal(GATE_26_55)


func _stuck_bot(mode: String, rounds: int, campaign: bool = true) -> Dictionary:
	var bot := PlaytestBot.new()
	bot.stay_on_level = true
	bot.use_campaign_seed = campaign
	return bot.run(rounds, 42, mode)


func test_stuck_attempts_bounded_by_stuck_count_and_attempts() -> void:
	var report: Dictionary = _stuck_bot(PlaytestBot.MODE_GREEDY, 60)
	var total: int = 0
	for label: String in PlaytestBot.BRACKET_LABELS:
		var s: int = report["stuck_attempts_by_bracket"][label]
		assert_int(s).is_less_equal(report["attempts_by_bracket"][label])
		total += s
	assert_int(total).is_less_equal(report["stuck_count"])


func test_stuck_attempts_zero_for_solver() -> void:
	var report: Dictionary = _stuck_bot(PlaytestBot.MODE_SOLVER, 20)
	for label: String in PlaytestBot.BRACKET_LABELS:
		assert_int(report["stuck_attempts_by_bracket"][label]).is_equal(0)
		assert_float(report["stuck_rate_pct_by_bracket"][label]).is_equal(0.0)


func test_stuck_rate_random_matches_formula() -> void:
	# Random, --stay, per-round seeds, seed 42, 20 rounds: 1 stuck attempt (bracket 8-25).
	# (With the campaign board 20 rounds give 0, 60 rounds give 7.)
	var report: Dictionary = _stuck_bot(PlaytestBot.MODE_RANDOM, 20, false)
	var total: int = 0
	for label: String in PlaytestBot.BRACKET_LABELS:
		var s: int = report["stuck_attempts_by_bracket"][label]
		var a: int = report["attempts_by_bracket"][label]
		total += s
		var expected: float = snappedf(100.0 * s / a, 0.1) if a > 0 else 0.0
		assert_float(report["stuck_rate_pct_by_bracket"][label]).is_equal(expected)
	assert_int(total).is_greater_equal(1)
