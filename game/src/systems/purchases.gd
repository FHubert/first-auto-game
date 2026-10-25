extends Node
## Autoload "Purchases": owns the IAP provider and grants purchased goods.

signal purchase_granted(sku: String)
signal purchase_failed(sku: String, state: String)
signal products_updated(products: Array)
signal restore_done(restored: Array)

const SKU_REMOVE_ADS: String = "remove_ads"
const SKU_COINS_SMALL: String = "coins_small"
const SKU_COINS_LARGE: String = "coins_large"
const SKU_STARTER: String = "starter_pack"
const ALL_SKUS: Array[String] = [SKU_REMOVE_ADS, SKU_COINS_SMALL, SKU_COINS_LARGE, SKU_STARTER]
const NON_CONSUMABLE: Array[String] = [SKU_REMOVE_ADS, SKU_STARTER]

var provider: IapProvider
## Injected by App / screens; Purchases does not load the save itself.
var state: GameState
var products: Dictionary = {}
var save_callback: Callable = func() -> void: _default_save()


func _ready() -> void:
	if provider == null:
		provider = _make_default_provider()
	provider.connected.connect(_on_connected)
	provider.products_received.connect(_on_products_received)
	provider.purchase_updated.connect(_on_purchase_updated)
	provider.restore_finished.connect(_on_restore_finished)
	provider.connect_store()


func bind_state(s: GameState) -> void:
	state = s
	if s != null:
		Ads.set_ads_removed(bool(s.settings.get("ads_removed", false)))


## Localized price from the store; "" when unknown (UI never hardcodes prices).
func price_text(sku: String) -> String:
	if not products.has(sku):
		return ""
	return str((products[sku] as Dictionary).get("price_text", ""))


func buy(sku: String) -> bool:
	if not ALL_SKUS.has(sku) or provider == null or not provider.is_connected_store():
		return false
	if state != null and NON_CONSUMABLE.has(sku) and state.has_purchase(sku):
		return false
	provider.purchase(sku)
	return true


func restore() -> void:
	if provider != null:
		provider.restore()


## Pure grant logic; idempotent for non-consumables. False when nothing was granted.
func grant(sku: String, token: String = "") -> bool:
	if state == null or not ALL_SKUS.has(sku):
		return false
	if NON_CONSUMABLE.has(sku) and state.has_purchase(sku):
		return false
	match sku:
		SKU_REMOVE_ADS:
			state.settings["ads_removed"] = true
			Ads.set_ads_removed(true)
		SKU_COINS_SMALL:
			Economy.earn(state, int(GameConfig.get_value("iap_coins_small")), Economy.SOURCE_IAP)
		SKU_COINS_LARGE:
			Economy.earn(state, int(GameConfig.get_value("iap_coins_large")), Economy.SOURCE_IAP)
		SKU_STARTER:
			Economy.earn(state, int(GameConfig.get_value("iap_starter_coins")), Economy.SOURCE_IAP)
			var theme_id: String = str(GameConfig.get_value("iap_starter_theme"))
			if not state.owns_theme(theme_id):
				state.themes_owned.append(theme_id)
	if NON_CONSUMABLE.has(sku):
		state.purchases[sku] = true
	state.remember_iap_token(token)
	save_callback.call()
	Analytics.track_design("iap:granted:%s" % sku)
	purchase_granted.emit(sku)
	return true


## Starter offer window. starter_offer_start_day stores the unix SECONDS of the first
## qualifying call (field name kept to avoid a save schema change).
func starter_offer_visible(level: int, now_unix: int) -> bool:
	if state == null or state.has_purchase(SKU_STARTER):
		return false
	if level < int(GameConfig.get_value("starter_offer_min_level")):
		return false
	if state.starter_offer_start_day == 0:
		state.starter_offer_start_day = now_unix
	var window_s: int = int(GameConfig.get_value("starter_offer_hours")) * 3600
	return now_unix - state.starter_offer_start_day < window_s


func _on_connected(ok: bool) -> void:
	if ok:
		provider.query_products(ALL_SKUS)


func _on_products_received(list: Array) -> void:
	for p: Variant in list:
		var d: Dictionary = p
		products[str(d.get("sku", ""))] = d
	products_updated.emit(list)


func _on_purchase_updated(sku: String, st: String, token: String) -> void:
	match st:
		IapProvider.STATE_PURCHASED:
			# Empty token = fake/legacy provider: no dedupe (old behaviour).
			if state != null and state.has_iap_token(token):
				provider.acknowledge(token)
				return
			var owned: bool = NON_CONSUMABLE.has(sku) and state != null and state.has_purchase(sku)
			var done: bool = grant(sku, token)
			if not done and owned:
				state.remember_iap_token(token)
				save_callback.call()
			if done or owned:
				provider.acknowledge(token)
				if done:
					var p: Dictionary = products.get(sku, {})
					var cents: int = int(round(float(p.get("price_micros", 0)) / 10000.0))
					Analytics.track_business(sku, cents, str(p.get("currency", "USD")))
		IapProvider.STATE_PENDING:
			pass
		_:
			purchase_failed.emit(sku, st)
			Analytics.track_design("iap:failed:%s:%s" % [sku, st])


func _on_restore_finished(skus: Array) -> void:
	var restored: Array = []
	for sku: Variant in skus:
		if NON_CONSUMABLE.has(sku) and grant(str(sku)):
			restored.append(sku)
	restore_done.emit(restored)


func _default_save() -> void:
	if state != null:
		SaveSystem.save(state)


func _make_default_provider() -> IapProvider:
	# TODO: real Google Play / StoreKit provider (Phase 5); fake until then.
	return FakeIapProvider.new()
