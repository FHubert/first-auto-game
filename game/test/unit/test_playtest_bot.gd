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
	"errors",
	"elapsed_ms",
]


func before_test() -> void:
	GameConfig.reset()


func after_test() -> void:
	GameConfig.reset()


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
