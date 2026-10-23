extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_analytics_events.json"
const FAKE_UNIX: int = 20750 * 86400 + 100

var _level: Level
var _fake: FakeAnalyticsProvider
var _prev_analytics: AnalyticsProvider
var _prev_provider: AdProvider
var _prev_clock: Callable
var _prev_shown: int
var _old_path: String


func before_test() -> void:
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	_prev_provider = Ads.provider
	_prev_clock = Ads.clock
	_prev_shown = Ads.interstitials_shown
	GameConfig.reset()
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
	Ads.provider = FakeAdProvider.new()
	Ads.clock = func() -> float: return 1000000.0
	Ads.reset_break()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.state.settings["tutorial_done"] = true
	_level.clock = func() -> int: return FAKE_UNIX
	add_child(_level)


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	_cleanup()
	SaveSystem.save_path = _old_path
	Analytics.provider = _prev_analytics
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	Ads.interstitials_shown = _prev_shown
	Ads.reset_break()
	GameConfig.reset()


func _cleanup() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _win_level(no: int) -> void:
	_level.load_level(no)
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	var sol: Array = ContentGenerator.new().generate(seed_value, no)["payload"]["solution"]
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func _find(type: String, key: String, value: String, from: int = 0) -> int:
	for i in range(from, _fake.events.size()):
		var e: Dictionary = _fake.events[i]
		if e["type"] == type and str(e.get(key, "")) == value:
			return i
	return -1


func _has_design(id: String) -> bool:
	return _find("design", "event_id", id) >= 0


func test_start_complete_double_next_sequence() -> void:
	_fake.events.clear()
	_win_level(2)
	var mm: int = _level.round.min_moves()
	var i_start: int = _find("progression", "status", "Start")
	assert_int(i_start).is_greater_equal(0)
	assert_str(_fake.events[i_start]["l1"]).is_equal("campaign")
	assert_str(_fake.events[i_start]["l2"]).is_equal("level_0002")
	var i_ls: int = _find("design", "event_id", "level:start", i_start)
	assert_int(i_ls).is_greater(i_start)
	assert_float(_fake.events[i_ls]["value"]).is_equal(float(mm))
	var i_done: int = _find("progression", "status", "Complete", i_ls)
	assert_int(i_done).is_greater(i_ls)
	assert_int(_fake.events[i_done]["score"]).is_equal(_level.round.moves())
	var i_win: int = _find("resource", "item_id", "win", i_ls)
	assert_int(i_win).is_greater(i_ls)
	assert_int(i_win).is_less(i_done)
	assert_str(_fake.events[i_win]["flow"]).is_equal("Source")
	assert_float(_fake.events[i_win]["amount"]).is_equal(
		float(GameConfig.get_value("win_reward_coins"))
	)
	assert_str(_fake.events[i_win]["item_type"]).is_equal("economy")
	var perfect: bool = bool(_level.round.result().get("perfect", false))
	assert_bool(_find("resource", "item_id", "perfect", i_ls) >= 0).is_equal(perfect)
	var bonus: int = _level.double_coins_bonus()
	assert_bool(_level.watch_double_coins()).is_true()
	var i_off: int = _find("design", "event_id", "ads:rewarded:double_coins:offered", i_done)
	var i_grant: int = _find("design", "event_id", "ads:rewarded:double_coins:granted", i_off)
	var i_rew: int = _find("resource", "item_id", "rewarded", i_grant)
	assert_int(i_off).is_greater_equal(0)
	assert_int(i_grant).is_greater(i_off)
	assert_int(i_rew).is_greater(i_grant)
	assert_float(_fake.events[i_rew]["amount"]).is_equal(float(bonus))
	_level.on_next_pressed()
	assert_bool(_has_design("ads:interstitial:shown")).is_false()
	var i_next: int = _find("progression", "status", "Start", i_rew)
	assert_int(i_next).is_greater(i_rew)
	assert_str(_fake.events[i_next]["l2"]).is_equal("level_%04d" % _level.state.level)


func test_next_without_double_shows_interstitial() -> void:
	_win_level(2)
	_fake.events.clear()
	_level.on_next_pressed()
	var i: int = _find("design", "event_id", "ads:interstitial:shown")
	assert_int(i).is_greater_equal(0)
	assert_float(_fake.events[i]["value"]).is_equal(2.0)


func test_quit_mid_round_is_fail() -> void:
	_fake.events.clear()
	_level.quit_level()
	assert_str(_fake.events[0]["status"]).is_equal("Fail")
	assert_bool(_has_design("level:fail:quit")).is_true()


func test_pause_reports_quit() -> void:
	_fake.events.clear()
	_level.pause()
	assert_bool(_has_design("level:fail:quit")).is_true()


func test_quit_after_win_is_silent() -> void:
	_win_level(2)
	_fake.events.clear()
	_level.quit_level()
	assert_int(_fake.events.size()).is_equal(0)


func test_restart_reports_fail_restart() -> void:
	_fake.events.clear()
	_level.restart()
	assert_str(_fake.events[0]["status"]).is_equal("Fail")
	assert_bool(_has_design("level:fail:restart")).is_true()


func test_skip_reports_fail_skip() -> void:
	for i in int(GameConfig.get_value("skip_unlock_restarts")):
		_level.restart()
	assert_bool(_level.round.can_skip()).is_true()
	_fake.events.clear()
	_level.skip_level()
	assert_bool(_has_design("level:fail:skip")).is_true()
	assert_bool(_has_design("level:skip:free")).is_true()


func test_report_consent() -> void:
	_fake.events.clear()
	Ads.report_consent("ump", "granted")
	assert_str(_fake.events[0]["event_id"]).is_equal("consent:ump:granted")
