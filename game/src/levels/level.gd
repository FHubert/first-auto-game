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
## Haptic length on tube close (2x AudioService.HAPTIC_MS).
const TUBE_FULL_HAPTIC_MS: int = 40
const CONFETTI_AMOUNT: int = 48
const CONFETTI_COLORS: int = 6
const CONFETTI_EMIT_HEIGHT: float = 4.0

@export var level: int = 2

var round: GameRound
var state: GameState
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var mode: String = MODE_CAMPAIGN
var level_no: int = 1
var utc_day: int = 0
var tutorial: TutorialFlow
var rewarded: RewardedPlacements = RewardedPlacements.new()
var offers: LevelOffers = LevelOffers.new()
var effects_enabled: bool = true

var _round_bound_at: int = 0
var _tutorial_max_step: int = 0
var _last_win_coins: int = 0
var _last_win_perfect: bool = false
var _last_win_title: String = ""

@onready var board: BoardView = $Board
@onready var hud: Hud = $Hud
@onready var confetti: CPUParticles2D = $Confetti
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
		func(_from: int, to: int) -> void:
			var closes: bool = Level.closes_tube(round.board(), to) and not round.is_done()
			Audio.play_sfx("pour")
			Audio.haptic(TUBE_FULL_HAPTIC_MS if closes else Audio.HAPTIC_MS)
			if closes:
				Audio.play_sfx("tube_full")
				board.pulse_tube(to)
	)
	board.illegal_move.connect(func(_from: int, _to: int) -> void: Audio.play_sfx("error"))
	board.tube_selected.connect(_on_tutorial_selected)
	board.tube_deselected.connect(_on_tutorial_deselected)
	board.pour_finished.connect(_on_tutorial_pour)
	offers.shop_requested.connect(func(reason: String) -> void: shop_requested.emit(reason))
	offers.purchase_finished.connect(_finish_purchase)
	offers.hint_source.connect(
		func(index: int) -> void:
			if board.selected_index() == -1:
				board.tap(index)
	)
	offers.action_applied.connect(_after_action)
	offers.skip_applied.connect(_apply_skip)
	offers.double_coins_granted.connect(_on_double_coins_granted)
	hud.hint_pressed.connect(offers.buy_hint)
	hud.extra_tube_pressed.connect(offers.buy_extra_tube)
	stuck_panel.undo_pressed.connect(undo)
	stuck_panel.extra_tube_pressed.connect(offers.buy_extra_tube)
	stuck_panel.undo_refill_pressed.connect(offers.buy_undo_refill)
	hud.extra_tube_ad_pressed.connect(func() -> void: offers.watch_extra_tube())
	hud.undo_refill_ad_pressed.connect(func() -> void: offers.watch_undo_refill())
	stuck_panel.extra_tube_ad_pressed.connect(func() -> void: offers.watch_extra_tube())
	stuck_panel.undo_refill_ad_pressed.connect(func() -> void: offers.watch_undo_refill())
	level_complete.double_pressed.connect(func() -> void: offers.watch_double_coins())
	stuck_panel.restart_pressed.connect(restart)
	stuck_panel.skip_pressed.connect(offers.watch_skip)
	hud.undo_pressed.connect(undo)
	hud.restart_pressed.connect(restart)
	hud.pause_pressed.connect(pause)
	level_complete.next_pressed.connect(on_next_pressed)
	level_complete.home_pressed.connect(func() -> void: home_requested.emit())
	if round == null:
		load_level(state.level, state.theme_active)


## True when tube `to` is full and single-coloured after a pour.
static func closes_tube(sort_board: SortBoard, to: int) -> bool:
	return sort_board.is_full(to) and sort_board.is_uniform(to)


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
	Analytics.track_progression("Start", mode, _level_id())
	Analytics.track_design("level:start", float(round.min_moves()))
	_bind_round(theme_id)


## Podpina biezaca runde do widokow (plansza, HUD, tutorial, oferty).
func _bind_round(theme_id: String) -> void:
	_stop_confetti()
	offers.bind(state, round, rewarded, mode, level_no)
	_round_bound_at = int(clock.call())
	board.setup(round, theme_id)
	hud.bind(round, level_no)
	stuck_panel.visible = false
	tutorial = null
	if level_no == 1 and not bool(state.settings.get("tutorial_done", false)):
		_tutorial_max_step = 0
		tutorial = TutorialFlow.new()
		tutorial.start(_solver_first_move())
		_track_tutorial_step()
	_update_tutorial_overlay()
	_refresh_offers()


## Dolicza czas od ostatniego bind/flush do round.elapsed_s (idempotentne).
func _flush_elapsed() -> void:
	var now: int = int(clock.call())
	round.elapsed_s += float(maxi(0, now - _round_bound_at))
	_round_bound_at = now


## Wznowienie liczenia czasu rundy po powrocie z tla - czas w tle nie wchodzi do elapsed_s.
func resume_clock() -> void:
	_round_bound_at = int(clock.call())


## Snapshot biezacej rundy do round_in_progress; {} gdy brak rundy lub ukonczona.
func snapshot() -> Dictionary:
	if round == null or round.is_done():
		return {}
	_flush_elapsed()
	return GameState.round_snapshot(mode, level_no, utc_day, round)


## Wznawia runde ze snapshotu (bez level:start); false = snapshot niezgodny.
func resume(snap: Dictionary, today: int) -> bool:
	var mode_in: String = str(snap.get("mode", ""))
	if mode_in != MODE_CAMPAIGN and mode_in != MODE_DAILY:
		return false
	var lvl: Variant = GameState._as_int(snap.get("level_no"))
	var day: Variant = GameState._as_int(snap.get("utc_day"))
	if lvl == null or day == null or typeof(snap.get("round")) != TYPE_DICTIONARY:
		return false
	if mode_in == MODE_DAILY and int(day) != today:
		return false
	if mode_in == MODE_CAMPAIGN and int(lvl) != state.level:
		return false
	var r: GameRound = GameRound.from_dict(snap["round"])
	if r == null or r.is_done():
		return false
	mode = mode_in
	level_no = int(lvl)
	utc_day = int(day)
	round = r
	rewarded.reset()
	_bind_round(state.theme_active)
	hud.set_title(tr("hud_daily") if mode == MODE_DAILY else "")
	Analytics.track_design("level:resume", float(round.moves()))
	return true


func on_next_pressed() -> void:
	if mode == MODE_DAILY:
		level_complete.visible = false
		home_requested.emit()
		return
	level_complete.visible = false
	Ads.maybe_show_interstitial(level_no, bool(state.settings.get("ads_removed", false)))
	load_level(state.level, state.theme_active)
	next_requested.emit(state.level)


## Pierwszy ruch solvera z biezacego stanu (bez liczenia podpowiedzi).
func _solver_first_move() -> Vector2i:
	var max_states: int = int(GameConfig.get_value("hint_solver_max_states"))
	var path: Array = SortSolver.solve(round.board(), max_states, 1.0).get("path", [])
	if path.is_empty():
		return GameRound.NO_HINT
	return path[0]


func _on_tutorial_selected(index: int) -> void:
	if tutorial != null and tutorial.on_tube_selected(index):
		_track_tutorial_step()
		_update_tutorial_overlay()


func _on_tutorial_deselected(_index: int) -> void:
	if tutorial != null and tutorial.step == TutorialFlow.Step.PICK_TARGET:
		tutorial.on_deselect()
		Analytics.track_design("tutorial:reset", float(TutorialFlow.Step.PICK_TARGET + 1))
		_update_tutorial_overlay()


func _on_tutorial_pour(from: int, to: int) -> void:
	if tutorial == null:
		return
	var next_move: Vector2i = GameRound.NO_HINT
	if not round.is_done():
		next_move = _solver_first_move()
	var prev_step: int = tutorial.step
	if not tutorial.on_pour(from, to, next_move, round.is_done()):
		if round.is_done():
			tutorial.step = TutorialFlow.Step.DONE
		else:
			tutorial.start(next_move)
			Analytics.track_design("tutorial:reset", float(prev_step + 1))
	_track_tutorial_step()
	_update_tutorial_overlay()


## Loguje tutorial:step:N (N = Step + 1: 1 wybor zrodla, 2 cel, 3 koniec) raz na runde.
func _track_tutorial_step() -> void:
	if tutorial == null or tutorial.is_done():
		return
	var step_no: int = tutorial.step + 1
	if step_no > _tutorial_max_step:
		_tutorial_max_step = step_no
		Analytics.track_design("tutorial:step:%d" % step_no)


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
	_stop_confetti()
	round.restart()
	state.level_restarts += 1
	_after_action()
	Analytics.track_progression("Fail", mode, _level_id())
	Analytics.track_design("level:fail:restart")


func _apply_skip(source: String) -> void:
	Analytics.track_progression("Fail", mode, _level_id())
	Analytics.track_design("level:fail:skip")
	Analytics.track_design(source)
	state.level += 1
	SaveSystem.save(state)
	load_level(state.level, state.theme_active)
	next_requested.emit(state.level)


func pause() -> void:
	quit_level()
	pause_requested.emit()


## Leaving an unfinished round is a pause (snapshot is resumable), not a fail;
## abandoning the snapshot is reported by App as level:fail:abandon.
func quit_level() -> void:
	if round != null and not round.is_done():
		Analytics.track_design("level:pause", float(round.moves()))


func _on_round_won() -> void:
	Audio.play_sfx("win")
	Audio.play_sfx("coins")
	_flush_elapsed()
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
	state.round_in_progress = {}
	SaveSystem.save(state)
	_last_win_coins = coins
	offers.last_win_coins = coins
	_last_win_perfect = bool(result.get("perfect", false))
	_last_win_title = title
	Analytics.track_progression("Complete", mode, _level_id(), int(result.get("moves", 0)))
	var kind: String = "perfect" if _last_win_perfect else "normal"
	Analytics.track_design("level:complete:" + kind, float(result.get("elapsed_s", 0.0)))
	Analytics.track_design("level:complete:undos", float(result.get("undos_used", 0)))
	Analytics.track_design("level:complete:boosters", float(result.get("boosters_used", 0)))
	hud.refresh()
	level_complete.show_result(
		coins,
		_last_win_perfect,
		level_no,
		title,
		LevelComplete.progress_message(level_no, mode, state)
	)
	level_complete.set_double_offer(offers.double_coins_bonus(), offers.can_double_coins())
	_start_confetti()
	level_won.emit(level_no, coins)


func _start_confetti() -> void:
	if not effects_enabled:
		return
	confetti.amount = CONFETTI_AMOUNT
	confetti.lifetime = float(GameConfig.get_value("confetti_seconds", 1.2))
	confetti.position = board.position + Vector2(board.size.x * 0.5, 0.0)
	confetti.emission_rect_extents = Vector2(board.size.x * 0.5, CONFETTI_EMIT_HEIGHT)
	confetti.color_initial_ramp = _confetti_ramp()
	confetti.restart()
	confetti.emitting = true


func _stop_confetti() -> void:
	confetti.emitting = false


## Gradient z pierwszych kolorow palety aktywnego motywu.
func _confetti_ramp() -> Gradient:
	var liquids: Array = board.theme_data.get("liquids", [])
	var n: int = mini(CONFETTI_COLORS, liquids.size())
	var ramp := Gradient.new()
	if n == 0:
		ramp.offsets = PackedFloat32Array([0.0])
		ramp.colors = PackedColorArray([Color.WHITE])
		return ramp
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in n:
		offs.append(float(i) / float(maxi(1, n - 1)))
		cols.append(Color(str(liquids[i])))
	ramp.offsets = offs
	ramp.colors = cols
	return ramp


func _finish_purchase(ok: bool) -> void:
	if ok:
		SaveSystem.save(state)
	_after_action()


func _on_double_coins_granted(bonus: int) -> void:
	SaveSystem.save(state)
	level_complete.show_result(
		_last_win_coins + bonus,
		_last_win_perfect,
		level_no,
		_last_win_title,
		LevelComplete.progress_message(level_no, mode, state)
	)
	level_complete.set_double_offer(0, false)
	hud.refresh()
	Audio.play_sfx("coins")


## Odswieza HUD/plansze/stuck panel po powrocie ze sklepu (overlay).
func refresh_after_shop() -> void:
	if board.theme_id != state.theme_active:
		board.apply_theme(state.theme_active)
	_after_action()


func apply_theme(theme_id_in: String) -> void:
	board.apply_theme(theme_id_in)


func _after_action() -> void:
	board.refresh()
	hud.refresh()
	_refresh_offers()
	stuck_panel.visible = false
	_check_stuck()


func _check_stuck() -> void:
	if round.is_stuck() and not round.is_done():
		stuck_panel.show_for(round, mode != MODE_DAILY, offers.ad_offers())
		Analytics.track_design("level:stuck", round.moves_to_goal())


func _level_id() -> String:
	return level_id_for(mode, level_no, utc_day)


static func level_id_for(mode_in: String, level_no_in: int, utc_day_in: int) -> String:
	if mode_in == MODE_DAILY:
		return "daily_%d" % utc_day_in
	return "level_%04d" % level_no_in


func _refresh_offers() -> void:
	var o: Dictionary = offers.ad_offers()
	hud.set_ad_offers(bool(o["extra_tube"]), bool(o["undo_refill"]))
