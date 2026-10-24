extends GdUnitTestSuite

const KEYS: Array = [
	"mode",
	"rounds",
	"wins",
	"losses",
	"softlocks",
	"stuck_count",
	"restarts_total",
	"avg_moves",
	"avg_steps",
	"perfect_count",
	"coins_end",
	"interstitials_shown",
	"interstitial_calls",
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
	Ads._last_interstitial_s = -INF
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
