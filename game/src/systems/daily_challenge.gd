class_name DailyChallenge
extends RefCounted
## Poziom dnia: deterministyczny z dnia UTC, nagroda raz na dzien. Czysta logika.


static func is_unlocked(state: GameState) -> bool:
	return state.level >= int(GameConfig.get_value("daily_unlock_level"))


static func level_for_day(utc_day: int) -> Dictionary:
	return ContentGenerator.new().generate_daily(utc_day)


static func is_completed_today(state: GameState, utc_day: int) -> bool:
	return state.daily_last_completed_day == utc_day


static func can_complete(state: GameState, utc_day: int) -> bool:
	return utc_day > 0 and is_unlocked(state) and utc_day > state.daily_last_completed_day


static func reward_amount() -> int:
	return int(GameConfig.get_value("daily_challenge_coins"))


## Zalicza Poziom dnia. Zwraca przyznane monety (0 gdy przegrana/zablokowane/juz zaliczone).
static func complete(state: GameState, utc_day: int, result: Dictionary) -> int:
	if not bool(result.get("won", false)) or not can_complete(state, utc_day):
		return 0
	state.daily_last_completed_day = utc_day
	state.daily_completed_total += 1
	var amount: int = reward_amount()
	Economy.earn(state, amount, Economy.SOURCE_DAILY_CHALLENGE)
	Analytics.track_design("daily_challenge:completed", float(result.get("moves", 0)))
	DailyRewards.register_play(state, utc_day)
	return amount


static func seconds_to_next(unix_now: int) -> int:
	return DailyRewards.SECONDS_PER_DAY - (unix_now % DailyRewards.SECONDS_PER_DAY)
