extends SceneTree
## Pomiar T-179: start aplikacji (CI, nie urzadzenie). Reczny, poza `make test`:
##   .tools/godot --headless --path game -s res://test/perf/measure_startup.gd
## Pelne `App` z fake providerami i TestClock; save_path testowy. "Gotowy" = synchroniczny
## add_child/emit zwrocil: `Level._ready` -> `load_level`/`start_daily` -> `_bind_round`
## (plansza, HUD, input) albo `Home._ready` (karty zbudowane). Headless, bez renderu.
## Bez prefetchu = `App._drop_home_prefetch()` po wejsciu na Home (Level generuje synchronicznie).

const RUNS: int = 20
const SAVE_PATH: String = "user://test_startup_perf.json"
const RETURNING_LEVEL: int = 60
const POLL_MS: int = 2
const P95_IDX: int = 18  # 20 prob posortowanych: 19. wartosc
const MEDIAN_IDX: int = 10
const SCENARIOS: Array = [
	"a. 1. uruchomienie -> Level 1",
	"b1. powrot lvl 60 -> Home",
	"b2. Graj -> Level 60 (z prefetchem)",
	"b3. Graj -> Level 60 (bez prefetchu)",
	"c. Home -> Poziom dnia -> Level daily",
]

var _us: Dictionary = {}


func _initialize() -> void:
	root.get_node("SaveSystem").save_path = SAVE_PATH
	root.get_node("Analytics").provider = load("res://src/systems/fake_analytics_provider.gd").new()
	root.get_node("Ads").provider = load("res://src/systems/fake_ad_provider.gd").new()
	for s: String in SCENARIOS:
		_us[s] = []
	for _i in RUNS:
		_remove_save()
		var app: Control = _make_app(false)
		_us[SCENARIOS[0]].append(_timed_add(app))
		await _free_app(app)
		app = _make_app(true)
		_us[SCENARIOS[1]].append(_timed_add(app))
		_wait_prefetch(app)
		_us[SCENARIOS[2]].append(_timed_emit(app.current_screen().play_pressed))
		await _free_app(app)
		app = _make_app(true)
		_timed_add(app)
		app._drop_home_prefetch()
		_us[SCENARIOS[3]].append(_timed_emit(app.current_screen().play_pressed))
		await _free_app(app)
		app = _make_app(true)
		_timed_add(app)
		_us[SCENARIOS[4]].append(_timed_emit(app.current_screen().daily_pressed))
		await _free_app(app)
	_remove_save()
	print("| scenariusz | mediana ms | p95 ms |\n|---|---|---|")
	for s: String in SCENARIOS:
		var v: Array = _us[s]
		v.sort()
		print("| %s | %.1f | %.1f |" % [s, v[MEDIAN_IDX] / 1000.0, v[P95_IDX] / 1000.0])
	quit()


func _make_app(returning: bool) -> Control:
	var app: Control = load("res://src/core/app.gd").new()
	app.clock = load("res://test/helpers/test_clock.gd").fixed()
	app.effects_enabled = false
	app.notifications = load("res://src/systems/fake_notification_provider.gd").new()
	if returning:
		var st: RefCounted = load("res://src/core/game_state.gd").new()
		st.level = RETURNING_LEVEL
		st.settings["tutorial_done"] = true
		app.state = st
	return app


func _timed_add(app: Control) -> int:
	var t0: int = Time.get_ticks_usec()
	root.add_child(app)
	return Time.get_ticks_usec() - t0


func _timed_emit(sig: Signal) -> int:
	var t0: int = Time.get_ticks_usec()
	sig.emit()
	return Time.get_ticks_usec() - t0


func _wait_prefetch(app: Control) -> void:
	while not WorkerThreadPool.is_task_completed(app.home_prefetch._task_id):
		OS.delay_msec(POLL_MS)


func _free_app(app: Control) -> void:
	root.remove_child(app)
	app.free()
	await process_frame


func _remove_save() -> void:
	load("res://test/helpers/test_save_cleanup.gd").remove(SAVE_PATH)
