extends SceneTree
## Pomiar T-210: czas GameRound.hint() / moves_to_goal() na stanach w trakcie rundy (ANR).
## Reczny, poza `make test` (z korzenia repo):
##   timeout 900 .tools/godot --headless --path game --script res://test/perf/measure_hint.gd \
##     -- --out test/reports/hint_perf.json
## Stany: 0/25/50/75 % ruchow przebiegu greedy (seed 42) na poziomach kampanii i Poziomach dnia.
## Kazdy pomiar na SWIEZYM GameRound (pusty cache), mediana z REPEATS prob.

const CAMPAIGN_LEVELS: Array = [8, 26, 40, 56, 80, 120]
const DAYS: Array = [20750, 20751, 20752]
const PROGRESS: Array = [0, 25, 50, 75]
const BOT_SEED: int = 42
const REPEATS: int = 5
const MAX_STEPS: int = 400
const USEC_PER_MS: float = 1000.0
const P95_Q: float = 0.95
const BRACKETS: Array = ["8-25", "26-55", "56+", "daily"]
const GATE_P95_MS: float = 100.0
const GATE_MAX_MS: float = 500.0

## Skrypty ladowane dynamicznie w _initialize: statyczne nazwy klas kompiluja sie przed
## rejestracja autoloadu GameConfig (jak w measure_curve.gd).
var _round_cls: GDScript
var _solver_cls: GDScript
var _bot_cls: GDScript
var _job_cls: GDScript


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = "test/reports/hint_perf.json"
	var idx: int = args.find("--out")
	if idx >= 0 and idx + 1 < args.size():
		out_path = args[idx + 1]
	var lim: int = args.find("--limit")
	if lim >= 0 and lim + 1 < args.size():
		_cfg().set_for_test("hint_solver_max_states", int(args[lim + 1]))
	_round_cls = load("res://src/core/game_round.gd")
	_solver_cls = load("res://src/core/sort_solver.gd")
	_bot_cls = load("res://test/integration/playtest_bot.gd")
	_job_cls = load("res://src/systems/hint_job.gd")
	var gen_cls: GDScript = load("res://src/systems/content_generator.gd")
	var daily_cls: GDScript = load("res://src/systems/daily_challenge.gd")
	var seed_value: int = int(_cfg().get_value("campaign_seed"))
	var rows: Array = []
	for lv: int in CAMPAIGN_LEVELS:
		var data: Dictionary = gen_cls.new().generate(seed_value, lv)
		rows.append_array(_measure_level(data, lv, "campaign", _bracket(lv)))
	for day: int in DAYS:
		rows.append_array(_measure_level(daily_cls.level_for_day(day), day, "daily", "daily"))
	var summary: Dictionary = _summary(rows)
	var report: Dictionary = {
		"limit": int(_cfg().get_value("hint_solver_max_states")),
		"summary": summary,
		"states": rows,
	}
	var abs_path: String = ProjectSettings.globalize_path("res://").path_join(out_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("| przedzial | n | hint med/p95/max ms | moves_to_goal med/p95/max ms | bramka |")
	for b: String in BRACKETS:
		var s: Dictionary = summary[b]
		var h: Array = s["hint_ms"]
		var m: Array = s["moves_to_goal_ms"]
		print("| %s | %d | %s | %s | %s |" % [b, s["n"], _fmt(h), _fmt(m), s["gate"]])
	print("| przedzial | HintJob.request (watek glowny) med/p95/max ms | do wyniku (worker) |")
	for b: String in BRACKETS:
		print("| %s | %s | %s |" % [b, _fmt(summary[b]["main_ms"]), _fmt(summary[b]["worker_ms"])])
	print("zapisano: ", abs_path)
	quit()


func _cfg() -> Node:
	return root.get_node("GameConfig")


func _bracket(level: int) -> String:
	if level >= 56:
		return "56+"
	return "26-55" if level >= 26 else "8-25"


func _measure_level(data: Dictionary, level: int, mode: String, bracket: String) -> Array:
	var states: Array = _greedy_snapshots(data)
	print("poziom ", level, " (", mode, "): ", states.size(), " stanow")
	var rows: Array = []
	for i in states.size():
		var snap: Dictionary = states[i]
		var hint_us: Array = []
		var goal_us: Array = []
		for _r in REPEATS:
			var r: RefCounted = _round_cls.from_dict(snap)
			var t0: int = Time.get_ticks_usec()
			r.hint()
			hint_us.append(Time.get_ticks_usec() - t0)
			r = _round_cls.from_dict(snap)
			t0 = Time.get_ticks_usec()
			var moves: int = r.moves_to_goal()
			goal_us.append(Time.get_ticks_usec() - t0)
		var probe: RefCounted = _round_cls.from_dict(snap)
		var limit: int = int(_cfg().get_value("hint_solver_max_states"))
		var first: Dictionary = _solver_cls.solve(probe.board(), limit, _solver_cls.EXACT_WEIGHT)
		(
			rows
			. append(
				{
					"level": level,
					"mode": mode,
					"bracket": bracket,
					"progress_pct": PROGRESS[i],
					"hint_ms": _median(hint_us) / USEC_PER_MS,
					"async_ms": _measure_async(snap),
					"moves_to_goal_ms": _median(goal_us) / USEC_PER_MS,
					"moves": probe.moves_to_goal(),
					"exact": int(first["moves"]) > 0,
					"states_expanded": int(first["expanded"]),
				}
			)
		)
	return rows


## T-222: [czas request() na watku glownym, czas do wyniku] w ms (mediana z REPEATS).
func _measure_async(snap: Dictionary) -> Array:
	var main_us: Array = []
	var total_us: Array = []
	for _r in REPEATS:
		var board: RefCounted = _round_cls.from_dict(snap).board()
		var job: RefCounted = _job_cls.new()
		var t0: int = Time.get_ticks_usec()
		job.request(board, int(_cfg().get_value("hint_solver_max_states")), 3.0)
		main_us.append(Time.get_ticks_usec() - t0)
		while job.poll().is_empty():
			OS.delay_msec(1)
		total_us.append(Time.get_ticks_usec() - t0)
	return [_median(main_us) / USEC_PER_MS, _median(total_us) / USEC_PER_MS]


## Snapshoty (to_dict) po 0/25/50/75 % ruchow przebiegu greedy (seed 42, bez cofania).
func _greedy_snapshots(data: Dictionary) -> Array:
	var r: RefCounted = _round_cls.new()
	r.start(data)
	var rng := RandomNumberGenerator.new()
	rng.seed = BOT_SEED
	var snaps: Array = [r.to_dict()]
	var prev: Vector2i = Vector2i(-1, -1)
	while not r.is_done() and r.moves() < MAX_STEPS:
		var legal: Array[Vector2i] = r.board().legal_moves()
		if legal.is_empty():
			break
		prev = _bot_cls.pick_greedy(r.board(), legal, prev, rng)
		r.try_move(prev.x, prev.y)
		snaps.append(r.to_dict())
	var total: int = snaps.size() - 1
	var out: Array = []
	for pct: int in PROGRESS:
		out.append(snaps[total * pct / 100])
	return out


func _summary(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for b: String in BRACKETS:
		var h: Array = []
		var m: Array = []
		var am: Array = []
		var aw: Array = []
		for row: Dictionary in rows:
			if row["bracket"] == b:
				h.append(row["hint_ms"])
				m.append(row["moves_to_goal_ms"])
				am.append(row["async_ms"][0])
				aw.append(row["async_ms"][1])
		var hs: Array = _stats(h)
		var ms: Array = _stats(m)
		var ok: bool = hs[1] <= GATE_P95_MS and ms[1] <= GATE_P95_MS
		ok = ok and hs[2] <= GATE_MAX_MS and ms[2] <= GATE_MAX_MS
		out[b] = {
			"n": h.size(),
			"hint_ms": hs,
			"moves_to_goal_ms": ms,
			"main_ms": _stats(am),
			"worker_ms": _stats(aw),
			"gate": "OK" if ok else "FAIL",
		}
	return out


## [mediana, p95, max] posortowanej listy.
func _stats(v: Array) -> Array:
	v.sort()
	if v.is_empty():
		return [0.0, 0.0, 0.0]
	var p95: int = clampi(ceili(v.size() * P95_Q) - 1, 0, v.size() - 1)
	return [_median_sorted(v), v[p95], v[v.size() - 1]]


func _median(v: Array) -> float:
	v.sort()
	return _median_sorted(v)


func _median_sorted(v: Array) -> float:
	return float(v[v.size() / 2])


func _fmt(s: Array) -> String:
	return "%.1f / %.1f / %.1f" % [s[0], s[1], s[2]]
