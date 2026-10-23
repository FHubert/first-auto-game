class_name Boosters
extends RefCounted
## Zakup boosterow za monety (czysta logika). Brak srodkow = saldo i efekt bez zmian.


static func buy_extra_tube(state: GameState, round_in: GameRound) -> bool:
	if not round_in.can_add_extra_tube():
		return false
	if not Economy.buy_booster(state, Economy.SINK_EXTRA_TUBE):
		return false
	round_in.add_extra_tube()
	Analytics.track_design("booster:extra_tube:coins")
	return true


static func buy_undo_refill(state: GameState, round_in: GameRound) -> bool:
	if not Economy.buy_booster(state, Economy.SINK_UNDO_REFILL):
		return false
	round_in.add_undo_charges(_cfg_int("undo_refill_amount"))
	Analytics.track_design("booster:undo_refill:coins")
	return true


static func buy_hint(state: GameState, round_in: GameRound) -> Vector2i:
	if round_in.is_done() or not Economy.buy_booster(state, Economy.SINK_HINT):
		return GameRound.NO_HINT
	Analytics.track_design("booster:hint:coins")
	return round_in.hint()


static func _cfg_int(key: String) -> int:
	return int(GameConfig.get_value(key, 0))
