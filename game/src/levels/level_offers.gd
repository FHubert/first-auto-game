class_name LevelOffers
extends RefCounted
## Oferty rewarded i boostery za monety rundy; czysta logika, UI przez sygnaly.

signal shop_requested(reason: String)
signal purchase_finished(ok: bool)
signal hint_source(index: int)
signal action_applied
signal skip_applied(source: String)
signal double_coins_granted(bonus: int)

const MODE_CAMPAIGN: String = "campaign"
const MODE_DAILY: String = "daily"

var state: GameState
var round: GameRound
var rewarded: RewardedPlacements
var mode: String = MODE_CAMPAIGN
var level_no: int = 1
var last_win_coins: int = 0


func bind(
	p_state: GameState,
	p_round: GameRound,
	p_rewarded: RewardedPlacements,
	p_mode: String,
	p_level_no: int
) -> void:
	state = p_state
	round = p_round
	rewarded = p_rewarded
	mode = p_mode
	level_no = p_level_no


func buy_extra_tube() -> bool:
	var ok: bool = Boosters.buy_extra_tube(state, round)
	if not ok and not Economy.can_afford(state, Economy.extra_tube_cost()):
		shop_requested.emit(Economy.SINK_EXTRA_TUBE)
	purchase_finished.emit(ok)
	return ok


func buy_undo_refill() -> bool:
	var ok: bool = Boosters.buy_undo_refill(state, round)
	if not ok and not Economy.can_afford(state, Economy.undo_refill_cost()):
		shop_requested.emit(Economy.SINK_UNDO_REFILL)
	purchase_finished.emit(ok)
	return ok


## Zwraca zrodlo podpowiedzi przez hint_source; ruchu nie wykonuje.
func buy_hint() -> bool:
	var m: Vector2i = Boosters.buy_hint(state, round)
	var ok: bool = m != GameRound.NO_HINT
	if not ok and not Economy.can_afford(state, Economy.hint_cost()):
		shop_requested.emit(Economy.SINK_HINT)
	if ok:
		hint_source.emit(m.x)
	purchase_finished.emit(ok)
	return ok


## Skip without an ad (kept for tests/debug); the UI uses watch_skip.
func skip_level() -> void:
	if mode == MODE_DAILY or not round.can_skip():
		return
	skip_applied.emit("level:skip:free")


func watch_skip() -> bool:
	if mode == MODE_DAILY or not round.can_skip():
		return false
	return rewarded.offer(
		RewardedPlacements.SKIP_LEVEL, func() -> void: skip_applied.emit("level:skip:rewarded")
	)


func can_double_coins() -> bool:
	if not round.is_done() or last_win_coins <= 0:
		return false
	var min_level: int = int(GameConfig.get_value("rewarded_double_coins_min_level"))
	if mode != MODE_DAILY and level_no < min_level:
		return false
	return rewarded.can_offer(RewardedPlacements.DOUBLE_COINS)


func double_coins_bonus() -> int:
	return Economy.rewarded_bonus(last_win_coins) if can_double_coins() else 0


func watch_double_coins() -> bool:
	if not can_double_coins():
		return false
	var bonus: int = double_coins_bonus()
	return rewarded.offer(
		RewardedPlacements.DOUBLE_COINS,
		func() -> void:
			Economy.earn(state, bonus, Economy.SOURCE_REWARDED)
			double_coins_granted.emit(bonus)
	)


func watch_extra_tube() -> bool:
	if round.is_done() or not round.can_add_extra_tube():
		return false
	return rewarded.offer(
		RewardedPlacements.EXTRA_TUBE,
		func() -> void:
			round.add_extra_tube()
			Analytics.track_design("booster:extra_tube:rewarded")
			action_applied.emit()
	)


func watch_undo_refill() -> bool:
	if round.is_done():
		return false
	return rewarded.offer(
		RewardedPlacements.UNDO_REFILL,
		func() -> void:
			round.add_undo_charges(int(GameConfig.get_value("undo_refill_amount")))
			Analytics.track_design("booster:undo_refill:rewarded")
			action_applied.emit()
	)


func ad_offers() -> Dictionary:
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
