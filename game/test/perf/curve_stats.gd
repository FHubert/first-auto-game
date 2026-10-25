class_name CurveStats
extends RefCounted
## T-187: agregacja pomiaru krzywej po seedach (srednia, blad standardowy w pp, min/max).


## by_seed = {bracket: [pct_seed1, ...]}. Zwraca {mean, stderr_pp, min, max, n}.
static func summarize(by_seed: Dictionary) -> Dictionary:
	var mean: Dictionary = {}
	var stderr_pp: Dictionary = {}
	var lo: Dictionary = {}
	var hi: Dictionary = {}
	var n: int = 0
	for b: String in by_seed:
		var vals: Array = by_seed[b]
		n = vals.size()
		var sum: float = 0.0
		for v: float in vals:
			sum += v
		var m: float = sum / float(maxi(n, 1))
		var se: float = 0.0
		if n > 1:
			var sq: float = 0.0
			for v: float in vals:
				sq += (v - m) * (v - m)
			se = sqrt(sq / float(n - 1)) / sqrt(float(n))
		mean[b] = m
		stderr_pp[b] = se
		lo[b] = vals.min() if n > 0 else 0.0
		hi[b] = vals.max() if n > 0 else 0.0
	return {"mean": mean, "stderr_pp": stderr_pp, "min": lo, "max": hi, "n": n}
