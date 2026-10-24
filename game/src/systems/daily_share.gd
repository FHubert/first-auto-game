class_name DailyShare
extends RefCounted
## Tekst wyniku Poziomu dnia do schowka (jak Wordle). Stala produktu, nie balans.
## TODO: dodac link do sklepu po publikacji.

## Dzien UTC numer 0; #1 = 2026-10-24 = dzien UTC 20750.
const EPOCH_DAY: int = 20749
const STAR: String = " ★"


static func text(utc_day: int, moves: int, min_moves: int, streak_days: int) -> String:
	var slack: int = int(GameConfig.get_value("par_slack_moves"))
	var line2: String = TranslationServer.translate("share_daily_moves") % [moves, min_moves]
	if moves <= min_moves + slack:
		line2 += STAR
	var line3: String = TranslationServer.translate("home_streak") % streak_days
	return "Vialo Daily #%d\n%s\n%s" % [utc_day - EPOCH_DAY, line2, line3]
