class_name SettingsScreen
extends Control
## Ustawienia: muzyka, SFX, haptyka, jezyk, wersja. Zapis do GameState.settings.

signal back_pressed
signal settings_changed(key: String)

## [klucz etykiety, kod locale]
const LOCALES: Array = [
	["set_lang_system", ""], ["set_lang_en", "en"], ["set_lang_pl", "pl"], ["set_lang_de", "de"]
]
const GAP: int = 22
const ICON_SIZE: int = 48

var state: GameState
var music_toggle: CheckButton
var sfx_toggle: CheckButton
var haptics_toggle: CheckButton
var symbols_toggle: CheckButton
var notifications_toggle: CheckButton
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
	music_toggle.set_pressed_no_signal(bool(state.settings.get(GameState.SETTING_MUSIC_ON, true)))
	sfx_toggle.set_pressed_no_signal(bool(state.settings.get(GameState.SETTING_SFX_ON, true)))
	haptics_toggle.set_pressed_no_signal(
		bool(state.settings.get(GameState.SETTING_HAPTICS_ON, true))
	)
	symbols_toggle.set_pressed_no_signal(ColorSymbols.enabled(state.settings))
	var notif_on: bool = bool(state.settings.get(GameState.SETTING_NOTIFICATIONS_ON, true))
	notifications_toggle.set_pressed_no_signal(notif_on)
	privacy_button.visible = Ads.is_privacy_options_required()
	var code: String = str(state.settings.get("locale", ""))
	for i in LOCALES.size():
		if LOCALES[i][1] == code:
			locale_option.select(i)


func _build() -> void:
	theme = ScreenHeader.UI_THEME
	ScreenHeader.add_backdrop(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiTokens.SCREEN_PAD)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	margin.add_child(box)
	back_button = ScreenHeader.build(box, tr("btn_settings"), false)["back"]
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	var sound: VBoxContainer = _section(box, "set_section_sound")
	music_toggle = _toggle(sound, "music", tr("set_music"), GameState.SETTING_MUSIC_ON)
	sfx_toggle = _toggle(sound, "speaker", tr("set_sfx"), GameState.SETTING_SFX_ON)
	haptics_toggle = _toggle(sound, "vibration", tr("set_haptics"), GameState.SETTING_HAPTICS_ON)
	var notif_key: String = GameState.SETTING_NOTIFICATIONS_ON
	notifications_toggle = _toggle(sound, "speaker", tr("set_notifications"), notif_key)
	var access: VBoxContainer = _section(box, "set_section_access")
	symbols_toggle = _toggle(access, "symbols", tr("set_symbols"), ColorSymbols.SETTING_KEY)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", GAP)
	access.add_child(lang_row)
	lang_row.add_child(_icon("globe"))
	language_label = Label.new()
	language_label.text = tr("set_language")
	language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(language_label)
	locale_option = OptionButton.new()
	locale_option.theme_type_variation = &"ButtonSecondary"
	locale_option.custom_minimum_size.y = UiTokens.TOUCH_MIN
	for entry: Array in LOCALES:
		locale_option.add_item(tr(entry[0]))
	locale_option.item_selected.connect(
		func(idx: int) -> void: set_setting("locale", LOCALES[idx][1])
	)
	lang_row.add_child(locale_option)
	var account: VBoxContainer = _section(box, "set_section_account")
	restore_button = _link_row(account, "arrow_right", tr("btn_restore"))
	restore_button.pressed.connect(_on_restore_pressed)
	privacy_button = _link_row(account, "shield", tr("set_privacy_options"))
	privacy_button.pressed.connect(func() -> void: Ads.show_privacy_options())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	version_label = Label.new()
	version_label.text = tr("set_version") % [Version.VERSION, Version.BUILD_INFO]
	version_label.theme_type_variation = &"LabelCaption"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version_label)


func _section(parent: Control, title_key: String) -> VBoxContainer:
	var l := Label.new()
	l.text = tr(title_key).to_upper()
	l.theme_type_variation = &"LabelSection"
	parent.add_child(l)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardRow"
	parent.add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	return col


func _icon(icon_name: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTokens.icon(icon_name)
	r.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _link_row(parent: Control, icon_name: String, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = UiTokens.icon(icon_name)
	ScreenHeader.plain(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", ICON_SIZE)
	b.add_theme_constant_override("h_separation", GAP)
	parent.add_child(b)
	return b


func _toggle(parent: Control, icon_name: String, text: String, key: String) -> CheckButton:
	var t := CheckButton.new()
	t.text = text
	t.icon = UiTokens.icon(icon_name)
	t.add_theme_constant_override("icon_max_width", ICON_SIZE)
	t.add_theme_constant_override("h_separation", GAP)
	ScreenHeader.style_switch(t)
	t.toggled.connect(func(on: bool) -> void: set_setting(key, on))
	parent.add_child(t)
	return t
