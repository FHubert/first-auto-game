class_name AnalyticsProvider
extends RefCounted
## Base analytics interface (no-op). Real SDK wrappers extend this.


func init() -> void:
	pass


func track_design(_event_id: String, _value: float = 0.0) -> void:
	pass


## status: "Start" | "Complete" | "Fail".
func track_progression(_status: String, _l1: String, _l2: String = "", _score: int = 0) -> void:
	pass


func track_business(_sku: String, _amount_cents: int, _currency: String) -> void:
	pass


## flow: "Source" | "Sink".
func track_resource(
	_flow: String, _currency: String, _amount: float, _item_type: String, _item_id: String
) -> void:
	pass
