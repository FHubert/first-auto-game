class_name Economy
extends RefCounted
## Pure coin economy logic: earn/spend with analytics, win rewards, costs.

const SOURCE_WIN: String = "win"
const SOURCE_PERFECT: String = "perfect"
const SOURCE_DAILY_REWARD: String = "daily_reward"
const SOURCE_DAILY_CHALLENGE: String = "daily_challenge"
const SOURCE_DAILY_MONTH_GOAL: String = "daily_month_goal"
const SOURCE_REWARDED: String = "rewarded"
const SOURCE_IAP: String = "iap"

const SINK_HINT: String = "hint"
const SINK_EXTRA_TUBE: String = "extra_tube"
const SINK_UNDO_REFILL: String = "undo_refill"
const SINK_THEME: String = "theme"


## Adds coins; non-positive amounts are ignored. Returns the new balance.
static func earn(state: GameState, amount: int, source: String) -> int:
	if amount <= 0:
		return state.coins
	state.coins += amount
	Analytics.track_resource("Source", "coins", float(amount), "economy", source)
	return state.coins


## Removes coins if affordable. Returns false (balance unchanged) otherwise.
static func spend(state: GameState, amount: int, sink: String) -> bool:
	if amount < 0:
		return false
	if amount == 0:
		return true
	if state.coins < amount:
		return false
	state.coins -= amount
	assert(state.coins >= 0)
	Analytics.track_resource("Sink", "coins", float(amount), "economy", sink)
	return true


static func can_afford(state: GameState, amount: int) -> bool:
	return amount >= 0 and state.coins >= amount


static func win_reward(result: Dictionary) -> int:
	if not result.get("won", false):
		return 0
	var total: int = int(GameConfig.get_value("win_reward_coins"))
	if result.get("perfect", false):
		total += int(GameConfig.get_value("par_bonus_coins"))
	return total


## Grants win reward (base as "win", par bonus as "perfect"). Returns total.
static func apply_win(state: GameState, result: Dictionary) -> int:
	if not result.get("won", false):
		return 0
	var base: int = int(GameConfig.get_value("win_reward_coins"))
	var total: int = base
	earn(state, base, SOURCE_WIN)
	if result.get("perfect", false):
		var bonus: int = int(GameConfig.get_value("par_bonus_coins"))
		earn(state, bonus, SOURCE_PERFECT)
		total += bonus
	return total


## Extra coins granted by a rewarded ad on top of base.
static func rewarded_bonus(base: int) -> int:
	var multiplier: float = float(GameConfig.get_value("rewarded_multiplier"))
	return maxi(0, int(round(base * multiplier)) - base)


static func hint_cost() -> int:
	return int(GameConfig.get_value("hint_cost_coins"))


static func extra_tube_cost() -> int:
	return int(GameConfig.get_value("extra_tube_cost_coins"))


static func undo_refill_cost() -> int:
	return int(GameConfig.get_value("undo_refill_cost_coins"))


## Price of the Nth paid theme (1-based); 0 for index <= 0.
static func theme_cost(paid_index: int) -> int:
	if paid_index <= 0:
		return 0
	var base: float = float(GameConfig.get_value("theme_cost_base"))
	var growth: float = float(GameConfig.get_value("theme_cost_growth"))
	return roundi(base * pow(growth, paid_index - 1))


static func buy_booster(state: GameState, sink: String) -> bool:
	match sink:
		SINK_HINT:
			return spend(state, hint_cost(), sink)
		SINK_EXTRA_TUBE:
			return spend(state, extra_tube_cost(), sink)
		SINK_UNDO_REFILL:
			return spend(state, undo_refill_cost(), sink)
	return false
