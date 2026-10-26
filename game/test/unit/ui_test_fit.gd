class_name UiTestFit
extends RefCounted
## T-312: wspolny helper testow UI. Korzen sceny ma kotwice full-rect, wiec `.size` daje
## ostrzezenie silnika "non-equal opposite anchors". fit_root zrownuje kotwice (lewy-gorny
## naroznik, pozycja 0,0, offsety == rozmiar), potem ustawia rozmiar.


static func fit_root(control: Control, size: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = size
