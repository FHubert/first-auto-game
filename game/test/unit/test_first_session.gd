extends GdUnitTestSuite
## Straznik pierwszej sesji przez App: tutorial -> poziomy 1..5 sciezka solvera (T-168).

const SAVE_PATH: String = "user://test_first_session.json"
const FIRST_SESSION_LEVELS: int = 5
const SOLVER_MAX_STATES: int = 20000
const TUTORIAL_EVENTS: Array[String] = [
	"tutorial:step:1", "tutorial:step:2", "tutorial:step:3", "tutorial:done"
]

var _old_path: String
var _prev_analytics: AnalyticsProvider
var _prev_ads: AdProvider
var _fake: FakeAnalyticsProvider
var _notif: FakeNotificationProvider
var _t: Array[int] = [TestClock.FIXED_UNIX]
var _start_coins: int = 0
var _first_win_coins: int = 0
var _badge_seen: bool = false
var _popup_seen: bool = false
var _daily_card_seen: bool = false
var _interstitials_before: int = 0


func before_test() -> void:
	GameConfig.reset()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	_cleanup()
	_prev_analytics = Analytics.provider
	_fake = FakeAnalyticsProvider.new()
	Analytics.provider = _fake
	_prev_ads = Ads.provider
	Ads.provider = FakeAdProvider.new()
	_interstitials_before = Ads.interstitials_shown
	_notif = FakeNotificationProvider.new()
	_t = [TestClock.FIXED_UNIX]
	_badge_seen = false
	_daily_card_seen = false
	_popup_seen = false


func after_test() -> void:
	Analytics.provider = _prev_analytics
	Ads.provider = _prev_ads
	Ads.interstitials_shown = _interstitials_before
	_cleanup()
	SaveSystem.save_path = _old_path
	GameConfig.reset()


func _cleanup() -> void:
	TestSaveCleanup.remove(SAVE_PATH)


func _new_app() -> App:
	var app: App = auto_free(App.new())
	app.clock = TestClock.ticking(_t)
	app.effects_enabled = false
	app.notifications = _notif
	app.state = SaveSystem.fresh_state()  # jak nowy gracz (starting_coins, T-173)
	add_child(app)
	return app


func _win_current_level(app: App) -> void:
	var level := app.current_screen() as Level
	var path: Array = SortSolver.solve(level.round.board(), SOLVER_MAX_STATES, 1.0)["path"]
	for m: Vector2i in path:
		level.board.tap(m.x)
		level.board.tap(m.y)
	assert_bool(level.level_complete.visible).is_true()


func _play_first_session() -> App:
	var app := _new_app()
	_start_coins = app.state.coins
	var unlock: int = int(GameConfig.get_value("daily_unlock_level"))
	for n in range(1, FIRST_SESSION_LEVELS + 1):
		assert_int((app.current_screen() as Level).level_no).is_equal(n)
		_win_current_level(app)
		if n == 1:
			_first_win_coins = app.state.coins
		if n == unlock:
			(app.current_screen() as Level).home_requested.emit()
			var home := app.current_screen() as Home
			_popup_seen = app.popup_visible()
			app._popup.closed.emit()
			_daily_card_seen = home.daily_card.visible and not home.daily_button.disabled
			_badge_seen = home.daily_new_badge.visible
			app.show_level()
		else:
			(app.current_screen() as Level).on_next_pressed()
	return app


func _ids(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in _fake.events:
		var id: String = str(e.get("event_id", ""))
		if e.get("type", "") == "design" and id.begins_with(prefix):
			out.append(id)
	return out


func test_tutorial_events_in_order_once() -> void:
	_play_first_session()
	var seen: Array[String] = []
	for id in _ids("tutorial:"):
		if id in TUTORIAL_EVENTS:
			seen.append(id)
	assert_array(seen).is_equal(TUTORIAL_EVENTS)


func test_five_completions_and_no_interstitial() -> void:
	_play_first_session()
	var completes: int = 0
	for id in _ids("level:complete:"):
		if id == "level:complete:normal" or id == "level:complete:perfect":
			completes += 1
	assert_int(completes).is_equal(FIRST_SESSION_LEVELS)
	assert_int(_ids("ads:interstitial:shown").size()).is_equal(0)
	assert_int(Ads.interstitials_shown).is_equal(_interstitials_before)
	assert_int(FIRST_SESSION_LEVELS).is_less(int(GameConfig.get_value("interstitial_min_level")))


func test_first_win_pays_reward() -> void:
	var app := _play_first_session()
	var reward: int = int(GameConfig.get_value("win_reward_coins"))
	var bonus: int = int(GameConfig.get_value("par_bonus_coins"))
	var start: int = int(GameConfig.get_value("starting_coins"))
	# T-173: nowy gracz startuje z starting_coins (wczesniej martwy klucz, saldo 0).
	assert_int(_start_coins).is_equal(start)
	var gained: int = _first_win_coins - start
	assert_bool(gained == reward or gained == reward + bonus).is_true()
	assert_int(app.state.levels_completed).is_equal(FIRST_SESSION_LEVELS)


func test_daily_card_and_badge_after_unlock_level() -> void:
	_play_first_session()
	assert_bool(_popup_seen).is_true()
	assert_bool(_daily_card_seen).is_true()
	assert_bool(_badge_seen).is_true()


func test_progress_saved_to_disk() -> void:
	_play_first_session()
	var loaded: GameState = SaveSystem.load()
	assert_int(loaded.level).is_equal(FIRST_SESSION_LEVELS + 1)
	assert_bool(loaded.settings[GameState.SETTING_TUTORIAL_DONE]).is_true()


func test_focus_out_schedules_notification() -> void:
	var app := _play_first_session()
	assert_int(_notif.scheduled.size()).is_equal(0)
	app.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(_notif.scheduled.size()).is_greater_equal(1)
	assert_int((app.current_screen() as Level).level_no).is_equal(FIRST_SESSION_LEVELS + 1)
