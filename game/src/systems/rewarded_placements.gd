class_name RewardedPlacements
extends RefCounted
## Six rewarded placements: per-level grant counters and the offer -> ad -> reward flow.

const DOUBLE_COINS: String = "double_coins"
const EXTRA_TUBE: String = "extra_tube"
const UNDO_REFILL: String = "undo_refill"
const SKIP_LEVEL: String = "skip_level"
const DAILY_X2: String = "daily_x2"
const STREAK_SAVE: String = "streak_save"
const ALL: Array[String] = [
	DOUBLE_COINS, EXTRA_TUBE, UNDO_REFILL, SKIP_LEVEL, DAILY_X2, STREAK_SAVE
]

var _granted: Dictionary = {}


func reset() -> void:
	_granted.clear()


func granted_count(id: String) -> int:
	return int(_granted.get(id, 0))


func is_valid(id: String) -> bool:
	return id in ALL


func max_per_level(id: String) -> int:
	match id:
		DOUBLE_COINS:
			return int(GameConfig.get_value("rewarded_double_coins_max_per_level"))
		UNDO_REFILL:
			return int(GameConfig.get_value("rewarded_undo_refill_max_per_level"))
		SKIP_LEVEL:
			return int(GameConfig.get_value("rewarded_skip_max_per_level"))
		EXTRA_TUBE:
			return int(GameConfig.get_value("extra_tube_max_per_level"))
		DAILY_X2, STREAK_SAVE:
			return 1
	return 0


func can_offer(id: String, ads: Node = null) -> bool:
	return _within_cap(id) and _ads(ads).is_rewarded_ready()


## Shows the ad; on_grant runs only when the reward was earned. True if an ad was shown.
func offer(id: String, on_grant: Callable, ads: Node = null) -> bool:
	if not _within_cap(id):
		Analytics.track_design("ads:rewarded:%s:unavailable" % id)
		return false
	if not _ads(ads).is_rewarded_ready():
		return false
	Analytics.track_design("ads:rewarded:%s:offered" % id)
	return _ads(ads).request_rewarded(
		id,
		func() -> void:
			_granted[id] = granted_count(id) + 1
			on_grant.call()
	)


func _within_cap(id: String) -> bool:
	return is_valid(id) and granted_count(id) < max_per_level(id)


func _ads(ads: Node) -> Node:
	return ads if ads != null else Ads
