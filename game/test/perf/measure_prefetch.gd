extends SceneTree
## Pomiar LevelPrefetch.take (T-136, przeniesiony z testu w T-144). Reczny, poza `make test`:
##   cd game && ../.tools/godot --headless --path . --script res://test/perf/measure_prefetch.gd
## Mediana z 5 load-ek: take synchroniczny (cold) vs po request + 150 ms (prefetched).

const LEVELS: Array = [2, 26, 50, 120]
const RUNS: int = 5
const MEDIAN_IDX: int = 2
const WAIT_MSEC: int = 150


func _initialize() -> void:
	# load() w runtime: autoloady (GameConfig) istnieja dopiero po kompilacji tego skryptu.
	var prefetch: RefCounted = load("res://src/systems/level_prefetch.gd").new()
	for level in LEVELS:
		var cold: Array = []
		var warm: Array = []
		for _i in RUNS:
			var t0: int = Time.get_ticks_usec()
			prefetch.take(1, level)
			cold.append(Time.get_ticks_usec() - t0)
			prefetch.request(1, level)
			OS.delay_msec(WAIT_MSEC)
			t0 = Time.get_ticks_usec()
			prefetch.take(1, level)
			warm.append(Time.get_ticks_usec() - t0)
		cold.sort()
		warm.sort()
		print(
			(
				"PREFETCH_MEASURE level=%d sync_us=%d prefetched_us=%d"
				% [level, cold[MEDIAN_IDX], warm[MEDIAN_IDX]]
			)
		)
	prefetch.cancel_all()
	quit()
