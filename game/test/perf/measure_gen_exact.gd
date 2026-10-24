extends SceneTree
## Pomiar T-129 (gen_exact_max_colors x gen_exact_state_budget) i T-166 (wariant A:
## gen_quick_state_budget; wariant B - flaga exact_full_budget_in_quick - zmierzony jednorazowo
## i usuniety z kodu, wyniki w docs/GDD.md, Generator contentu). Reczny, poza `make test`:
##   cd game && ../.tools/godot --headless --path . --script res://test/perf/measure_gen_exact.gd
## Kampania 1..200 (seed campaign_seed) i Poziom dnia 20750..20779. exact_26_37 = odsetek
## poziomow 26..37 z min_moves_exact; quick_26_37 = przyblizenie "rozstrzyga szybki przebieg":
## expanded <= gen_quick_state_budget (expanded dotyczy ostatniego, zwyciskiego solve).

const BASE_COLORS: int = 6
const BASE_BUDGET: int = 1000
const QUICK_BUDGET_GRID: Array = [250, 500, 1000, 2000]
const GOLDEN_LEVELS: Array = [1, 2, 10, 50]
const LEVELS: int = 200
const FIRST_DAY: int = 20750
const DAYS: int = 30
const MID_FIRST: int = 26
const MID_LAST: int = 37

var _base_tubes: Dictionary = {}


func _initialize() -> void:
	var cfg: Node = root.get_node("GameConfig")
	var gen: RefCounted = load("res://src/systems/content_generator.gd").new()
	cfg.reset()
	var seed_value: int = int(cfg.get_value("campaign_seed"))
	for lv in GOLDEN_LEVELS:
		_base_tubes[lv] = gen.generate(seed_value, lv)["payload"]["tubes"]
	cfg.apply_remote({"gen_exact_max_colors": BASE_COLORS, "gen_exact_state_budget": BASE_BUDGET})
	print(_measure(cfg, gen, "GEN_EXACT colors=%d budget=%d" % [BASE_COLORS, BASE_BUDGET], true))
	for q in QUICK_BUDGET_GRID:
		cfg.reset()
		cfg.apply_remote({"gen_quick_state_budget": q})
		print(_measure(cfg, gen, "GEN_QUICK quick=%d" % q, false))
	cfg.reset()
	quit()


func _measure(cfg: Node, gen: RefCounted, label: String, with_quick: bool) -> String:
	var seed_value: int = int(cfg.get_value("campaign_seed"))
	var quick_budget: int = int(cfg.get_value("gen_quick_state_budget"))
	var camp: Array = []
	var daily: Array = []
	var expanded_total: int = 0
	var exact_mid: int = 0
	var quick_mid: int = 0
	var exact_daily: int = 0
	var changed: Array = []
	for lv in range(1, LEVELS + 1):
		var t0: int = Time.get_ticks_usec()
		var p: Dictionary = gen.generate(seed_value, lv)["payload"]
		camp.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		expanded_total += int(p["expanded"])
		if lv >= MID_FIRST and lv <= MID_LAST:
			exact_mid += 1 if p["min_moves_exact"] else 0
			quick_mid += 1 if int(p["expanded"]) <= quick_budget else 0
	for lv in GOLDEN_LEVELS:
		if gen.generate(seed_value, lv)["payload"]["tubes"] != _base_tubes[lv]:
			changed.append(lv)
	for day in range(FIRST_DAY, FIRST_DAY + DAYS):
		var t0: int = Time.get_ticks_usec()
		var p: Dictionary = gen.generate_daily(day)["payload"]
		daily.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		exact_daily += 1 if p["min_moves_exact"] else 0
	var line: String = (
		(
			"%s camp_med_ms=%.1f camp_p95_ms=%.1f daily_med_ms=%.1f daily_p95_ms=%.1f "
			+ "expanded_total=%d exact_26_37=%d/12 exact_daily=%d/30 golden_changed=%s"
		)
		% [
			label,
			_pct(camp, 0.5),
			_pct(camp, 0.95),
			_pct(daily, 0.5),
			_pct(daily, 0.95),
			expanded_total,
			exact_mid,
			exact_daily,
			str(changed),
		]
	)
	if with_quick:
		line += " quick_26_37=%d/12" % quick_mid
	return line


func _pct(values: Array, q: float) -> float:
	var s: Array = values.duplicate()
	s.sort()
	return float(s[mini(s.size() - 1, int(q * s.size()))])
