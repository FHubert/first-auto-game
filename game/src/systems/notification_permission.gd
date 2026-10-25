class_name NotificationPermission
extends RefCounted
## When to ask for the system notification permission (GDD decision 8): once, after the
## 1st completed Daily Level, never at start. Pure logic, no Node.

const MIN_DAILY_COMPLETED: int = 1


static func should_ask(state: GameState, status: String) -> bool:
	if status != NotificationProvider.PERMISSION_NOT_DETERMINED:
		return false
	var s: Dictionary = state.settings
	return (
		bool(s.get(GameState.SETTING_NOTIFICATIONS_ON, true))
		and bool(s.get(GameState.SETTING_TUTORIAL_DONE, false))
		and not bool(s.get(GameState.SETTING_NOTIF_PERMISSION_ASKED, false))
		and state.daily_completed_total >= MIN_DAILY_COMPLETED
	)


## Statuses that allow scheduling notifications.
static func allows_scheduling(status: String) -> bool:
	return (
		status == NotificationProvider.PERMISSION_GRANTED
		or status == NotificationProvider.PERMISSION_NOT_REQUIRED
	)
