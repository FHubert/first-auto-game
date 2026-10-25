class_name ScreenshotFixtures
extends RefCounted
## In-memory GameState presets for `--screenshot` captures (never written to the player's save).

const MIDGAME_COINS: int = 350
const MIDGAME_LEVEL: int = 20
const MIDGAME_STREAK: int = 4
const MIDGAME_EXTRA_THEME: String = "neon"
# Store screenshots (docs/ASO.md): level 20 = 6 colors with the default curve.
const ASO_LEVEL: int = 20
const ASO_COINS: int = 350
const ASO_STREAK: int = 4  # claiming on the next day lands on cycle day 5
const ASO_HOME_DAILY_TOTAL: int = 23
const ASO_HOME_STREAK_BEST: int = 12
const ASO_HOME_STREAK_DAYS: int = 5
const SYMBOLS_LEVEL: int = 32  # 8 colors with the default curve
const PLATEAU_LEVEL: int = 56
## Restarts played by the screenshot driver before the capture (attempt 3 shows the bar).
const PLATEAU_RESTARTS: int = 2
## aso_themes: two of four owned, so a priced locked theme shows and ASO_COINS < its cost.
const THEMES_OWNED: Array = ["classic", "neon"]
const THEMES_ACTIVE: String = "neon"
## aso_shop: starter offer with ~11 h left; daily: streak shown as 3 claimed days.
const SHOP_OFFER_HOURS_LEFT: int = 11
const DAILY_STREAK: int = 3
const SECONDS_PER_DAY: int = 86400


## Pre-win LevelComplete values, derived from Economy (never literals).
static func win_result() -> Dictionary:
	var coins: int = Economy.win_reward({"won": true, "perfect": true})
	return {"perfect": true, "coins": coins, "double_bonus": Economy.rewarded_bonus(coins)}


## Fills the LevelComplete overlay of `level` with the pre-win values.
static func apply_win(level: Level) -> void:
	var result: Dictionary = win_result()
	var progress: Dictionary = LevelComplete.progress_message(
		level.level_no, level.mode, level.state
	)
	var next_id: String = ThemeCatalog.next_theme_id(level.state)
	var breakdown: Dictionary = {
		"win": int(GameConfig.get_value("win_reward_coins")),
		"perfect": int(GameConfig.get_value("par_bonus_coins")),
		"moves": level.round.min_moves() if level.round != null else 0,
		"theme_name": level.tr("theme_name_" + next_id) if next_id != "" else "",
		"theme_cost": ThemeCatalog.next_theme_cost(level.state),
		"coins": level.state.coins,
	}
	level.level_complete.show_result(
		int(result["coins"]), true, level.level_no, "", progress, breakdown
	)
	level.level_complete.set_double_offer(int(result["double_bonus"]), true)
	level.hud.visible = false
	level.fit_board_above_panel()


## Returns a fresh state for the fixture name, or null when unknown.
## `utc_day` (today) is only used by calendar fixtures (aso_daily, daily, aso_shop);
## `now_unix` (0 = start of `utc_day`) anchors the starter offer window of aso_shop.
static func make(fixture: String, utc_day: int = 0, now_unix: int = 0) -> GameState:
	var state := GameState.new()
	state.settings[GameState.SETTING_TUTORIAL_DONE] = true
	match fixture:
		"default":
			pass
		"midgame":
			state.level = MIDGAME_LEVEL
			state.levels_completed = MIDGAME_LEVEL - 1
			state.coins = MIDGAME_COINS
			state.streak_days = MIDGAME_STREAK
			state.themes_owned = [GameState.DEFAULT_THEME, MIDGAME_EXTRA_THEME]
			state.daily_reward_last_claim_day = 0
		"aso_level", "aso_win", "aso_home":
			state.level = ASO_LEVEL
			state.levels_completed = ASO_LEVEL - 1
			state.coins = ASO_COINS
			state.streak_days = ASO_STREAK
			if fixture == "aso_home":
				state.streak_days = ASO_HOME_STREAK_DAYS
				state.streak_best = ASO_HOME_STREAK_BEST
				state.daily_completed_total = ASO_HOME_DAILY_TOTAL
				state.settings[Home.DAILY_INTRO_SEEN_KEY] = true
		"aso_daily":
			state.level = ASO_LEVEL
			state.levels_completed = ASO_LEVEL - 1
			state.coins = ASO_COINS
			state.streak_days = ASO_STREAK
			state.last_play_utc_day = maxi(utc_day - 1, 0)
			state.daily_reward_last_claim_day = maxi(utc_day - 1, 0)
		"daily":
			state.level = ASO_LEVEL
			state.levels_completed = ASO_LEVEL - 1
			state.coins = ASO_COINS
			state.streak_days = DAILY_STREAK
			state.last_play_utc_day = maxi(utc_day - 1, 0)
			state.daily_reward_last_claim_day = maxi(utc_day - 1, 0)
		"aso_shop":
			state.level = maxi(ASO_LEVEL, int(GameConfig.get_value("starter_offer_min_level")))
			state.levels_completed = state.level - 1
			state.coins = ASO_COINS
			var now: int = now_unix if now_unix > 0 else utc_day * SECONDS_PER_DAY
			var window_s: int = int(GameConfig.get_value("starter_offer_hours")) * 3600
			state.starter_offer_start_day = maxi(now + SHOP_OFFER_HOURS_LEFT * 3600 - window_s, 1)
		"symbols", "symbols_neon":
			state.level = SYMBOLS_LEVEL
			state.levels_completed = SYMBOLS_LEVEL - 1
			state.settings[ColorSymbols.SETTING_KEY] = true
			if fixture == "symbols_neon":
				state.themes_owned = [GameState.DEFAULT_THEME, MIDGAME_EXTRA_THEME]
				state.theme_active = MIDGAME_EXTRA_THEME
		"plateau_assist":
			state.level = PLATEAU_LEVEL
			state.levels_completed = PLATEAU_LEVEL - 1
			state.coins = ASO_COINS
		"aso_themes":
			state.level = ASO_LEVEL
			state.coins = ASO_COINS
			state.themes_owned = THEMES_OWNED.duplicate()
			state.theme_active = THEMES_ACTIVE
		_:
			return null
	return state
