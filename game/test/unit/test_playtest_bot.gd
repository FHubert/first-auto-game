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
]

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
	var greedy := PlaytestBot.new()
	greedy.use_campaign_seed = true
	var rep_g: Dictionary = greedy.run(20, 42, PlaytestBot.MODE_GREEDY)
	var rnd := PlaytestBot.new()
	rnd.use_campaign_seed = true
	var rep_r: Dictionary = rnd.run(20, 42, PlaytestBot.MODE_RANDOM)
	assert_str(rep_g["mode"]).is_equal("greedy")
	assert_int(rep_g["softlocks"]).is_equal(0)
	assert_int(rep_g["wins"]).is_greater_equal(rep_r["wins"])
	assert_int(rep_g["losses_by_bracket"]["1-7"]).is_equal(0)
