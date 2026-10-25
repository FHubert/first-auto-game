class_name UiTokens
extends RefCounted
## Tokeny UI v2. Źródło prawdy: docs/ui/README.md; skala ×1,846 (pt makiety -> px Godota).
## Jedyny font: nunito.ttf (bez osobnych wag).

const BG := Color("#14213D")
const BG_DEEP := Color("#0E1A33")
const CARD := Color("#1F3A6B")
const CARD_ROW := Color("#16294F")
const CARD_ICON := Color("#2A4A82")
const PRIMARY := Color("#2EC4B6")
const PRIMARY_SHADOW := Color("#1C8F85")
const ON_PRIMARY := Color("#0B2A3C")
const ACCENT := Color("#FFD166")
const ACCENT_SHADOW := Color("#C99A2E")
const ON_ACCENT := Color("#3D2A00")
const STREAK := Color("#FB8500")
const TEXT := Color("#FFFFFF")
const TEXT_MUTED := Color("#A9B8D6")
const TEXT_SECTION := Color("#8EA0C4")
const DIM := Color(0.0235, 0.0471, 0.1098, 0.66)

const FONT_XS := 24
const FONT_SM := 28
const FONT_MD := 31
const FONT_BTN := 35
const FONT_TITLE := 48
const FONT_OVERLAY := 55
const FONT_HERO := 96
const FONT_HERO_LG := 103

const TOUCH_MIN := 81
const BTN_ICON := 89
const BTN_H := 103
const HUD_BTN := 118
const NAV_BTN := 126
const PLAY_BTN := 140
const SCREEN_PAD := 37
## Probówka i plansza (T-231); README -> "Plansza i probówki".
const TUBE_W := 85
const TUBE_H := 332
const TUBE_RIM_W := 103
const TUBE_RIM_H := 15
const TUBE_RIM_OVERLAP := 4
const TUBE_RADIUS := 42
const TUBE_OUTLINE := 6
const TUBE_PAD := 6
const TUBE_LAYER_H := 76
const TUBE_LIFT := 55
const TUBE_GAP_X := 97
const TUBE_GAP_Y := 140
const TUBE_HIGHLIGHT_W := 9
const TUBE_HIGHLIGHT_X := 11
const TUBE_HIGHLIGHT_TOP := 22
const TUBE_HIGHLIGHT_BOTTOM := 48
const TUBE_HIGHLIGHT_RADIUS := 5
const TUBE_HIGHLIGHT_ALPHA := 0.22
const GLASS_ALPHA := 0.55
const GLASS_ALPHA_SELECTED := 0.95
const GLASS_INNER_ALPHA := 0.08
const BOARD_MAX_COLS := 4
const BOARD_MAX_COLS_SCALED := 7
const BOARD_SCALED_FROM := 9
const NAV_RADIUS := 44
const CARD_RADIUS := 59
const CARD_ROW_RADIUS := 37
const TILE_RADIUS := 33
const SHADOW_BTN := 11
const SHADOW_ICON := 9
const BTN_PAD_H := 44
const ICON_DIR := "res://assets/sprites/ui/v2/"
const ICON_NAMES: Array[String] = [
	"pause",
	"undo",
	"restart",
	"hint",
	"add_tube",
	"coin",
	"streak",
	"calendar",
	"palette",
	"bag",
	"gear",
	"play",
	"video",
	"close",
	"back",
	"arrow_right",
	"check",
	"skip",
	"music",
	"speaker",
	"vibration",
	"symbols",
	"globe",
	"shield",
]


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func contrast_ratio(fg: Color, bg: Color) -> float:
	var l1: float = _luminance(fg)
	var l2: float = _luminance(bg)
	return (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05)


static func icon(name: String) -> Texture2D:
	if not ICON_NAMES.has(name):
		push_error("UiTokens.icon: unknown icon '%s'" % name)
		return null
	return load(ICON_DIR + name + ".png") as Texture2D
