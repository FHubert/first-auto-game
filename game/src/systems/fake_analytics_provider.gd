class_name FakeAnalyticsProvider
extends AnalyticsProvider
## Collects events in memory for tests and headless runs.

var events: Array[Dictionary] = []
var initialized: bool = false


func init() -> void:
	initialized = true


func track_design(event_id: String, value: float = 0.0) -> void:
	events.append({"type": "design", "event_id": event_id, "value": value})


func track_progression(status: String, l1: String, l2: String = "", score: int = 0) -> void:
	events.append({"type": "progression", "status": status, "l1": l1, "l2": l2, "score": score})


func track_error(severity: String, message: String) -> void:
	events.append(
		{
			"type": "error",
			"event_id": "error:%s" % severity,
			"severity": severity,
			"message": message
		}
	)


func track_business(sku: String, amount_cents: int, currency: String) -> void:
	events.append(
		{"type": "business", "sku": sku, "amount_cents": amount_cents, "currency": currency}
	)


func track_resource(
	flow: String, currency: String, amount: float, item_type: String, item_id: String
) -> void:
	(
		events
		. append(
			{
				"type": "resource",
				"flow": flow,
				"currency": currency,
				"amount": amount,
				"item_type": item_type,
				"item_id": item_id,
			}
		)
	)
