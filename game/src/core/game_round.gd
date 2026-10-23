class_name GameRound
extends RefCounted
## Genre-agnostic round stub: deterministic simulation used by the playtest bot.
## Replace with real gameplay; keep start/step/result as the bot contract.

const ACTION_COUNT: int = 3
const BASE_TARGET: int = 5
const TARGET_PER_DIFFICULTY: int = 20
const POINTS_PER_HIT: int = 10

var _rng := RandomNumberGenerator.new()
var _target: int = 0
var _max_misses: int = 0
var _hits: int = 0
var _misses: int = 0
var _steps: int = 0
var _score: int = 0
var _done: bool = false
var _won: bool = false


func start(level_data: Dictionary) -> void:
	var difficulty: float = float(level_data.get("difficulty", 0.0))
	_rng.seed = int(level_data.get("seed", 0)) + int(level_data.get("level", 0))
	_target = BASE_TARGET + int(difficulty * TARGET_PER_DIFFICULTY)
	_max_misses = 3 + int((1.0 - difficulty) * 5.0)
	_hits = 0
	_misses = 0
	_steps = 0
	_score = 0
	_done = false
	_won = false


## Applies one action (0..ACTION_COUNT-1). Returns true when the round is over.
func step(action: int) -> bool:
	if _done:
		return true
	_steps += 1
	var required: int = _rng.randi_range(0, ACTION_COUNT - 1)
	if action == required:
		_hits += 1
		_score += POINTS_PER_HIT
	else:
		_misses += 1
	if _hits >= _target:
		_done = true
		_won = true
	elif _misses > _max_misses:
		_done = true
	return _done


func result() -> Dictionary:
	return {"won": _won, "score": _score, "steps": _steps}
