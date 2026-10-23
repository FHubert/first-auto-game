class_name Locale
extends RefCounted
## Lokalizacja EN/PL/DE: wlasny loader CSV (keys,en,pl,de) -> Translation.
## Bez importu CSV i bez [internationalization] w project.godot.

const CSV_PATH: String = "res://locale/strings.csv"
const FALLBACK: String = "en"

static var _installed: Array[Translation] = []


static func supported() -> PackedStringArray:
	return PackedStringArray(["en", "pl", "de"])


## Czyta CSV (pierwsza kolumna = klucz, naglowek = kody jezykow).
static func load_csv(path: String) -> Array[Translation]:
	var result: Array[Translation] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var header: PackedStringArray = file.get_csv_line()
	for i in range(1, header.size()):
		var t := Translation.new()
		t.locale = header[i]
		result.append(t)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		for i in result.size():
			if i + 1 < row.size():
				result[i].add_message(row[0], row[i + 1])
	return result


static func install(translations: Array[Translation]) -> void:
	uninstall()
	for t in translations:
		TranslationServer.add_translation(t)
		_installed.append(t)


static func uninstall() -> void:
	for t in _installed:
		TranslationServer.remove_translation(t)
	_installed.clear()


## Idempotentne: instaluje tlumaczenia raz, wolane przez ekrany (tr() zawsze ma tekst).
static func ensure_installed() -> void:
	if _installed.is_empty():
		install(load_csv(CSV_PATH))


## "" = jezyk systemowy zawezony do supported(), fallback "en". Zwraca wybrany kod.
static func apply_setting(locale_setting: String) -> String:
	var code: String = locale_setting
	if code.is_empty():
		code = OS.get_locale_language()
	if not supported().has(code):
		code = FALLBACK
	TranslationServer.set_locale(code)
	return code
