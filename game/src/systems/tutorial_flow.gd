class_name TutorialFlow
extends RefCounted
## Maszyna stanow tutorialu poziomu 1: wskaz zrodlo -> wskaz cel -> ukoncz.

enum Step { PICK_SOURCE, PICK_TARGET, FINISH, DONE }

var step: int = Step.PICK_SOURCE
var expected: Vector2i = Vector2i(-1, -1)


func start(first_move: Vector2i) -> void:
	expected = first_move
	step = Step.PICK_SOURCE


func on_tube_selected(index: int) -> bool:
	if step == Step.PICK_SOURCE and index == expected.x:
		step = Step.PICK_TARGET
		return true
	return false


func on_pour(from: int, to: int, next_move: Vector2i, won: bool) -> bool:
	if step == Step.PICK_TARGET and Vector2i(from, to) != expected:
		return false
	if step != Step.PICK_TARGET and step != Step.FINISH:
		return false
	expected = next_move
	step = Step.DONE if won else Step.FINISH
	return true


func on_deselect() -> void:
	if step == Step.PICK_TARGET:
		step = Step.PICK_SOURCE


func is_done() -> bool:
	return step == Step.DONE


func highlight() -> int:
	match step:
		Step.PICK_TARGET:
			return expected.y
		Step.PICK_SOURCE, Step.FINISH:
			return expected.x
	return -1


func message() -> String:
	Locale.ensure_installed()
	match step:
		Step.PICK_SOURCE:
			return tr("tut_pick_source")
		Step.PICK_TARGET:
			return tr("tut_pick_target")
		Step.FINISH:
			return tr("tut_finish")
	return ""
