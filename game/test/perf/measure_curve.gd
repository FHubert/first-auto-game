extends SceneTree
## Pomiar T-162: krzywa trudnosci vs nadpisania GameConfig. Reczny, poza `make test`:
##   cd game && ../.tools/godot --headless --path . --script res://test/perf/measure_curve.gd
## Generator: kampania 1..200 (mediana/p95 ms, "floor_binding" w 56..85, kolory).
## Bot: greedy --stay, 3 seedy rng, przebieg A od poziomu 1, przebieg B od poziomu 56.

const GRID: Array = [
	{"label": "base", "overrides": {}},
	{"label": "mmfh_1.8", "overrides": {"min_moves_factor_hard": 1.8}},
	{"label": "mmfh_1.6", "overrides": {"min_moves_factor_hard": 1.6}},
	{"label": "dmax_0.85", "overrides": {"difficulty_max": 0.85}},
	{"label": "dmax_0.7", "overrides": {"difficulty_max": 0.7}},
	{"label": "cmax_11", "overrides": {"colors_max": 11}},
	{"label": "cmax_10", "overrides": {"colors_max": 10}},
	{"label": "info_empty_3", "overrides": {"empty_tubes": 3}},
]
## T-175: wiersz bazy + siatka "probowka od proby N" (uruchom z `-- --assist`).
const ASSIST_MIN_LEVELS: Array = [26, 56]
const ASSIST_FROM_ATTEMPTS: Array = [1, 2, 3]
const SEED_POOL: Array = [42, 7, 1, 1337, 2024, 99, 5, 11, 123, 314]
const DEFAULT_SEEDS: int = 3
const ROUNDS: int = 400
const LEVELS: int = 200
const PLATEAU_FIRST: int = 56
const PLATEAU_LAST: int = 85
const PLATEAU_SIZE: int = 30
const EARLY_BRACKETS: Array = ["1-7", "8-25", "26-55"]
const PLATEAU_BRACKET: String = "56+"
const GATE_B1_7: float = 100.0
const GATE_B8_25: float = 85.0
const GATE_B26_55: float = 50.0
const GATE_B56: float = 35.0
const GATE_P95_MS: float = 250.0
const PERCENT: float = 100.0
const MEDIAN_Q: float = 0.5
const P95_Q: float = 0.95

var _extra_from: int = 0
var _extra_min: int = 1
var _seeds: Array = []
var _assist: bool = false
var _out_name: String = "curve_assist.json"


func _initialize() -> void:
	var cfg: Node = root.get_node("GameConfig")
	var grid: Array = GRID
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_assist = "--assist" in args
	_seeds = SEED_POOL.slice(
		0, clampi(int(_arg(args, "--seeds", DEFAULT_SEEDS)), 1, SEED_POOL.size())
	)
	_out_name = str(_arg(args, "--out", _out_name))
	if _assist:
		grid = [{"label": "base", "overrides": {}}]
		for min_level: int in ASSIST_MIN_LEVELS:
			for from_attempt: int in ASSIST_FROM_ATTEMPTS:
				(
					grid
					. append(
						{
							"label": "assist_min%d_from%d" % [min_level, from_attempt],
							"overrides": {},
							"extra_from": from_attempt,
							"extra_min_level": min_level,
						}
					)
				)
		if int(_arg(args, "--extra-tube-from", -1)) >= 0:
			var from_n: int = int(_arg(args, "--extra-tube-from", 0))
			var min_lv: int = int(
				_arg(args, "--extra-tube-min-level", cfg.get_value("plateau_assist_min_level"))
			)
			grid = [
				{
					"label": "assist_min%d_from%d" % [min_lv, from_n],
					"overrides": {},
					"extra_from": from_n,
					"extra_min_level": min_lv,
				}
			]
	for entry: Dictionary in grid:
		_extra_from = int(entry.get("extra_from", 0))
		_extra_min = int(entry.get("extra_min_level", 1))
		cfg.reset()
		cfg.apply_remote(entry["overrides"])
		_measure(cfg, str(entry["label"]))
	cfg.reset()
	quit()


## Wartosc flagi `--name N` z user args albo `default`.
func _arg(args: PackedStringArray, name: String, default: Variant) -> Variant:
	var i: int = args.find(name)
	if i < 0:
		return default
	if i + 1 >= args.size():
		return default
	return args[i + 1]


func _measure(cfg: Node, label: String) -> void:
	var gen: RefCounted = load("res://src/systems/content_generator.gd").new()
	var seed_value: int = int(cfg.get_value("campaign_seed"))
	var times: Array = []
	var binding: int = 0
	var colors_56: int = 0
	var colors_85: int = 0
	for lv in range(1, LEVELS + 1):
		var t0: int = Time.get_ticks_usec()
		var p: Dictionary = gen.generate(seed_value, lv)["payload"]
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if lv < PLATEAU_FIRST or lv > PLATEAU_LAST:
			continue
		if (
			int(p["attempt"]) > 0
			or int(p["min_moves"]) < int(p["min_moves_floor"])
			or bool(p.get("fallback", false))
		):
			binding += 1
		if lv == PLATEAU_FIRST:
			colors_56 = int(p["colors"])
		if lv == PLATEAU_LAST:
			colors_85 = int(p["colors"])
	var by_seed: Dictionary = {}
	var rounds: Dictionary = {}
	for b: String in EARLY_BRACKETS + [PLATEAU_BRACKET]:
		by_seed[b] = []
		rounds[b] = 0
	for s: int in _seeds:
		var rep_a: Dictionary = _run_bot(1, s)
		var rep_b: Dictionary = _run_bot(PLATEAU_FIRST, s)
		for b: String in EARLY_BRACKETS:
			by_seed[b].append(_emit(label, s, b, rep_a))
			rounds[b] += _closed(rep_a, b)
		by_seed[PLATEAU_BRACKET].append(_emit(label, s, PLATEAU_BRACKET, rep_b))
		rounds[PLATEAU_BRACKET] += _closed(rep_b, PLATEAU_BRACKET)
	var st: Dictionary = CurveStats.summarize(by_seed)
	var a1: float = st["mean"]["1-7"]
	var a2: float = st["mean"]["8-25"]
	var a3: float = st["mean"]["26-55"]
	var a4: float = st["mean"][PLATEAU_BRACKET]
	var med: float = _pct(times, MEDIAN_Q)
	var p95: float = _pct(times, P95_Q)
	print(
		(
			(
				"CURVE_AVG cfg=%s b1_7=%.1f b8_25=%.1f b26_55=%.1f b56=%.1f gen_med_ms=%.1f "
				+ "gen_p95_ms=%.1f floor_binding_56_85=%d/%d colors_56=%d colors_85=%d "
				+ "seeds=%d se56=%.1f se26_55=%.1f"
			)
			% [
				label,
				a1,
				a2,
				a3,
				a4,
				med,
				p95,
				binding,
				PLATEAU_SIZE,
				colors_56,
				colors_85,
				_seeds.size(),
				st["stderr_pp"][PLATEAU_BRACKET],
				st["stderr_pp"]["26-55"]
			]
		)
	)
	var ok: bool = (
		a1 >= GATE_B1_7
		and a2 >= GATE_B8_25
		and a3 >= GATE_B26_55
		and a4 >= GATE_B56
		and p95 <= GATE_P95_MS
	)
	print("GATE cfg=%s pass=%s" % [label, str(ok).to_lower()])
	if _assist:
		_write_json(label, by_seed, st, rounds)


func _write_json(label: String, by_seed: Dictionary, st: Dictionary, rounds: Dictionary) -> void:
	var data: Dictionary = {
		"config":
		{
			"min_level": _extra_min,
			"from_attempt": _extra_from,
			"seeds": _seeds,
			"label": label,
		},
		"won_le3_pct_by_bracket": st["mean"],
		"won_le3_pct_by_seed": by_seed,
		"stderr_pp_by_bracket": st["stderr_pp"],
		"min_pct_by_bracket": st["min"],
		"max_pct_by_bracket": st["max"],
		"rounds_by_bracket": rounds,
	}
	var path: String = "res://test/reports/" + _out_name
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("CURVE_JSON path=%s label=%s" % [path, label])


func _run_bot(start_level: int, rng_seed: int) -> Dictionary:
	var bot: RefCounted = load("res://test/integration/playtest_bot.gd").new()
	bot.use_campaign_seed = true
	bot.stay_on_level = true
	bot.start_level = start_level
	bot.extra_tube_from_attempt = _extra_from
	bot.extra_tube_min_level = _extra_min
	return bot.run(ROUNDS, rng_seed, "greedy")


func _closed(rep: Dictionary, bracket: String) -> int:
	return int(rep["levels_won_by_bracket"][bracket]) + int(rep["skips_by_bracket"][bracket])


## Prints one CURVE line, returns within_3 percent.
func _emit(label: String, rng_seed: int, bracket: String, rep: Dictionary) -> float:
	var won: int = int(rep["levels_won_by_bracket"][bracket])
	var skips: int = int(rep["skips_by_bracket"][bracket])
	var closed: int = won + skips
	var first_pct: float = 0.0
	var within_pct: float = 0.0
	if closed > 0:
		first_pct = float(rep["won_first_try_by_bracket"][bracket]) / float(closed) * PERCENT
		within_pct = float(rep["won_within_3_by_bracket"][bracket]) / float(closed) * PERCENT
	print(
		(
			(
				"CURVE cfg=%s seed=%d bracket=%s closed=%d won=%d first_try_pct=%.1f "
				+ "within_3_pct=%.1f median_attempts=%.1f skips=%d"
			)
			% [
				label,
				rng_seed,
				bracket,
				closed,
				won,
				first_pct,
				within_pct,
				float(rep["median_attempts_by_bracket"][bracket]),
				skips
			]
		)
	)
	return within_pct


func _pct(values: Array, q: float) -> float:
	var s: Array = values.duplicate()
	s.sort()
	return float(s[mini(s.size() - 1, int(q * s.size()))])
