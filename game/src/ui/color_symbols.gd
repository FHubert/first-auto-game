class_name ColorSymbols
extends RefCounted
## Symbole kolorow (dostepnosc, daltonizm): 12 prostych ksztaltow wg indeksu koloru.

const SHAPES: int = 12
const SYMBOL_SCALE: float = 0.45
const SETTING_KEY: String = "colorblind_symbols"
const CIRCLE_POINTS: int = 16
const ARC_POINTS: int = 9
const STAR_INNER: float = 0.45
const PLUS_ARM: float = 0.3
const BAR_HALF_HEIGHT: float = 0.3


## Czy symbole sa wlaczone w ustawieniach (zly typ / brak klucza = false).
static func enabled(settings: Dictionary) -> bool:
	var v: Variant = settings.get(SETTING_KEY, false)
	return typeof(v) == TYPE_BOOL and v


## Wielokat symbolu dla koloru wpisany w SYMBOL_SCALE mniejszego boku rect, wysrodkowany.
static func polygon(color_index: int, rect: Rect2) -> PackedVector2Array:
	var half: float = minf(rect.size.x, rect.size.y) * SYMBOL_SCALE * 0.5
	var center: Vector2 = rect.get_center()
	var pts := PackedVector2Array()
	for p: Vector2 in _unit_shape(posmod(color_index, SHAPES)):
		pts.append(center + p * half)
	return pts


## Ksztalt w kwadracie [-1, 1] (os Y w dol).
static func _unit_shape(shape: int) -> PackedVector2Array:
	match shape:
		0:
			return _regular(CIRCLE_POINTS, 0.0, 1.0)
		1:
			return PackedVector2Array(
				[
					Vector2(-0.85, -0.85),
					Vector2(0.85, -0.85),
					Vector2(0.85, 0.85),
					Vector2(-0.85, 0.85)
				]
			)
		2:
			return PackedVector2Array([Vector2(0, -1), Vector2(1, 0.8), Vector2(-1, 0.8)])
		3:
			return PackedVector2Array([Vector2(-1, -0.8), Vector2(1, -0.8), Vector2(0, 1)])
		4:
			return PackedVector2Array(
				[Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
			)
		5:
			return _plus()
		6:
			return _rotated(_plus(), PI * 0.25)
		7:
			return _star()
		8:
			return _regular(6, 0.0, 1.0)
		9:
			return _regular(5, -PI * 0.5, 1.0)
		10:
			var pts := PackedVector2Array()
			for k: int in ARC_POINTS:
				var a: float = PI + PI * float(k) / float(ARC_POINTS - 1)
				pts.append(Vector2(cos(a), sin(a)) + Vector2(0, 0.5))
			return pts
		_:
			var h: float = BAR_HALF_HEIGHT
			return PackedVector2Array(
				[Vector2(-1, -h), Vector2(1, -h), Vector2(1, h), Vector2(-1, h)]
			)


static func _regular(n: int, start: float, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k: int in n:
		var a: float = start + TAU * float(k) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


static func _star() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k: int in 10:
		var a: float = -PI * 0.5 + TAU * float(k) / 10.0
		var r: float = 1.0 if k % 2 == 0 else STAR_INNER
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func _plus() -> PackedVector2Array:
	var t: float = PLUS_ARM
	return PackedVector2Array(
		[
			Vector2(-t, -1),
			Vector2(t, -1),
			Vector2(t, -t),
			Vector2(1, -t),
			Vector2(1, t),
			Vector2(t, t),
			Vector2(t, 1),
			Vector2(-t, 1),
			Vector2(-t, t),
			Vector2(-1, t),
			Vector2(-1, -t),
			Vector2(-t, -t)
		]
	)


static func _rotated(pts: PackedVector2Array, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p.rotated(angle) * 0.8)
	return out
