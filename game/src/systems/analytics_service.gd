extends Node
## Autoload "Analytics": delegates to a provider (fake in editor/headless).

var provider: AnalyticsProvider


func _ready() -> void:
	if provider == null:
		provider = _make_default_provider()
	provider.init()


func track_design(event_id: String, value: float = 0.0) -> void:
	provider.track_design(event_id, value)


func track_progression(status: String, l1: String, l2: String = "", score: int = 0) -> void:
	provider.track_progression(status, l1, l2, score)


func track_business(sku: String, amount_cents: int, currency: String) -> void:
	provider.track_business(sku, amount_cents, currency)


func track_resource(
	flow: String, currency: String, amount: float, item_type: String, item_id: String
) -> void:
	provider.track_resource(flow, currency, amount, item_type, item_id)


func _make_default_provider() -> AnalyticsProvider:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return FakeAnalyticsProvider.new()
	# TODO: real SDK provider (GameAnalytics); no-op base until then.
	return AnalyticsProvider.new()
