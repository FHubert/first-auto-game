extends GdUnitTestSuite

const CSV: String = "res://locale/strings.csv"
const MAX_BTN_LEN: int = 18


func after_test() -> void:
	Locale.uninstall()
	TranslationServer.set_locale("en")


func _keys(t: Translation) -> Array:
	var keys: Array = Array(t.get_message_list())
	keys.sort()
	return keys


func test_load_csv_three_locales_same_keys() -> void:
	var ts: Array[Translation] = Locale.load_csv(CSV)
	assert_int(ts.size()).is_equal(3)
	var codes: Array = []
	for t in ts:
		codes.append(t.locale)
	assert_array(codes).contains_exactly(["en", "pl", "de"])
	var base: Array = _keys(ts[0])
	assert_array(base).is_not_empty()
	for t in ts:
		assert_array(_keys(t)).is_equal(base)
		for key: String in base:
			assert_str(str(t.get_message(key))).is_not_empty()


func test_btn_keys_fit_length() -> void:
	for t in Locale.load_csv(CSV):
		for key: String in t.get_message_list():
			if key.begins_with("btn_"):
				assert_int(str(t.get_message(key)).length()).is_less_equal(MAX_BTN_LEN)


func test_apply_setting() -> void:
	assert_str(Locale.apply_setting("de")).is_equal("de")
	assert_str(TranslationServer.get_locale()).starts_with("de")
	assert_bool(Locale.supported().has(Locale.apply_setting(""))).is_true()
	assert_str(Locale.apply_setting("xx")).is_equal("en")


func test_tr_uses_installed_translations() -> void:
	Locale.install(Locale.load_csv(CSV))
	TranslationServer.set_locale("pl")
	assert_str(tr("btn_next")).is_equal("Dalej")
	TranslationServer.set_locale("en")
	assert_str(tr("btn_next")).is_equal("Next")


func test_ensure_installed_is_idempotent() -> void:
	Locale.ensure_installed()
	Locale.ensure_installed()
	TranslationServer.set_locale("de")
	assert_str(tr("btn_back")).is_equal("Zurück")
