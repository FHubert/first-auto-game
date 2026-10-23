class_name Level
extends Control
## Scena poziomu: generuje poziom, uruchamia GameRound, HUD, wygrana i zapis.

signal level_won(level_no: int, coins: int)
signal next_requested(level_no: int)
signal pause_requested
signal home_requested
signal shop_requested(reason: String)

const MODE_CAMPAIGN: String = "campaign"
const MODE_DAILY: String = "daily"

@export var level: int = 2

var round: GameRound
var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var mode: String = MODE_CAMPAIGN
var level_no: int = 1
var utc_day: int = 0
var tutorial: TutorialFlow
var rewarded: RewardedPlacements = RewardedPlacements.new()

var _last_win_coins: int = 0
var _last_win_perfect: bool = false
var _last_win_title: String = ""

@onready var board: BoardView = $Board
@onready var hud: Hud = $Hud
@onready var level_complete: LevelComplete = $LevelComplete
@onready var stuck_panel: StuckPanel = $StuckPanel
@onready var tutorial_overlay: TutorialOverlay = $TutorialOverlay


func _ready() -> void:
	if state == null:
		state = SaveSystem.load()
	board.round_won.connect(_on_round_won)
	board.pour_finished.connect(
		func(_from: int, _to: int) -> void:
			hud.refresh()
			_refresh_offers()
			_check_stuck()
	)
	board.pour_finished.connect(
		func(_from: int, _to: int) -> void:
			Audio.play_sfx("pour")
			Audio.haptic()
	)
	board.illegal_move.connect(func(_from: int, _to: int) -> void: Audio.play_sfx("error"))
	board.tube_selected.connect(_on_tutorial_selected)
	board.pour_finished.connect(_on_tutorial_pour)
	hud.hint_pressed.connect(buy_hint)
	hud.extra_tube_pressed.connect(buy_extra_tube)
	stuck_panel.undo_pressed.connect(undo)
	stuck_panel.extra_tube_pressed.connect(buy_extra_tube)
	stuck_panel.undo_refill_pressed.connect(buy_undo_refill)
	hud.extra_tube_ad_pressed.connect(func() -> void: watch_extra_tube())
	hud.undo_refill_ad_pressed.connect(func() -> void: watch_undo_refill())
	stuck_panel.extra_tube_ad_pressed.connect(func() -> void: watch_extra_tube())
	stuck_panel.undo_refill_ad_pressed.connect(func() -> void: watch_undo_refill())
	level_complete.double_pressed.connect(func() -> void: watch_double_coins())
	stuck_panel.restart_pressed.connect(restart)
	stuck_panel.skip_pressed.connect(watch_skip)
	hud.undo_pressed.connect(undo)
	hud.restart_pressed.connect(restart)
	hud.pause_pressed.connect(pause)
	level_complete.next_pressed.connect(on_next_pressed)
	level_complete.home_pressed.connect(func() -> void: home_requested.emit())
	if round == null:
		load_level(state.level, state.theme_active)


func load_level(level_in: int, theme_id: String = "classic") -> void:
	mode = MODE_CAMPAIGN
	hud.set_title("")
	level_no = level_in
	var seed_value: int = int(GameConfig.get_value("campaign_seed", 1))
	start_round(ContentGenerator.new().generate(seed_value, level_no), theme_id)


## Poziom dnia: bez "pomin", bez podnoszenia state.level.
func start_daily(day: int) -> void:
	mode = MODE_DAILY
	utc_day = day
	level_no = day
	start_round(DailyChallenge.level_for_day(day), state.theme_active)
	hud.set_title(tr("hud_daily"))


func start_round(level_data: Dictionary, theme_id: String = "classic") -> void:
	rewarded.reset()
	round = GameRound.new()
	round.start(level_data)
	board.setup(round, theme_id)
	hud.bind(round, level_no)
	stuck_panel.visible = false
	tutorial = null
	if level_no == 1 and not bool(state.settings.get("tutorial_done", false)):
		tutorial = TutorialFlow.new()
		tutorial.start(_solver_first_move())
	_update_tutorial_overlay()
	_refresh_offers()


func on_next_pressed() -> void:
	if mode == MODE_DAILY:
		level_complete.visible = false
		home_requested.emit()
		return
	level_complete.visible = false
	load_level(state.level, state.theme_active)
	next_requested.emit(state.level)


func _process(_delta: float) -> void:
	if tutorial != null and board.selected_index() == -1:
		if tutorial.step == TutorialFlow.Step.PICK_TARGET:
			tutorial.on_deselect()
			_update_tutorial_overlay()


## Pierwszy ruch solvera z biezacego stanu (bez liczenia podpowiedzi).
func _solver_first_move() -> Vector2i:
	var max_states: int = int(GameConfig.get_value("hint_solver_max_states"))
	var path: Array = SortSolver.solve(round.board(), max_states, 1.0).get("path", [])
	if path.is_empty():
		return GameRound.NO_HINT
	return path[0]


func _on_tutorial_selected(index: int) -> void:
	if tutorial != null and tutorial.on_tube_selected(index):
		_update_tutorial_overlay()


func _on_tutorial_pour(from: int, to: int) -> void:
	if tutorial == null:
		return
	var next_move: Vector2i = GameRound.NO_HINT
	if not round.is_done():
		next_move = _solver_first_move()
	if not tutorial.on_pour(from, to, next_move, round.is_done()):
		if round.is_done():
			tutorial.step = TutorialFlow.Step.DONE
		else:
			tutorial.start(next_move)
	_update_tutorial_overlay()


func _update_tutorial_overlay() -> void:
	var active: bool = tutorial != null and not tutorial.is_done()
	hud.set_boosters_visible(not active)
	if active:
		var idx: int = tutorial.highlight()
		if idx >= 0 and idx < round.board().tube_count():
			tutorial_overlay.point_at(board.tube_rect(idx), tutorial.message())
		return
	tutorial_overlay.hide_hand()
	if tutorial != null:
		state.settings["tutorial_done"] = true
		SaveSystem.save(state)
		Analytics.track_design("tutorial:done")
		tutorial = null


func undo() -> void:
	round.undo()
	_after_action()


func restart() -> void:
	round.restart()
	state.level_restarts += 1
	_after_action()
	Analytics.track_progression("Fail", mode, _level_id())


func buy_extra_tube() -> bool:
	var ok: bool = Boosters.buy_extra_tube(state, round)
	if not ok and not Economy.can_afford(state, Economy.extra_tube_cost()):
		shop_requested.emit(Economy.SINK_EXTRA_TUBE)
	return _finish_purchase(ok)


func buy_undo_refill() -> bool:
	var ok: bool = Boosters.buy_undo_refill(state, round)
	if not ok:
		shop_requested.emit(Economy.SINK_UNDO_REFILL)
	return _finish_purchase(ok)


## Podswietla zrodlo podpowiedzi (podnosi probowke); ruchu nie wykonuje.
func buy_hint() -> bool:
	var m: Vector2i = Boosters.buy_hint(state, round)
	var ok: bool = m != GameRound.NO_HINT
	if not ok and not Economy.can_afford(state, Economy.hint_cost()):
		shop_requested.emit(Economy.SINK_HINT)
	if ok and board.selected_index() == -1:
		board.tap(m.x)
	return _finish_purchase(ok)


## Skip without an ad (kept for tests/debug); the UI uses watch_skip.
func skip_level() -> void:
	if mode == MODE_DAILY or not round.can_skip():
		return
	_apply_skip("level:skip:free")


func watch_skip() -> bool:
	if mode == MODE_DAILY or not round.can_skip():
		return false
	return rewarded.offer(
		RewardedPlacements.SKIP_LEVEL, func() -> void: _apply_skip("level:skip:rewarded")
	)


func can_double_coins() -> bool:
	if not round.is_done() or _last_win_coins <= 0:
		return false
	var min_level: int = int(GameConfig.get_value("rewarded_double_coins_min_level"))
	if mode != MODE_DAILY and level_no < min_level:
		return false
	return rewarded.can_offer(RewardedPlacements.DOUBLE_COINS)


func double_coins_bonus() -> int:
	return Economy.rewarded_bonus(_last_win_coins) if can_double_coins() else 0


func watch_double_coins() -> bool:
	if not can_double_coins():
		return false
	var bonus: int = double_coins_bonus()
	return rewarded.offer(
		RewardedPlacements.DOUBLE_COINS,
		func() -> void:
			Economy.earn(state, bonus, Economy.SOURCE_REWARDED)
			SaveSystem.save(state)
			level_complete.show_result(
				_last_win_coins + bonus, _last_win_perfect, level_no, _last_win_title
			)
			level_complete.set_double_offer(0, false)
			hud.refresh()
			Audio.play_sfx("coins")
	)


func watch_extra_tube() -> bool:
	if round.is_done() or not round.can_add_extra_tube():
		return false
	return rewarded.offer(
		RewardedPlacements.EXTRA_TUBE,
		func() -> void:
			round.add_extra_tube()
			Analytics.track_design("booster:extra_tube:rewarded")
			_after_action()
	)


func watch_undo_refill() -> bool:
	if round.is_done():
		return false
	return rewarded.offer(
		RewardedPlacements.UNDO_REFILL,
		func() -> void:
			round.add_undo_charges(int(GameConfig.get_value("undo_refill_amount")))
			Analytics.track_design("booster:undo_refill:rewarded")
			_after_action()
	)


func _apply_skip(source: String) -> void:
	Analytics.track_progression("Fail", mode, _level_id())
	Analytics.track_design(source)
	state.level += 1
	SaveSystem.save(state)
	load_level(state.level, state.theme_active)
	next_requested.emit(state.level)


func pause() -> void:
	pause_requested.emit()


func _on_round_won() -> void:
	Audio.play_sfx("win")
	Audio.play_sfx("coins")
	var result: Dictionary = round.result()
	var coins: int
	var title: String = ""
	if mode == MODE_DAILY:
		coins = DailyChallenge.complete(state, utc_day, result)
		title = tr("lc_daily_title")
	else:
		coins = Economy.apply_win(state, result)
		state.level += 1
		state.levels_completed += 1
		DailyRewards.register_play(state, DailyRewards.utc_day_from_unix(int(clock.call())))
	SaveSystem.save(state)
	_last_win_coins = coins
	_last_win_perfect = bool(result.get("perfect", false))
	_last_win_title = title
	Analytics.track_progression("Complete", mode, _level_id(), int(result.get("moves", 0)))
	hud.refresh()
	level_complete.show_result(coins, _last_win_perfect, level_no, title)
	level_complete.set_double_offer(double_coins_bonus(), can_double_coins())
	level_won.emit(level_no, coins)


func _finish_purchase(ok: bool) -> bool:
	if ok:
		SaveSystem.save(state)
	_after_action()
	return ok


func _after_action() -> void:
	board.refresh()
	hud.refresh()
	_refresh_offers()
	stuck_panel.visible = false
	_check_stuck()


func _check_stuck() -> void:
	if round.is_stuck() and not round.is_done():
		stuck_panel.show_for(round, mode != MODE_DAILY, _ad_offers())
		Analytics.track_design("level:stuck", round.moves_to_goal())


func _level_id() -> String:
	if mode == MODE_DAILY:
		return "daily_%d" % utc_day
	return "level_%04d" % level_no


func _ad_offers() -> Dictionary:
	var live: bool = not round.is_done()
	return {
		"extra_tube":
		live and round.can_add_extra_tube() and rewarded.can_offer(RewardedPlacements.EXTRA_TUBE),
		"undo_refill":
		live and round.undo_charges() == 0 and rewarded.can_offer(RewardedPlacements.UNDO_REFILL),
		"skip":
		(
			mode != MODE_DAILY
			and round.can_skip()
			and rewarded.can_offer(RewardedPlacements.SKIP_LEVEL)
		),
	}


func _refresh_offers() -> void:
	var o: Dictionary = _ad_offers()
	hud.set_ad_offers(bool(o["extra_tube"]), bool(o["undo_refill"]))
