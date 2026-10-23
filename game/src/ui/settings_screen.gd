class_name SettingsScreen
extends Control
## Ustawienia: muzyka, SFX, haptyka, jezyk, wersja. Zapis do GameState.settings.

signal back_pressed
signal settings_changed(key: String)

const TEXT_MUSIC: String = "Muzyka"
const TEXT_SFX: String = "Dźwięki"
const TEXT_HAPTICS: String = "Wibracje"
const TEXT_BACK: String = "Wróć"
const TEXT_VERSION: String = "v%s (%s)"
## [etykieta, kod locale]
const LOCALES: Array = [["Systemowy", ""], ["English", "en"], ["Polski", "pl"], ["Deutsch", "de"]]
const FONT_SIZE: int = 32
const MARGIN: int = 48

var state: GameState
var music_toggle: CheckButton
var sfx_toggle: CheckButton
var haptics_toggle: CheckButton
var locale_option: OptionButton
var version_label: Label
var back_button: Button


func _ready() -> void:
	if state == null:
		state = SaveSystem.load()
	_build()
	apply_from_state()


func set_setting(key: String, value: Variant) -> void:
	state.settings[key] = value
	SaveSystem.save(state)
	settings_changed.emit(key)


func apply_from_state() -> void:
	music_toggle.set_pressed_no_signal(bool(state.settings.get("music_on", true)))
	sfx_toggle.set_pressed_no_signal(bool(state.settings.get("sfx_on", true)))
	haptics_toggle.set_pressed_no_signal(bool(state.settings.get("haptics_on", true)))
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
	music_toggle = _toggle(box, TEXT_MUSIC, "music_on")
	sfx_toggle = _toggle(box, TEXT_SFX, "sfx_on")
	haptics_toggle = _toggle(box, TEXT_HAPTICS, "haptics_on")
	locale_option = OptionButton.new()
	locale_option.add_theme_font_size_override("font_size", FONT_SIZE)
	for entry: Array in LOCALES:
		locale_option.add_item(entry[0])
	locale_option.item_selected.connect(
		func(idx: int) -> void: set_setting("locale", LOCALES[idx][1])
	)
	box.add_child(locale_option)
	version_label = Label.new()
	version_label.text = TEXT_VERSION % [Version.VERSION, Version.BUILD_INFO]
	version_label.add_theme_font_size_override("font_size", FONT_SIZE)
	box.add_child(version_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	back_button = Button.new()
	back_button.text = TEXT_BACK
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
