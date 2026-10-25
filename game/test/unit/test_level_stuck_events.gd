extends GdUnitTestSuite
## T-254: `level:stuck` (wartosc = ruchy), `level:stuck:<przedzial>` (wartosc = proba), 1x/probe.

const LEVEL_NO: int = 30
const BRACKET: String = "lv26_55"

var _prev_analytics: AnalyticsProvider
var _fake: FakeAnalyticsProvider


func before_test() -> void:
	GameConfig.reset()
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake


func after_test() -> void:
	Analytics.provider = _prev_analytics
	GameConfig.reset()


func _deadlock_data() -> Dictionary:
	var payload: Dictionary = {
		"capacity": 4,
		"colors": 2,
		"tubes": [[0, 1, 0, 1], [1, 0, 1, 0]],
		"min_moves": 1,
		"min_moves_exact": true,
		"solution": [],
	}
	return {"seed": 1, "level": LEVEL_NO, "difficulty": 0.0, "payload": payload}


func _level(daily: bool) -> Level:
	var level: Level = auto_free(load("res://src/levels/level.tscn").instantiate())
	level.state = SaveSystem.fresh_state()
	level.state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	add_child(level)
	if daily:
		level.mode = Level.MODE_DAILY
	level.level_no = LEVEL_NO
	level.start_round(_deadlock_data())
	level._check_stuck()
	return level


func _values(id: String) -> Array:
	var out: Array = []
	for e: Dictionary in _fake.events:
		if str(e.get("event_id", "")) == id:
			out.append(float(e["value"]))
	return out


func test_campaign_deadlock_reports_moves_and_first_attempt() -> void:
	_level(false)
	assert_array(_values("level:stuck")).contains_exactly([0.0])
	assert_array(_values("level:stuck:" + BRACKET)).contains_exactly([1.0])


func test_restart_is_second_attempt_and_same_attempt_is_not_repeated() -> void:
	var level := _level(false)
	level.restart()
	assert_array(_values("level:stuck:" + BRACKET)).contains_exactly([1.0, 2.0])
	var count: int = _values("level:stuck").size()
	level._check_stuck()
	assert_int(_values("level:stuck").size()).is_equal(count)
	assert_array(_values("level:stuck:" + BRACKET)).contains_exactly([1.0, 2.0])


func test_daily_has_no_bracket_event() -> void:
	_level(true)
	assert_array(_values("level:stuck")).has_size(1)
	for e: Dictionary in _fake.events:
		assert_bool(str(e.get("event_id", "")).begins_with("level:stuck:")).is_false()
