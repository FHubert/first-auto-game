class_name IapProvider
extends RefCounted
## Base in-app purchase interface. Real store wrappers (Google Play / StoreKit) extend this.

signal connected(ok: bool)
## Each product: {sku, price_text, price_micros, currency}.
signal products_received(products: Array)
signal purchase_updated(sku: String, state: String, token: String)
## Owned non-consumable SKUs.
signal restore_finished(skus: Array)
signal acknowledged(token: String)

const STATE_PURCHASED: String = "purchased"
const STATE_PENDING: String = "pending"
const STATE_FAILED: String = "failed"
const STATE_CANCELED: String = "canceled"


func connect_store() -> void:
	pass


func is_connected_store() -> bool:
	return false


func query_products(_skus: Array) -> void:
	pass


func purchase(_sku: String) -> void:
	pass


func restore() -> void:
	pass


## Finishes / acknowledges a transaction so the store does not refund or replay it.
func acknowledge(_token: String) -> void:
	pass
