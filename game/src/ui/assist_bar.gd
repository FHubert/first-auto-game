class_name AssistBar
extends PanelContainer
## Pasek pomocy na plateau (T-177): "Trudny poziom? Zacznij z dodatkowa probowka".

signal coins_pressed
signal ad_pressed

const FONT_SIZE: int = 24
const BAR_HEIGHT: float = 120.0
const BOTTOM_MARGIN: float = 10.0

var title_label: Label
var coins_button: Button
var ad_button: Button


func _ready() -> void:
	Locale.ensure_installed()
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -(UiTokens.HUD_BOTTOM_H + BAR_HEIGHT + BOTTOM_MARGIN)
	offset_bottom = -(UiTokens.HUD_BOTTOM_H + BOTTOM_MARGIN)
	var rows := VBoxContainer.new()
	add_child(rows)
	title_label = Label.new()
	title_label.text = tr("assist_title")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", FONT_SIZE)
	rows.add_child(title_label)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	coins_button = _button(buttons, coins_pressed)
	ad_button = _button(buttons, ad_pressed)
	visible = false


## Pokazuje pasek wg odpowiedzi `LevelOffers.plateau_assist()`.
func apply(offer: Dictionary) -> void:
	if coins_button == null:
		return
	visible = bool(offer.get("show", false))
	coins_button.text = tr("btn_extra_tube") % Economy.extra_tube_cost()
	coins_button.visible = bool(offer.get("coins", false))
	ad_button.text = tr("btn_extra_tube_ad")
	ad_button.visible = bool(offer.get("rewarded", false))


func _button(parent: Control, sig: Signal) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.pressed.connect(func() -> void: sig.emit())
	parent.add_child(b)
	return b
