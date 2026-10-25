class_name AdLoadPolicy
extends RefCounted
## Retry policy for ad loading (T-224, ADR-013). Pure logic: caller supplies time (seconds).
## Delay after the n-th consecutive failure = min(base * 2^(n-1), max); gives up after
## `ad_load_max_retries` consecutive failures. One instance per ad format.

var _failures: int = 0
var _next_at: float = 0.0
var _loading: bool = false


func on_requested(now: float) -> void:
	_loading = true
	_next_at = now


func on_loaded() -> void:
	_loading = false
	_failures = 0
	_next_at = 0.0


## Registers a failed load; returns the time of the next allowed attempt.
func on_failed(now: float) -> float:
	_loading = false
	_failures += 1
	var base: float = float(GameConfig.get_value("ad_load_retry_base_seconds"))
	var cap: float = float(GameConfig.get_value("ad_load_retry_max_seconds"))
	var exponent: int = mini(_failures - 1, 30)
	_next_at = now + minf(base * pow(2.0, exponent), cap)
	return _next_at


func is_due(now: float) -> bool:
	return not gave_up() and not _loading and _failures > 0 and now >= _next_at


func gave_up() -> bool:
	return _failures > 0 and _failures >= maxi(int(GameConfig.get_value("ad_load_max_retries")), 1)


func failures() -> int:
	return _failures


func reset() -> void:
	_failures = 0
	_next_at = 0.0
	_loading = false
