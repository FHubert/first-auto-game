class_name SettingsScreen
extends Control
## Ustawienia: muzyka, SFX, haptyka, jezyk, wersja. Zapis do GameState.settings.

signal back_pressed
signal settings_changed(key: String)

## [klucz etykiety, kod locale]
const LOCALES: Array = [
	["set_lang_system", ""], ["set_lang_en", "en"], ["set_lang_pl", "pl"], ["set_lang_de", "de"]
]
const FONT_SIZE: int = 32
const MARGIN: int = 48

var state: GameState
var music_toggle: CheckButton
var sfx_toggle: CheckButton
var haptics_toggle: CheckButton
var language_label: Label
var locale_option: OptionButton
var version_label: Label
var restore_button: Button
var privacy_button: Button
var back_button: Button


func _ready() -> void:
	Locale.ensure_installed()
	if state == null:
		state = SaveSystem.load()
	_build()
	apply_from_state()
	if not Ads.consent_finished.is_connected(_on_consent_finished):
		Ads.consent_finished.connect(_on_consent_finished)


func _exit_tree() -> void:
	if Ads.consent_finished.is_connected(_on_consent_finished):
		Ads.consent_finished.disconnect(_on_consent_finished)


func _on_consent_finished(_result: Dictionary) -> void:
	privacy_button.visible = Ads.is_privacy_options_required()


func set_setting(key: String, value: Variant) -> void:
	state.settings[key] = value
	SaveSystem.save(state)
	settings_changed.emit(key)


func _on_restore_pressed() -> void:
	Purchases.bind_state(state)
	if not Purchases.restore_done.is_connected(_on_restore_done):
		Purchases.restore_done.connect(_on_restore_done)
	Purchases.restore()


func _on_restore_done(restored: Array) -> void:
	apply_from_state()
	if not restored.is_empty():
		settings_changed.emit("ads_removed")


func apply_from_state() -> void:
	music_toggle.set_pressed_no_signal(bool(state.settings.get("music_on", true)))
	sfx_toggle.set_pressed_no_signal(bool(state.settings.get("sfx_on", true)))
	haptics_toggle.set_pressed_no_signal(bool(state.settings.get("haptics_on", true)))
	privacy_button.visible = Ads.is_privacy_options_required()
	var code: String = str(state.settings.get("locale", ""))
	for i in LOCALES.size():
		if LOCALES[i][1] == code:
			locale_option.select(i)


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)
	music_toggle = _toggle(box, tr("set_music"), "music_on")
	sfx_toggle = _toggle(box, tr("set_sfx"), "sfx_on")
	haptics_toggle = _toggle(box, tr("set_haptics"), "haptics_on")
	language_label = Label.new()
	language_label.text = tr("set_language")
	language_label.add_theme_font_size_override("font_size", FONT_SIZE)
	box.add_child(language_label)
	locale_option = OptionButton.new()
	locale_option.add_theme_font_size_override("font_size", FONT_SIZE)
	for entry: Array in LOCALES:
		locale_option.add_item(tr(entry[0]))
	locale_option.item_selected.connect(
		func(idx: int) -> void: set_setting("locale", LOCALES[idx][1])
	)
	box.add_child(locale_option)
	version_label = Label.new()
	version_label.text = tr("set_version") % [Version.VERSION, Version.BUILD_INFO]
	version_label.add_theme_font_size_override("font_size", FONT_SIZE)
	box.add_child(version_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	privacy_button = Button.new()
	privacy_button.text = tr("set_privacy_options")
	privacy_button.custom_minimum_size = Vector2(0, 100)
	privacy_button.add_theme_font_size_override("font_size", FONT_SIZE)
	privacy_button.pressed.connect(func() -> void: Ads.show_privacy_options())
	box.add_child(privacy_button)
	restore_button = Button.new()
	restore_button.text = tr("btn_restore")
	restore_button.custom_minimum_size = Vector2(0, 100)
	restore_button.add_theme_font_size_override("font_size", FONT_SIZE)
	restore_button.pressed.connect(_on_restore_pressed)
	box.add_child(restore_button)
	back_button = Button.new()
	back_button.text = tr("btn_back")
	back_button.custom_minimum_size = Vector2(0, 100)
	back_button.add_theme_font_size_override("font_size", FONT_SIZE)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	box.add_child(back_button)


func _toggle(parent: Control, text: String, key: String) -> CheckButton:
	var t := CheckButton.new()
	t.text = text
	t.add_theme_font_size_override("font_size", FONT_SIZE)
	t.toggled.connect(func(on: bool) -> void: set_setting(key, on))
	parent.add_child(t)
	return t
