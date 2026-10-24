# gdlint: disable=max-public-methods
extends GdUnitTestSuite

const SAVE_PATH: String = "user://test_level_flow.json"
const FAKE_UNIX: int = 20750 * 86400 + 100

var _level: Level
var _old_path: String
var _coins_before: int
var _prev_provider: AdProvider
var _prev_clock: Callable
var _prev_shown: int


func before_test() -> void:
	_prev_provider = Ads.provider
	_prev_clock = Ads.clock
	_prev_shown = Ads.interstitials_shown
	Ads.reset_break()
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()
	_level = load("res://src/levels/level.tscn").instantiate()
	_level.state = GameState.new()
	_level.clock = func() -> int: return FAKE_UNIX
	_coins_before = _level.state.coins
	add_child(_level)


func after_test() -> void:
	if is_instance_valid(_level):
		_level.free()
	_cleanup()
	SaveSystem.save_path = _old_path
	Ads.provider = _prev_provider
	Ads.clock = _prev_clock
	Ads.interstitials_shown = _prev_shown
	Ads.reset_break()
	GameConfig.reset()


func _cleanup() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _solution() -> Array:
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	return ContentGenerator.new().generate(seed_value, 1)["payload"]["solution"]


func _win() -> void:
	var sol: Array = _solution()
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func test_hud_shows_level_and_moves() -> void:
	assert_str(_level.hud.level_label.text).contains("1")
	var m: Vector2i = _level.round.board().legal_moves()[0]
	_level.board.tap(m.x)
	_level.board.tap(m.y)
	assert_str(_level.hud.moves_label.text).contains("1")


func test_win_advances_level_and_pays_coins() -> void:
	_win()
	var st: GameState = _level.state
	var reward: int = int(GameConfig.get_value("win_reward_coins"))
	reward += int(GameConfig.get_value("par_bonus_coins"))
	assert_int(st.level).is_equal(2)
	assert_int(st.coins).is_equal(_coins_before + reward)
	assert_bool(_level.level_complete.visible).is_true()
	assert_int(st.levels_completed).is_equal(1)
	assert_int(st.streak_days).is_equal(1)


func test_win_beyond_par_has_no_perfect_bonus() -> void:
	GameConfig.apply_remote({"par_slack_moves": -1})
	_win()
	assert_bool(_level.round.moves() > _level.round.min_moves() - 1).is_true()
	assert_bool(_level.level_complete.perfect_label.visible).is_false()
	var reward: int = int(GameConfig.get_value("win_reward_coins"))
	assert_int(_level.state.coins).is_equal(_coins_before + reward)


func test_win_is_saved() -> void:
	_win()
	var loaded: GameState = SaveSystem.load()
	assert_int(loaded.level).is_equal(2)
	assert_int(loaded.coins).is_equal(_level.state.coins)


func test_win_clears_round_in_progress() -> void:
	_level.state.round_in_progress = {"mode": "campaign"}
	_win()
	assert_dict(_level.state.round_in_progress).is_empty()


func test_next_loads_following_level() -> void:
	_win()
	_level.on_next_pressed()
	assert_bool(_level.level_complete.visible).is_false()
	assert_str(_level.hud.level_label.text).contains("2")
	assert_int(_level.round.moves()).is_equal(0)
	var views: int = 0
	for c in _level.board.get_children():
		if c is TubeView and not c.is_queued_for_deletion():
			views += 1
	assert_int(views).is_equal(_level.round.board().tube_count())


func _open_interstitial_cap() -> void:
	Ads.provider = FakeAdProvider.new()
	var t: Array[float] = [1000000.0]
	Ads.clock = func() -> float: return t[0]
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


func test_next_shows_interstitial_when_cap_allows() -> void:
	_open_interstitial_cap()
	_win()
	var before: int = Ads.interstitials_shown
	_level.on_next_pressed()
	assert_int(Ads.interstitials_shown).is_equal(before + 1)


func test_next_no_interstitial_when_ads_removed() -> void:
	_open_interstitial_cap()
	_level.state.settings["ads_removed"] = true
	_win()
	var before: int = Ads.interstitials_shown
	_level.on_next_pressed()
	assert_int(Ads.interstitials_shown).is_equal(before)


func test_undo_and_restart() -> void:
	var charges: int = _level.round.undo_charges()
	var m: Vector2i = _level.round.board().legal_moves()[0]
	_level.board.tap(m.x)
	_level.board.tap(m.y)
	_level.undo()
	assert_int(_level.round.moves()).is_equal(0)
	assert_str(_level.hud.undo_button.text).contains(str(charges - 1))
	_level.board.tap(m.x)
	_level.board.tap(m.y)
	_level.restart()
	assert_int(_level.round.moves()).is_equal(0)
	assert_int(_level.state.level_restarts).is_equal(1)


func _win_level_two() -> void:
	_level.load_level(2)
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	var sol: Array = ContentGenerator.new().generate(seed_value, 2)["payload"]["solution"]
	for i in sol.size() - 1:
		_level.round.try_move(sol[i].x, sol[i].y)
	var last: Vector2i = sol[sol.size() - 1]
	_level.board.tap(last.x)
	_level.board.tap(last.y)


func test_double_coins_once_on_level_two() -> void:
	_win_level_two()
	assert_bool(_level.offers.can_double_coins()).is_true()
	var before: int = _level.state.coins
	var bonus: int = Economy.rewarded_bonus(_level._last_win_coins)
	assert_bool(_level.offers.watch_double_coins()).is_true()
	assert_int(_level.state.coins).is_equal(before + bonus)
	assert_bool(_level.offers.watch_double_coins()).is_false()
	assert_int(_level.state.coins).is_equal(before + bonus)


func test_double_coins_updates_progress_label() -> void:
	_win_level_two()
	var label: Label = _level.level_complete.progress_label
	assert_bool(label.visible).is_true()
	assert_bool(_level.offers.watch_double_coins()).is_true()
	var expected: Dictionary = LevelComplete.progress_message(2, _level.mode, _level.state)
	if expected["key"] == "lc_theme_progress":
		assert_str(label.text).is_equal(tr("lc_theme_progress") % expected["args"])
		assert_int(expected["args"][0]).is_equal(_level.state.coins)


func test_double_coins_not_on_level_one() -> void:
	_win()
	assert_bool(_level.offers.can_double_coins()).is_false()
	assert_bool(_level.offers.watch_double_coins()).is_false()


func test_watch_extra_tube_is_free() -> void:
	var coins: int = _level.state.coins
	var tubes: int = _level.round.board().tube_count()
	assert_bool(_level.offers.watch_extra_tube()).is_true()
	assert_int(_level.round.board().tube_count()).is_equal(tubes + 1)
	assert_int(_level.state.coins).is_equal(coins)
	assert_bool(_level.offers.watch_extra_tube()).is_false()


func test_watch_undo_refill_adds_charges() -> void:
	var before: int = _level.round.undo_charges()
	assert_bool(_level.offers.watch_undo_refill()).is_true()
	var amount: int = int(GameConfig.get_value("undo_refill_amount"))
	assert_int(_level.round.undo_charges()).is_equal(before + amount)


func test_double_button_flow() -> void:
	_win_level_two()
	var bonus: int = Economy.rewarded_bonus(_level._last_win_coins)
	var btn: Button = _level.level_complete.double_button
	assert_bool(btn.visible).is_true()
	assert_str(btn.text).contains(str(bonus))
	var before: int = _level.state.coins
	btn.pressed.emit()
	assert_int(_level.state.coins).is_equal(before + bonus)
	assert_bool(btn.visible).is_false()
	btn.pressed.emit()
	assert_int(_level.state.coins).is_equal(before + bonus)


func test_ad_buttons_hidden_when_no_ad_ready() -> void:
	var fake := FakeAdProvider.new()
	fake.always_ready = false
	Ads.provider = fake
	_level.load_level(2)
	assert_bool(_level.hud.extra_tube_ad_button.visible).is_false()
	assert_bool(_level.hud.undo_refill_ad_button.visible).is_false()
	_win_level_two()
	assert_bool(_level.level_complete.double_button.visible).is_false()


func test_hud_ad_button_visible_when_ready() -> void:
	_level.load_level(2)
	assert_bool(_level.hud.extra_tube_ad_button.visible).is_true()


func test_win_panel_below_board_aso_win() -> void:
	_level.state = ScreenshotFixtures.make("aso_win", 20750)
	_level.size = Vector2(720, 1280)
	_level.load_level(_level.state.level, _level.state.theme_active)
	ScreenshotFixtures.apply_win(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Rect2 = _level.level_complete.panel_rect()
	assert_float(panel.size.y).is_less_equal(640.0)
	var tubes: Rect2 = _level.board.tube_rect(0)
	for i in _level.round.board().tube_count():
		tubes = tubes.merge(_level.board.tube_rect(i))
	assert_bool(panel.intersects(tubes)).is_false()
	_level.load_level(_level.state.level, _level.state.theme_active)
	assert_float(_level.board.offset_top).is_equal(0.0)
	assert_float(_level.board.offset_bottom).is_equal(0.0)


func test_win_prefetches_next_level() -> void:
	_level.prefetch = LevelPrefetch.new()
	_win()
	_level.load_level(_level.state.level, _level.state.theme_active)
	assert_int(_level.level_no).is_equal(2)
	assert_int(_level.prefetch.sync_generations).is_equal(0)
