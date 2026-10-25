class_name OverlayFx
extends RefCounted
## Wejscie overlayu (UI v2): scale 0,9 -> 1 + fade-in.
## Wylaczone przy `effects_enabled=false` i w headless.

const ENTER_SECONDS: float = 0.18
const ENTER_SCALE: float = 0.9


## Uruchamia animacje wejscia na `panel`; zwraca Tween albo null, gdy efekty wylaczone.
## `pivot` = ulamek rozmiaru panelu (domyslnie srodek dolnej krawedzi arkusza).
static func enter(panel: Control, enabled: bool, pivot: Vector2 = Vector2(0.5, 1.0)) -> Tween:
	if not enabled or DisplayServer.get_name() == "headless" or not panel.is_inside_tree():
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
		return null
	var s: Vector2 = panel.size
	if s.x <= 0.0 or s.y <= 0.0:
		s = panel.get_combined_minimum_size()
	panel.pivot_offset = s * pivot
	panel.scale = Vector2.ONE * ENTER_SCALE
	panel.modulate.a = 0.0
	var tw: Tween = panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, ENTER_SECONDS)
	tw.tween_property(panel, "modulate:a", 1.0, ENTER_SECONDS)
	return tw


## Rodzic z wlasciwoscia `effects_enabled` (Level) ma pierwszenstwo przed polem overlayu.
static func enabled_for(node: Node, own: bool) -> bool:
	var p: Node = node.get_parent()
	if p != null and "effects_enabled" in p:
		return bool(p.get("effects_enabled"))
	return own
