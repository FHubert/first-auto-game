class_name ScreenshotFixtures
extends RefCounted
## In-memory GameState presets for `--screenshot` captures (never written to the player's save).

const MIDGAME_COINS: int = 350
const MIDGAME_LEVEL: int = 20
const MIDGAME_STREAK: int = 4
const MIDGAME_EXTRA_THEME: String = "neon"


## Returns a fresh state for the fixture name, or null when unknown.
static func make(fixture: String) -> GameState:
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
		_:
			return null
	return state
