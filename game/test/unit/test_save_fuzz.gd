extends GdUnitTestSuite
## T-206: deterministic fuzz of save.json reading (SaveSystem.load and a full App start).

const SAVE_PATH: String = "user://test_save_fuzz.json"
const SEED: int = 206
const CASES: int = 500
const APP_CASES: int = 20
const KINDS: int = 9
const BIG: int = GameState.MAX_SAVE_INT

var _old_path: String
var _prev_analytics: AnalyticsProvider
var _base_cache: Dictionary = {}


func before_test() -> void:
	GameConfig.reset()
	_prev_analytics = Analytics.provider
	Analytics.provider = FakeAnalyticsProvider.new()
	_old_path = SaveSystem.save_path
	SaveSystem.save_path = SAVE_PATH
	TestSaveCleanup.remove(SAVE_PATH)


func after_test() -> void:
	TestSaveCleanup.remove(SAVE_PATH)
	SaveSystem.save_path = _old_path
	Analytics.provider = _prev_analytics


func _base() -> Dictionary:
	if not _base_cache.is_empty():
		return _base_cache.duplicate(true)
	var s := GameState.new()
	s.coins = 1234
	s.level = 30
	s.streak_days = 5
	s.themes_owned = [GameState.DEFAULT_THEME, ThemeCatalog.ids()[1]]
	s.theme_active = ThemeCatalog.ids()[1]
	s.settings["tutorial_done"] = true
	var r := GameRound.new()
	r.start(ContentGenerator.new().generate(7, 30))
	var h: Vector2i = r.hint()
	r.try_move(h.x, h.y)
	s.round_in_progress = GameState.round_snapshot("campaign", 30, 20750, r)
	_base_cache = JSON.parse_string(JSON.stringify(s.to_dict()))
	return _base_cache.duplicate(true)


func _paths(node: Variant, prefix: Array, out: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for k: Variant in node:
			out.append(prefix + [k])
			_paths(node[k], prefix + [k], out)
	elif typeof(node) == TYPE_ARRAY:
		for i in (node as Array).size():
			out.append(prefix + [i])
			_paths(node[i], prefix + [i], out)


func _get_at(root: Variant, path: Array) -> Variant:
	var n: Variant = root
	for k: Variant in path:
		n = n[k]
	return n


## Returns [file_text, description] for mutation number `i` (kind = i % KINDS).
func _mutate(rng: RandomNumberGenerator, i: int) -> Array:
	var d: Dictionary = _base()
	var paths: Array = []
	_paths(d, [], paths)
	var path: Array = paths[rng.randi() % paths.size()]
	var parent: Variant = _get_at(d, path.slice(0, -1))
	var key: Variant = path[-1]
	var kind: int = i % KINDS
	var desc: String = "kind %d at %s" % [kind, str(path)]
	match kind:
		0:
			if typeof(parent) == TYPE_DICTIONARY:
				(parent as Dictionary).erase(key)
			else:
				(parent as Array).remove_at(key)
		1:
			var reps: Array = [0, "x", [1], {"a": 1}, null, true, 1.5]
			parent[key] = reps[rng.randi() % reps.size()]
		2:
			parent[key] = -1 - rng.randi() % 1000
		3:
			parent[key] = BIG + 1 + rng.randi() % 1000000
		4:
			parent[key] = [NAN, INF, -INF][rng.randi() % 3]
		5, 6:
			var text: String = JSON.stringify(d)
			var bytes: PackedByteArray = text.to_utf8_buffer()
			if kind == 5:
				return [bytes.slice(0, rng.randi() % bytes.size()).get_string_from_utf8(), desc]
			for _n in 1 + rng.randi() % 8:
				bytes[rng.randi() % bytes.size()] = rng.randi() % 256
			return [bytes.get_string_from_utf8(), desc]
		7:
			var rnd: Dictionary = d["round_in_progress"]["round"]
			match rng.randi() % 4:
				0:
					rnd["tubes"] = (rnd["tubes"] as Array).slice(1)
				1:
					rnd["tubes"][0] = [99, 99, 99, 99, 99]
				2:
					rnd["moves"] = -3
				3:
					rnd["tubes"][0].append(rng.randi_range(50, 90))
			desc = "bad round %s" % str(rnd.get("moves"))
		8:
			d["schema_version"] = [0, 99, "3", -1][rng.randi() % 4]
	return [JSON.stringify(d), desc]


func _write(text: String) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check_invariants(s: GameState) -> String:
	if s.coins < 0 or s.coins > BIG:
		return "coins %d" % s.coins
	if s.level < 1:
		return "level %d" % s.level
	if s.streak_days < 0:
		return "streak %d" % s.streak_days
	if not ThemeCatalog.ids().has(s.theme_active) and s.theme_active != GameState.DEFAULT_THEME:
		return "theme %s" % s.theme_active
	var rip: Dictionary = s.round_in_progress
	# The snapshot is validated lazily on resume (Level.resume); here it must be safe to try.
	if rip.get("round") is Dictionary:
		var r: GameRound = GameRound.from_dict(rip["round"])
		if r != null:
			var cap: int = r.board().capacity
			var counts: Dictionary = {}
			for t: Array in r.board().to_tubes():
				for c: int in t:
					counts[c] = int(counts.get(c, 0)) + 1
			for c: int in counts:
				if counts[c] != cap:
					return "color %d has %d != %d units" % [c, counts[c], cap]
	return ""


func test_load_survives_500_mutations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in CASES:
		var m: Array = _mutate(rng, i)
		_write(m[0])
		var s: GameState = SaveSystem.load()
		if s == null:
			fail("case %d (seed %d): load returned null; %s" % [i, SEED, m[1]])
			return
		var bad: String = _check_invariants(s)
		if not bad.is_empty():
			fail("case %d (seed %d): invariant %s; %s" % [i, SEED, bad, m[1]])
			return
		TestSaveCleanup.remove(SAVE_PATH)


func test_app_starts_on_mutated_saves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	for i in APP_CASES:
		var m: Array = _mutate(rng, i)
		_write(m[0])
		var app := App.new()
		app.clock = TestClock.fixed()
		add_child(app)
		var name: String = app.current_screen_name()
		if not name in ["home", "level"]:
			fail("app case %d (seed %d): screen '%s'; %s" % [i, SEED + 1, name, m[1]])
		remove_child(app)
		app.free()
		TestSaveCleanup.remove(SAVE_PATH)
	await get_tree().process_frame
