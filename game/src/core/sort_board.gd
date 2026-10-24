class_name SortBoard
extends RefCounted
## Model planszy water sort (czysta logika, bez Node).
## Probówka = Array intów, indeks 0 = dół, ostatni = góra. Kolory 0..n-1.

const DEFAULT_CAPACITY: int = 4

var tubes: Array = []
var capacity: int = DEFAULT_CAPACITY
## Liczba jednostek przelanych w ostatnim udanym `pour` (0 po nieudanym).
var last_pour_amount: int = 0


func _init(tubes_in: Array = [], capacity_in: int = DEFAULT_CAPACITY) -> void:
	capacity = capacity_in
	tubes = _deep_copy(tubes_in)


## Buduje planszę z payloadu generatora ({capacity, tubes}).
static func from_payload(payload: Dictionary) -> SortBoard:
	var cap: int = int(payload.get("capacity", DEFAULT_CAPACITY))
	var raw: Array = payload.get("tubes", [])
	return SortBoard.new(raw, cap)


func tube_count() -> int:
	return tubes.size()


## Dodaje pustą probówkę na końcu.
func add_empty_tube() -> void:
	tubes.append([])


## Kolor na górze probówki lub -1 gdy pusta.
func top_color(i: int) -> int:
	var t: Array = tubes[i]
	return -1 if t.is_empty() else int(t[t.size() - 1])


## Liczba jednostek koloru górnego z rzędu od góry (0 gdy pusta).
func top_run(i: int) -> int:
	var t: Array = tubes[i]
	if t.is_empty():
		return 0
	var c: int = int(t[t.size() - 1])
	var n: int = 0
	for k in range(t.size() - 1, -1, -1):
		if int(t[k]) != c:
			break
		n += 1
	return n


func free_space(i: int) -> int:
	return capacity - (tubes[i] as Array).size()


func is_empty(i: int) -> bool:
	return (tubes[i] as Array).is_empty()


func is_full(i: int) -> bool:
	return free_space(i) <= 0


## Niepusta i jednokolorowa.
func is_uniform(i: int) -> bool:
	return not is_empty(i) and top_run(i) == (tubes[i] as Array).size()


func can_pour(from: int, to: int) -> bool:
	if from == to:
		return false
	if from < 0 or to < 0 or from >= tubes.size() or to >= tubes.size():
		return false
	if is_empty(from) or is_full(to):
		return false
	if not is_empty(to) and top_color(from) != top_color(to):
		return false
	if is_uniform(from) and (is_empty(to) or is_full(from)):
		return false  # no-op strukturalny / rozwiązana probówka
	return true


## Przelewa górną serię w granicach wolnego miejsca. Nielegalny ruch: false, brak zmian.
func pour(from: int, to: int) -> bool:
	last_pour_amount = 0
	if not can_pour(from, to):
		return false
	var amount: int = mini(top_run(from), free_space(to))
	var color: int = top_color(from)
	var src: Array = tubes[from]
	var dst: Array = tubes[to]
	for _k in amount:
		src.pop_back()
		dst.append(color)
	last_pour_amount = amount
	return true


## Każda probówka pusta albo pełna i jednokolorowa. Pusta plansza = wygrana.
func is_won() -> bool:
	for i in tubes.size():
		if is_empty(i):
			continue
		if not (is_full(i) and is_uniform(i)):
			return false
	return true


## Legalne ruchy (bez no-opów), rosnąco po from, potem to.
func legal_moves() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for f in tubes.size():
		for t in tubes.size():
			if can_pour(f, t):
				out.append(Vector2i(f, t))
	return out


## Klucz stanu niezależny od kolejności probówek (do visited-set solvera).
func canonical_key() -> String:
	var parts: Array[String] = []
	for t in tubes:
		var strs: PackedStringArray = PackedStringArray()
		for c in t:
			strs.append(str(int(c)))
		parts.append(",".join(strs))
	parts.sort()
	return "|".join(parts)


func clone() -> SortBoard:
	return SortBoard.new(tubes, capacity)


func to_tubes() -> Array:
	return _deep_copy(tubes)


func color_count() -> int:
	var seen: Dictionary = {}
	for t in tubes:
		for c in t:
			seen[int(c)] = true
	return seen.size()


## Każda probówka <= capacity, kolory >= 0.
func is_valid() -> bool:
	for t in tubes:
		if (t as Array).size() > capacity:
			return false
		for c in t:
			if int(c) < 0:
				return false
	return true


static func _deep_copy(src: Array) -> Array:
	var out: Array = []
	for t in src:
		out.append((t as Array).duplicate())
	return out
