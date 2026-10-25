extends Node
## Autoload "GameConfig": all balance parameters, overridable by remote config.

const DEFAULTS: Dictionary = {
	# Ads
	"interstitial_every_n_rounds": 5,
	"interstitial_min_seconds": 120,
	"interstitial_min_level": 8,
	"ad_unmute_timeout_seconds": 90,
	"consent_timeout_seconds": 8,
	"consent_form_timeout_seconds": 120,
	# Ad load retry (T-224, ADR-013): backoff base * 2^(n-1), capped, give up after N failures
	"ad_load_retry_base_seconds": 2,
	"ad_load_retry_max_seconds": 64,
	"ad_load_max_retries": 6,
	"ad_max_age_seconds": 3300,
	"rewarded_multiplier": 2.0,
	"rewarded_double_coins_min_level": 2,
	"rewarded_undo_refill_max_per_level": 2,
	"rewarded_double_coins_max_per_level": 1,
	"rewarded_skip_max_per_level": 1,
	# Economy
	"daily_reward_base": 50,
	"starting_coins": 100,
	"win_reward_coins": 15,
	# Economy (GDD v1.0)
	"par_bonus_coins": 10,
	"hint_cost_coins": 25,
	"extra_tube_cost_coins": 60,
	"undo_refill_cost_coins": 20,
	"theme_cost_base": 600,
	"theme_cost_growth": 1.8,
	"daily_challenge_coins": 50,
	"daily_unlock_level": 3,
	# T-259: 20 -> 15 (make sim: K=6 59,5 %, K=7 86,1 % graczy; przy 20 tylko 3,0 % / 20,6 %)
	"daily_month_goal": 15,
	# T-296: max raportow bledow skryptu na sesje (0 = wylaczone)
	"error_report_max_per_session": 10,
	"daily_month_goal_coins": 300,
	# Local notifications (T-150)
	"notif_local_hour": 19,
	"notif_streak_min_days": 2,
	"notif_comeback_days": 3,
	# Session
	"session_target_seconds": 180,
	# Difficulty curve (logistic)
	"difficulty_min": 0.1,
	"difficulty_max": 1.0,
	"difficulty_midpoint_level": 20,
	"difficulty_steepness": 0.15,
	# Generator / progression (GDD v1.0)
	"tube_capacity": 4,
	"empty_tubes": 2,
	"tutorial_colors": 2,
	"colors_start": 3,
	"colors_max": 12,
	"levels_per_extra_color": 6,
	"breather_every": 5,
	"breather_factor": 0.65,
	"min_moves_factor_easy": 1.2,
	"min_moves_factor_hard": 2.0,
	"gen_max_attempts": 20,
	# Solver stages: states in the quick pass / exact A* budget / exact only up to N colors
	"gen_quick_state_budget": 250,
	"gen_exact_state_budget": 1000,
	"gen_exact_max_colors": 6,
	# Jak wyżej, ale dla Poziomu dnia (T-180): osobny limit, bo daily liczy się w czasie żądania
	"gen_exact_max_colors_daily": 6,
	"solver_max_states": 50000,
	"solver_fallback_weight": 3.0,
	"campaign_seed": 1,
	"daily_seed_salt": 104729,
	"daily_colors": 8,
	"daily_min_moves_factor": 1.8,
	# Round / boosters (GDD v1.0)
	"undo_free_per_level": 3,
	"undo_refill_amount": 3,
	"extra_tube_max_per_level": 1,
	"plateau_assist_min_level": 26,
	"plateau_assist_from_attempt": 2,
	"skip_unlock_restarts": 2,
	"par_slack_moves": 2,
	"hint_solver_max_states": 20000,
	# T-237: budżet exact tylko dla podpowiedzi; moves_to_goal() używa hint_solver_max_states
	"hint_exact_max_states": 2000,
	# Daily / streak (GDD v1.0)
	"daily_reward_multipliers": [1, 1, 2, 2, 3, 3, 6],
	"streak_save_max_per_week": 1,
	"streak_save_window_days": 7,
	"streak_grace_days": 1,
	# UI (GDD v1.0)
	"pour_anim_seconds": 0.4,
	"tube_lift_seconds": 0.1,
	"shake_seconds": 0.2,
	"tube_full_pulse_seconds": 0.25,
	"confetti_seconds": 1.2,
	# T-235: bez ruchu przez tyle sekund przycisk podpowiedzi zaczyna pulsować
	"hint_nudge_seconds": 8.0,
	# IAP
	"iap_coins_small": 500,
	"iap_coins_large": 1500,
	"iap_coins_large_bonus_pct": 20,
	"iap_starter_coins": 800,
	"iap_starter_theme": "neon",
	"starter_offer_min_level": 12,
	"starter_offer_hours": 72,
	# Experiments (T-142): variant label logged as design event config:variant:<v>
	"remote_config_variant": "default",
}

## Accepted remote range [min, max] per numeric key (T-135); out-of-range values are rejected.
const RANGES: Dictionary = {
	"interstitial_every_n_rounds": [1, 1000],
	"interstitial_min_seconds": [0, 86400],
	"interstitial_min_level": [0, 1000],
	"ad_unmute_timeout_seconds": [0, 86400],
	"consent_timeout_seconds": [0, 86400],
	"consent_form_timeout_seconds": [10, 600],
	"ad_load_retry_base_seconds": [1, 60],
	"ad_load_retry_max_seconds": [1, 600],
	"ad_load_max_retries": [0, 50],
	"ad_max_age_seconds": [60, 86400],
	"rewarded_multiplier": [1.0, 5.0],
	"rewarded_double_coins_min_level": [0, 1000],
	"rewarded_undo_refill_max_per_level": [0, 100],
	"rewarded_double_coins_max_per_level": [0, 100],
	"rewarded_skip_max_per_level": [0, 100],
	"daily_reward_base": [0, 100000],
	"starting_coins": [0, 100000],
	"win_reward_coins": [0, 100000],
	"par_bonus_coins": [0, 100000],
	"hint_cost_coins": [0, 100000],
	"extra_tube_cost_coins": [0, 100000],
	"undo_refill_cost_coins": [0, 100000],
	"theme_cost_base": [0, 100000],
	"theme_cost_growth": [1.0, 5.0],
	"daily_challenge_coins": [0, 100000],
	"daily_unlock_level": [0, 1000],
	"daily_month_goal": [1, 31],
	"error_report_max_per_session": [0, 100],
	"daily_month_goal_coins": [0, 5000],
	"notif_local_hour": [0, 23],
	"notif_streak_min_days": [1, 365],
	"notif_comeback_days": [2, 14],
	"session_target_seconds": [0, 86400],
	"difficulty_min": [0.0, 1.0],
	"difficulty_max": [0.0, 1.0],
	"difficulty_midpoint_level": [0, 1000],
	"difficulty_steepness": [0.0, 10.0],
	"tube_capacity": [2, 6],
	"empty_tubes": [0, 4],
	"tutorial_colors": [1, 12],
	"colors_start": [1, 12],
	"colors_max": [1, 12],
	"levels_per_extra_color": [1, 1000],
	"breather_every": [1, 1000],
	"breather_factor": [0.0, 1.0],
	"min_moves_factor_easy": [0.0, 10.0],
	"min_moves_factor_hard": [0.0, 10.0],
	"gen_max_attempts": [1, 1000],
	"gen_quick_state_budget": [1, 200000],
	"gen_exact_state_budget": [1, 200000],
	"gen_exact_max_colors": [0, 12],
	"gen_exact_max_colors_daily": [0, 12],
	"solver_max_states": [1, 200000],
	"solver_fallback_weight": [1.0, 10.0],
	"campaign_seed": [0, 2147483647],
	"daily_seed_salt": [0, 2147483647],
	"daily_colors": [1, 12],
	"daily_min_moves_factor": [0.0, 10.0],
	"undo_free_per_level": [0, 100],
	"undo_refill_amount": [0, 100],
	"extra_tube_max_per_level": [0, 4],
	"plateau_assist_min_level": [1, 1000],
	"plateau_assist_from_attempt": [1, 20],
	"skip_unlock_restarts": [0, 100],
	"par_slack_moves": [-10, 100],
	"hint_solver_max_states": [1, 200000],
	"hint_exact_max_states": [250, 200000],
	"streak_save_max_per_week": [0, 7],
	"streak_save_window_days": [1, 365],
	"streak_grace_days": [0, 30],
	"pour_anim_seconds": [0.0, 5.0],
	"tube_lift_seconds": [0.0, 5.0],
	"shake_seconds": [0.0, 5.0],
	"tube_full_pulse_seconds": [0.0, 5.0],
	"confetti_seconds": [0.0, 5.0],
	"hint_nudge_seconds": [2.0, 120.0],
	"iap_coins_small": [0, 100000],
	"iap_coins_large": [0, 100000],
	"iap_coins_large_bonus_pct": [0, 100],
	"iap_starter_coins": [0, 100000],
	"starter_offer_min_level": [0, 1000],
	"starter_offer_hours": [0, 8760],
}

## Array-valued keys: required length and minimum element (ints).
const ARRAY_RULES: Dictionary = {
	"daily_reward_multipliers": {"size": 7, "min": 0},
}

## String-valued keys with a required format (regex); others only need to be non-empty.
const STRING_RULES: Dictionary = {
	"remote_config_variant": "^[a-z0-9_]{1,24}$",
}

var _values: Dictionary = DEFAULTS.duplicate(true)
var _revision: int = 0


func get_value(key: String, default: Variant = null) -> Variant:
	return _values.get(key, default)


## Gleboka kopia biezacych wartosci - dla watkow roboczych (ADR-015).
func snapshot() -> Dictionary:
	return _values.duplicate(true)


## Licznik zmian konfiguracji (reset, set_for_test, apply_remote z >= 1 zastosowanym kluczem).
func revision() -> int:
	return _revision


## Overrides known keys only; wrong types / out-of-range values are skipped.
## A batch that breaks the invariants is rolled back entirely (returns 0).
func apply_remote(remote: Dictionary) -> int:
	var applied: int = 0
	var next: Dictionary = _values.duplicate(true)
	for key: Variant in remote:
		if typeof(key) != TYPE_STRING or not DEFAULTS.has(key):
			continue
		var converted: Variant = _coerce(DEFAULTS[key], remote[key])
		if converted == null:
			push_warning("GameConfig: ignoring remote '%s' (bad type)" % key)
			continue
		if not _in_range(key, converted):
			push_warning("GameConfig: ignoring remote '%s' (out of range)" % key)
			continue
		next[key] = converted
		applied += 1
	if applied > 0 and not _invariants_ok(next):
		push_warning("GameConfig: remote batch breaks invariants, rolled back")
		return 0
	_values = next
	if applied > 0:
		_revision += 1
	return applied


func reset() -> void:
	_values = DEFAULTS.duplicate(true)
	_revision += 1


## TYLKO TESTY: ustawia wartosc z pominieciem RANGES/niezmiennikow (np. wartosc poza zakresem).
func set_for_test(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_error("GameConfig.set_for_test: unknown key '%s'" % key)
		return
	_values[key] = value
	_revision += 1


## Returns value converted to the default's type, or null if incompatible.
func _coerce(default: Variant, value: Variant) -> Variant:
	var want: int = typeof(default)
	var got: int = typeof(value)
	if want == got:
		return value
	if want == TYPE_FLOAT and got == TYPE_INT:
		return float(value)
	if want == TYPE_INT and got == TYPE_FLOAT and is_equal_approx(value, roundf(value)):
		return int(value)
	return null


func _string_ok(key: String, value: String) -> bool:
	if STRING_RULES.has(key):
		return RegEx.create_from_string(str(STRING_RULES[key])).search(value) != null
	return not value.is_empty()


func _in_range(key: String, value: Variant) -> bool:
	if value is String:
		return _string_ok(key, value)
	if value is Array:
		var rule: Dictionary = ARRAY_RULES.get(key, {})
		var arr: Array = value
		if rule.is_empty() or arr.size() != int(rule["size"]):
			return false
		for item: Variant in arr:
			if typeof(item) != TYPE_INT or int(item) < int(rule["min"]):
				return false
		return true
	if not RANGES.has(key):
		return true
	var bounds: Array = RANGES[key]
	return value >= bounds[0] and value <= bounds[1]


func _invariants_ok(v: Dictionary) -> bool:
	var tubes: int = (
		maxi(int(v["colors_max"]), int(v["daily_colors"]))
		+ int(v["empty_tubes"])
		+ int(v["extra_tube_max_per_level"])
	)
	return (
		tubes <= GameRound.ACTION_BASE
		and int(v["tutorial_colors"]) <= int(v["colors_start"])
		and int(v["colors_start"]) <= int(v["colors_max"])
		and float(v["difficulty_min"]) <= float(v["difficulty_max"])
		and int(v["ad_load_retry_base_seconds"]) <= int(v["ad_load_retry_max_seconds"])
		and int(v["hint_exact_max_states"]) <= int(v["hint_solver_max_states"])
	)
