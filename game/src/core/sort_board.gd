class_name SortBoard
extends RefCounted
## Model planszy water sort (czysta logika, bez Node).
## Probówka = Array intów, indeks 0 = dół, ostatni = góra. Kolory 0..n-1.

const DEFAULT_CAPACITY: int = 4
## Limit pojemności kodowanej przez `fast_key` (4 bity na jednostkę w int32).
const MAX_KEY_CAPACITY: int = 8

var tubes: Array = []
var capacity: int = DEFAULT_CAPACITY
## Liczba jednostek przelanych w ostatnim udanym `pour` (0 po nieudanym).
var last_pour_amount: int = 0


func _init(tubes_in: Array = [], capacity_in: int = DEFAULT_CAPACITY) -> void:
	assert(capacity_in <= MAX_KEY_CAPACITY, "SortBoard: fast_key wymaga pojemności <= 8")
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


## Legalne ruchy (bez no-opów), rosnąco po from, potem to. Inline `can_pour`
## (gorąca pętla solvera): te same reguły, bez wywołań pomocniczych na parę.
func legal_moves() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n: int = tubes.size()
	for f in n:
		var src: Array = tubes[f]
		var size: int = src.size()
		if size == 0:
			continue
		var color: int = src[size - 1]
		var uniform: bool = true
		for k in size - 1:
			if src[k] != color:
				uniform = false
				break
		if uniform and size >= capacity:
			continue  # rozwiązana probówka
		for t in n:
			if t == f:
				continue
			var dst: Array = tubes[t]
			var dsize: int = dst.size()
			if dsize >= capacity:
				continue
			if dsize == 0:
				if not uniform:
					out.append(Vector2i(f, t))
			elif dst[dsize - 1] == color:
				out.append(Vector2i(f, t))
	return out


## Klucz stanu niezależny od kolejności probówek w postaci tekstu (referencja
## do testu równoważności z `fast_key`; wolny).
func canonical_key_string() -> String:
	var parts: Array[String] = []
	for t in tubes:
		var strs: PackedStringArray = PackedStringArray()
		for c in t:
			strs.append(str(int(c)))
		parts.append(",".join(strs))
	parts.sort()
	return "|".join(parts)


## Tekstowy klucz stanu (zgodność z dotychczasowymi konsumentami).
func canonical_key() -> String:
	return canonical_key_string()


## Szybki klucz stanu niezależny od kolejności probówek: posortowane kody probówek,
## kod = Σ (kolor+1) · 16^i. Wymaga kolorów <= 14 i pojemności <= 8 (4 bity × 8 = 32 bity;
## gra: 12 / 4). Pojemność pilnuje assert w `_init`; kolorów nie sprawdzamy (gorąca pętla).
func fast_key() -> PackedInt32Array:
	var codes: PackedInt32Array = PackedInt32Array()
	codes.resize(tubes.size())
	var i: int = 0
	for t in tubes:
		var code: int = 0
		var shift: int = 0
		for c in t:
			code |= (int(c) + 1) << shift
			shift += 4
		codes[i] = code
		i += 1
	codes.sort()
	return codes


func clone() -> SortBoard:
	return SortBoard.new(tubes, capacity)


## Odpowiednik `clone()` + `pour(from, to)` (ruch legalny): kopiuje tylko 2 probówki,
## pozostałe współdzieli. Tylko dla niemutowanych później plansz (solver).
func clone_poured(from: int, to: int) -> SortBoard:
	var b := SortBoard.new([], capacity)
	b.tubes = tubes.duplicate()
	b.tubes[from] = (tubes[from] as Array).duplicate()
	b.tubes[to] = (tubes[to] as Array).duplicate()
	b.pour(from, to)
	return b


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
