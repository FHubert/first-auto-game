class_name RoundCounters
extends RefCounted
## Liczniki i boostery jednej rundy (cofnięcia, dodatkowe probówki, restarty).
## Czysta logika bez Node; używana przez GameRound.

var undo_charges: int = 0
var undos_used: int = 0
var extra_tubes_added: int = 0
var boosters_used: int = 0
var restarts: int = 0


## Stan jak po GameRound.start().
func reset(free_undo: int) -> void:
	undo_charges = free_undo
	undos_used = 0
	extra_tubes_added = 0
	boosters_used = 0
	restarts = 0


## Stan jak po GameRound.restart(): undos_used i boosters_used zostają.
func on_restart(free_undo: int) -> void:
	undo_charges = free_undo
	extra_tubes_added = 0
	restarts += 1


func add_undo_charges(n: int) -> void:
	if n <= 0:
		return
	undo_charges += n
	boosters_used += 1


func use_undo() -> bool:
	if undo_charges <= 0:
		return false
	undo_charges -= 1
	undos_used += 1
	return true


func on_extra_tube() -> void:
	extra_tubes_added += 1
	boosters_used += 1


func on_hint_used() -> void:
	boosters_used += 1


func to_dict() -> Dictionary:
	return {
		"undo_charges": undo_charges,
		"undos_used": undos_used,
		"extra_tubes_added": extra_tubes_added,
		"boosters_used": boosters_used,
		"restarts": restarts,
	}


## Waliduje undo_charges/undos_used/boosters_used/restarts; null przy złym typie lub < 0.
## extra_tubes_added ustawia wołający (waliduje go razem z limitem z configu).
static func from_dict(d: Dictionary, fallback_undo: int) -> RoundCounters:
	var c := RoundCounters.new()
	var vals: Dictionary = {}
	for key: String in ["undo_charges", "undos_used", "boosters_used", "restarts"]:
		var fallback: int = fallback_undo if key == "undo_charges" else 0
		var v: Variant = GameState._as_int(d.get(key, fallback))
		if v == null or int(v) < 0:
			return null
		vals[key] = int(v)
	c.undo_charges = vals["undo_charges"]
	c.undos_used = vals["undos_used"]
	c.boosters_used = vals["boosters_used"]
	c.restarts = vals["restarts"]
	return c
