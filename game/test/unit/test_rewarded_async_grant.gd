extends GdUnitTestSuite
## T-197: kazdy z 6 placementow rewarded przez realnego wolajacego przy providerze, ktory
## odpowiada dopiero w pozniejszej klatce (jak AdMob). Nagroda: dokladnie raz, po klatce.

const SAVE_PATH: String = "user://test_rewarded_async_grant.json"
const DAY: int = 20750
const HARD_LEVEL: int = 56
const FRAMES: int = 2

var _level: Level
var _old_path: String
var _prev_provider: AdProvider
var _prev_an: AnalyticsProvider
var _prev_clock: Callable
var _fake_ads: FakeAdProvider
var _fake_an: FakeAnalyticsProvider
var _now: Array[int] = [DAY * 86400 + 3600]


func before_test() -> void:
	GameConfig.reset()
	_prev_provider = Ads.provider
	_prev_clock = Ads.clock
	_prev_an = Analytics.provider
	_fake_an = FakeAnalyticsProvider.new()
	Analytics.provider = _fake_an
	_fake_ads = FakeAdProvider.new()
	_fake_ads.deferred = true
	Ads.provider = _fake_ads
	Ads.reset_break()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)
	_now[0] = DAY * 86400 + 3600


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	Analytics.provider = _prev_an
	Ads.reset_break()
	GameConfig.reset()


func _frames() -> void:
	for i in FRAMES:
		await get_tree().process_frame


func _count(id: String) -> int:
	var n: int = 0
	for e: Dictionary in _fake_an.events:
		if str(e.get("event_id", "")) == id:
			n += 1
	return n


func _new_level(level_no: int, restarts: int = 0) -> void:
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	_level.clock = TestClock.fixed()
	_level.autoload_level = false
	add_child(_level)
	UiTestFit.fit_root(_level, Vector2(720, 1280))
	_level.load_level(level_no)
	for i in restarts:
		_level.restart()


func _win_level_two() -> void:
	_new_level(2)
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	var sol: Array = ContentGenerator.new().generate(seed_value, 2)["payload"]["solution"]
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func _app(state: GameState) -> App:
	var app: App = auto_free(App.new())
	app.state = state
	app.state.settings["tutorial_done"] = true
	app.clock = func() -> int: return _now[0]
	add_child(app)
	return app


func _popup(app: App) -> DailyRewardPopup:
	for c in app.get_children():
		if c is DailyRewardPopup:
			return c
	return null


func _tubes() -> int:
	return _level.round.board().tube_count()


func test_double_coins_level_complete_button() -> void:
	_win_level_two()
	var before: int = _level.state.coins
	var bonus: int = _level.offers.double_coins_bonus()
	assert_int(bonus).is_greater(0)
	_level.level_complete.double_pressed.emit()
	assert_int(_level.state.coins).is_equal(before)
	assert_int(_level.rewarded.granted_count("double_coins")).is_equal(0)
	await _frames()
	assert_int(_level.state.coins).is_equal(before + bonus)
	assert_int(_level.rewarded.granted_count("double_coins")).is_equal(1)
	assert_int(_count("ads:rewarded:double_coins:granted")).is_equal(1)
	assert_int(_fake_ads.releases).is_equal(1)


func test_extra_tube_hud_button() -> void:
	_new_level(HARD_LEVEL)
	var tubes: int = _tubes()
	_level.hud.extra_tube_ad_pressed.emit()
	assert_int(_tubes()).is_equal(tubes)
	assert_int(_level.rewarded.granted_count("extra_tube")).is_equal(0)
	await _frames()
	assert_int(_tubes()).is_equal(tubes + 1)
	assert_int(_level.rewarded.granted_count("extra_tube")).is_equal(1)
	assert_int(_count("ads:rewarded:extra_tube:granted")).is_equal(1)
	assert_int(_count("booster:extra_tube:rewarded")).is_equal(1)


func test_extra_tube_stuck_panel_button() -> void:
	_new_level(HARD_LEVEL)
	var tubes: int = _tubes()
	_level.stuck_panel.extra_tube_ad_pressed.emit()
	assert_int(_tubes()).is_equal(tubes)
	await _frames()
	assert_int(_tubes()).is_equal(tubes + 1)
	assert_int(_level.rewarded.granted_count("extra_tube")).is_equal(1)
	assert_int(_count("booster:extra_tube:rewarded")).is_equal(1)
	assert_int(_count("level:assist:rewarded")).is_equal(0)


func test_extra_tube_assist_bar_button() -> void:
	_new_level(HARD_LEVEL, 2)
	assert_bool(_level.assist_bar.visible).is_true()
	var tubes: int = _tubes()
	_level.assist_bar.ad_button.pressed.emit()
	assert_int(_tubes()).is_equal(tubes)
	assert_int(_count("level:assist:rewarded")).is_equal(0)
	await _frames()
	assert_int(_tubes()).is_equal(tubes + 1)
	assert_int(_level.rewarded.granted_count("extra_tube")).is_equal(1)
	assert_int(_count("level:assist:rewarded")).is_equal(1)
	assert_int(_count("ads:rewarded:extra_tube:granted")).is_equal(1)
	assert_bool(_level.assist_bar.visible).is_false()


func test_undo_refill_stuck_panel_button() -> void:
	_new_level(HARD_LEVEL)
	var charges: int = _level.round.counters.undo_charges
	var amount: int = int(GameConfig.get_value("undo_refill_amount"))
	_level.stuck_panel.undo_refill_ad_pressed.emit()
	assert_int(_level.round.counters.undo_charges).is_equal(charges)
	await _frames()
	assert_int(_level.round.counters.undo_charges).is_equal(charges + amount)
	assert_int(_level.rewarded.granted_count("undo_refill")).is_equal(1)
	assert_int(_count("ads:rewarded:undo_refill:granted")).is_equal(1)
	assert_int(_count("booster:undo_refill:rewarded")).is_equal(1)


func test_skip_level_stuck_panel_button() -> void:
	var need: int = int(GameConfig.get_value("skip_unlock_restarts"))
	_new_level(HARD_LEVEL, need)
	var lvl: int = _level.state.level
	_level.stuck_panel.skip_pressed.emit()
	assert_int(_level.state.level).is_equal(lvl)
	await _frames()
	assert_int(_level.state.level).is_equal(lvl + 1)
	# load_level() resets per-level counters, so the grant is visible via analytics only.
	assert_int(_count("ads:rewarded:skip_level:granted")).is_equal(1)
	assert_int(_count("level:skip:rewarded")).is_equal(1)


func test_daily_x2_popup_button() -> void:
	var app := _app(GameState.new())
	var popup := _popup(app)
	var rw: RewardedPlacements = popup.rewarded
	var expected: int = popup.preview_x2_amount()
	popup.claim_x2_button.pressed.emit()
	assert_int(app.state.coins).is_equal(0)
	assert_int(app.state.daily_reward_last_claim_day).is_not_equal(DAY)
	await _frames()
	assert_int(app.state.coins).is_equal(expected)
	assert_int(app.state.daily_reward_last_claim_day).is_equal(DAY)
	assert_int(rw.granted_count("daily_x2")).is_equal(1)
	assert_int(_count("ads:rewarded:daily_x2:granted")).is_equal(1)


func test_streak_save_popup_button() -> void:
	var state := GameState.new()
	state.streak_days = 3
	state.last_play_utc_day = DAY - 2
	state.daily_reward_last_claim_day = DAY - 2
	var app := _app(state)
	var popup := _popup(app)
	var rw: RewardedPlacements = popup.rewarded
	assert_bool(popup.save_streak_button.visible).is_true()
	popup.save_streak_button.pressed.emit()
	assert_bool(DailyRewards.can_save_streak(state, DAY)).is_true()
	assert_int(state.streak_saves_used).is_equal(0)
	await _frames()
	assert_bool(DailyRewards.can_save_streak(state, DAY)).is_false()
	assert_int(state.streak_saves_used).is_equal(1)
	assert_int(rw.granted_count("streak_save")).is_equal(1)
	assert_int(_count("ads:rewarded:streak_save:granted")).is_equal(1)


func test_deferred_not_granted_gives_no_reward() -> void:
	_fake_ads.reward_on_show = false
	_new_level(HARD_LEVEL, 2)
	var tubes: int = _tubes()
	_level.assist_bar.ad_button.pressed.emit()
	await _frames()
	assert_int(_fake_ads.releases).is_equal(1)
	assert_int(_tubes()).is_equal(tubes)
	assert_int(_level.rewarded.granted_count("extra_tube")).is_equal(0)
	assert_int(_count("ads:rewarded:extra_tube:skipped")).is_equal(1)
	assert_int(_count("level:assist:rewarded")).is_equal(0)
	assert_bool(_level.assist_bar.visible).is_true()
