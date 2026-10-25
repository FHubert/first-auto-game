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
const TILE_SIZE: int = 74
const ROW_MIN_H: int = 88
const SEP_H: int = 2

var state: GameState
var music_toggle: CheckButton
var sfx_toggle: CheckButton
var haptics_toggle: CheckButton
var symbols_toggle: CheckButton
var notifications_toggle: CheckButton
var language_label: Label
var language_button: Button
var language_value_label: Label
var privacy_sep: ColorRect
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
	_update_privacy_visibility()


func _update_privacy_visibility() -> void:
	var on: bool = Ads.is_privacy_options_required()
	privacy_button.visible = on
	privacy_sep.visible = on


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


func _locale_index() -> int:
	var code: String = str(state.settings.get("locale", ""))
	for i in LOCALES.size():
		if LOCALES[i][1] == code:
			return i
	return 0


func cycle_language() -> void:
	var nxt: int = (_locale_index() + 1) % LOCALES.size()
	set_setting("locale", LOCALES[nxt][1])
	language_value_label.text = tr(LOCALES[nxt][0])


func apply_from_state() -> void:
	music_toggle.set_pressed_no_signal(bool(state.settings.get(GameState.SETTING_MUSIC_ON, true)))
	sfx_toggle.set_pressed_no_signal(bool(state.settings.get(GameState.SETTING_SFX_ON, true)))
	haptics_toggle.set_pressed_no_signal(
		bool(state.settings.get(GameState.SETTING_HAPTICS_ON, true))
	)
	symbols_toggle.set_pressed_no_signal(ColorSymbols.enabled(state.settings))
	var notif_on: bool = bool(state.settings.get(GameState.SETTING_NOTIFICATIONS_ON, true))
	notifications_toggle.set_pressed_no_signal(notif_on)
	_update_privacy_visibility()
	language_value_label.text = tr(LOCALES[_locale_index()][0])


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
	notifications_toggle = _toggle(sound, "bell", tr("set_notifications"), notif_key)
	var access: VBoxContainer = _section(box, "set_section_access")
	symbols_toggle = _toggle(
		access, "symbols", tr("set_symbols"), ColorSymbols.SETTING_KEY, tr("set_symbols_desc")
	)
	language_button = _button_row(access, "globe", tr("set_language"))
	language_label = language_button.get_meta("title") as Label
	language_value_label = Label.new()
	language_value_label.theme_type_variation = &"LabelCaption"
	language_value_label.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	language_value_label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	var slot: HBoxContainer = language_button.get_meta("right") as HBoxContainer
	slot.add_child(language_value_label)
	slot.add_child(_icon("chevron_right", 32))
	language_button.pressed.connect(cycle_language)
	var account: VBoxContainer = _section(box, "set_section_account")
	restore_button = _button_row(account, "restart", tr("btn_restore"), true)
	restore_button.pressed.connect(_on_restore_pressed)
	privacy_button = _button_row(account, "shield", tr("set_privacy_options"), true)
	privacy_sep = account.get_child(account.get_child_count() - 2) as ColorRect
	privacy_button.pressed.connect(func() -> void: Ads.show_privacy_options())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	version_label = Label.new()
	version_label.text = tr("set_version") % Version.VERSION
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
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	return col


func _icon(icon_name: String, size: int = ICON_SIZE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiTokens.icon(icon_name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## Dodaje do karty sekcji kontener wiersza (przycisk); miedzy wierszami separator.
func _add_row_container(col: VBoxContainer, b: Button) -> void:
	if col.get_child_count() > 0:
		var sep := ColorRect.new()
		sep.color = UiTokens.BG_DEEP
		sep.custom_minimum_size.y = SEP_H
		col.add_child(sep)
	b.custom_minimum_size.y = ROW_MIN_H
	col.add_child(b)


## Wiersz: [kafelek z ikona] [tytul + podtytul] [prawy slot]. Buduje wnetrze `btn`
## (wypelnia caly przycisk, klik gdziekolwiek). Zwraca {"row", "right", "title"}.
func _row(btn: Button, icon_name: String, title: String, subtitle: String = "") -> Dictionary:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", GAP)
	btn.add_child(row)
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.CARD_ICON
	sb.set_corner_radius_all(UiTokens.TILE_RADIUS)
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var center := CenterContainer.new()
	center.add_child(_icon(icon_name, UiTokens.TILE_ICON))
	tile.add_child(center)
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", UiTokens.FONT_MD)
	t.add_theme_color_override("font_color", UiTokens.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(t)
	if subtitle != "":
		var d := Label.new()
		d.text = subtitle
		d.add_theme_font_size_override("font_size", UiTokens.FONT_XS)
		d.add_theme_color_override("font_color", UiTokens.TEXT_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(d)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	_ignore_mouse(row)
	btn.set_meta("title", t)
	btn.set_meta("right", right)
	return {"row": row, "right": right, "title": t}


func _button_row(
	col: VBoxContainer, icon_name: String, title: String, chevron: bool = false
) -> Button:
	var b := Button.new()
	ScreenHeader.plain(b)
	_add_row_container(col, b)
	var parts: Dictionary = _row(b, icon_name, title)
	if chevron:
		(parts["right"] as HBoxContainer).add_child(_icon("chevron_right", 32))
	return b


func _toggle(
	parent: VBoxContainer, icon_name: String, text: String, key: String, subtitle: String = ""
) -> CheckButton:
	var t := CheckButton.new()
	ScreenHeader.style_switch(t)
	_add_row_container(parent, t)
	var parts: Dictionary = _row(t, icon_name, text, subtitle)
	(parts["right"] as HBoxContainer).custom_minimum_size.x = ScreenHeader.SWITCH_SIZE.x
	t.toggled.connect(
		func(on: bool) -> void:
			set_setting(key, on)
			if key == GameState.SETTING_NOTIFICATIONS_ON:
				Analytics.track_design("settings:notifications:" + ("on" if on else "off"))
	)
	return t
