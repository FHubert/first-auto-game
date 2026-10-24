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
const ASO_THEMES: Array = ["classic", "pastel", "neon", "ocean"]


## Returns a fresh state for the fixture name, or null when unknown.
## `utc_day` (today) is only used by fixtures that depend on the calendar (aso_daily).
static func make(fixture: String, utc_day: int = 0) -> GameState:
	var state := GameState.new()
	state.settings["tutorial_done"] = true
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
		"aso_daily":
			state.level = ASO_LEVEL
			state.levels_completed = ASO_LEVEL - 1
			state.coins = ASO_COINS
			state.streak_days = ASO_STREAK
			state.last_play_utc_day = maxi(utc_day - 1, 0)
			state.daily_reward_last_claim_day = maxi(utc_day - 1, 0)
		"aso_themes":
			state.level = ASO_LEVEL
			state.coins = ASO_COINS
			state.themes_owned = ASO_THEMES.duplicate()
			state.theme_active = str(ASO_THEMES[1])
		_:
			return null
	return state
