class_name HintNudge
extends RefCounted
## T-235: zgłasza raz, gdy od ostatniej akcji minęło `delay` sekund (pulsowanie podpowiedzi).

var delay: float = 8.0

var _last_action: float = 0.0
var _fired: bool = false


func reset(now: float) -> void:
	_last_action = now
	_fired = false


## True dokładnie raz po upływie `delay` od ostatniego `reset`.
func due(now: float) -> bool:
	if _fired or now - _last_action < delay:
		return false
	_fired = true
	return true


func is_active() -> bool:
	return _fired
