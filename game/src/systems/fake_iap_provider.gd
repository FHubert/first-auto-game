class_name FakeIapProvider
extends IapProvider
## Deterministic provider for editor, headless runs and tests.

var fake_prices: Dictionary = {
	"remove_ads": 3990000,
	"coins_small": 1990000,
	"coins_large": 4990000,
	"starter_pack": 1990000,
}
var purchase_result: String = IapProvider.STATE_PURCHASED
var owned_for_restore: Array = []
var purchases_requested: int = 0
var acknowledged_tokens: Array = []

var _connected: bool = false


func connect_store() -> void:
	_connected = true
	connected.emit(true)


func is_connected_store() -> bool:
	return _connected


func query_products(skus: Array) -> void:
	var out: Array = []
	for sku: Variant in skus:
		if not fake_prices.has(sku):
			continue
		var micros: int = int(fake_prices[sku])
		(
			out
			. append(
				{
					"sku": sku,
					"price_text": "$%.2f" % (micros / 1000000.0),
					"price_micros": micros,
					"currency": "USD",
				}
			)
		)
	products_received.emit(out)


func purchase(sku: String) -> void:
	purchases_requested += 1
	purchase_updated.emit(sku, purchase_result, "tok_%s_%d" % [sku, purchases_requested])


func restore() -> void:
	restore_finished.emit(owned_for_restore.duplicate())


func acknowledge(token: String) -> void:
	acknowledged_tokens.append(token)
	acknowledged.emit(token)


## Test hook: the store delivers the same purchase again (onPurchasesUpdated + queryPurchases).
func redeliver(sku: String, token: String) -> void:
	purchase_updated.emit(sku, IapProvider.STATE_PURCHASED, token)
