class_name ThemeCatalog
extends RefCounted
## Katalog motywow z themes.json + zakup/aktywacja. Czysta logika (statyczna).
## Koszt zalezy od POZYCJI motywu w katalogu (pastel=600, neon=1080, ocean=1944),
## nie od kolejnosci zakupu - deterministycznie i czytelnie w UI.

const THEMES_PATH: String = "res://assets/themes.json"

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		_cache = _load()
	return _cache


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for t: Dictionary in all():
		out.append(str(t.get("id", "")))
	return out


static func theme(id: String) -> Dictionary:
	var list: Array = all()
	if list.is_empty():
		return {}
	for t: Dictionary in list:
		if t.get("id", "") == id:
			return t
	return list[0]


static func free_id() -> String:
	var list: Array = all()
	return "" if list.is_empty() else str((list[0] as Dictionary).get("id", ""))


## 1 dla pierwszego platnego, 2, 3...; 0 dla darmowego lub nieznanego.
static func paid_index(id: String) -> int:
	var i: int = ids().find(id)
	return maxi(i, 0)


static func cost(id: String) -> int:
	var idx: int = paid_index(id)
	return 0 if idx <= 0 else Economy.theme_cost(idx)


static func is_owned(state: GameState, id: String) -> bool:
	return state.owns_theme(id)


static func can_buy(state: GameState, id: String) -> bool:
	if not ids().has(id) or is_owned(state, id):
		return false
	return Economy.can_afford(state, cost(id))


static func buy(state: GameState, id: String) -> bool:
	if not ids().has(id) or is_owned(state, id):
		return false
	var price: int = cost(id)
	if not Economy.spend(state, price, Economy.SINK_THEME):
		return false
	state.themes_owned.append(id)
	Analytics.track_resource("Sink", "coins", price, "theme", id)
	Analytics.track_design("theme:unlocked:%s" % id)
	return true


static func set_active(state: GameState, id: String) -> bool:
	if not is_owned(state, id):
		return false
	state.theme_active = id
	return true


## Id najtanszego nieposiadanego motywu; "" gdy wszystkie posiadane.
static func next_theme_id(state: GameState) -> String:
	for id: String in ids():
		if not is_owned(state, id):
			return id
	return ""


static func next_theme_cost(state: GameState) -> int:
	var id: String = next_theme_id(state)
	return 0 if id == "" else cost(id)


static func _load() -> Array:
	var file := FileAccess.open(THEMES_PATH, FileAccess.READ)
	if file == null:
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for t: Dictionary in (data as Dictionary).get("themes", []):
		var d: Dictionary = t.duplicate()
		d["nine_slice"] = (data as Dictionary).get("nine_slice", {})
		out.append(d)
	return out
