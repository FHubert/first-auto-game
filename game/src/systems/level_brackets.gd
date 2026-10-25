class_name LevelBrackets
extends RefCounted
## Przedzialy poziomow kampanii: wspolne dla analityki (T-207) i raportu bota.

const RANGES: Array = [[1, 7], [8, 25], [26, 55], [56, 1000000]]
const LABELS: Array = ["1-7", "8-25", "26-55", "56+"]
## Czesc ID eventu GA (<= 32 znaki, bez ':'), w kolejnosci RANGES.
const IDS: Array = ["lv1_7", "lv8_25", "lv26_55", "lv56p"]


static func index_for(level: int) -> int:
	for idx in RANGES.size():
		if level <= int(RANGES[idx][1]):
			return idx
	return RANGES.size() - 1


static func id_for(level: int) -> String:
	return IDS[index_for(level)]
