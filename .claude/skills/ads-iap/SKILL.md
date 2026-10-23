---
name: ads-iap
description: Uzyj przy integracji reklam (AdMob rewarded/interstitial), zgody UMP/ATT, zakupow IAP (Google Play Billing, StoreKit), eventow biznesowych GA i sprawdzaniu polityk reklamowych.
---

# ads-iap — reklamy, zgoda, zakupy

## 0. Blokery do rozstrzygnięcia PRZED kodowaniem SDK
1. **Wersja Godota.** Plugin AdMob (`poing-studios/godot-admob-plugin`) i SDK GameAnalytics dla Godot wymagają **Godot 4.5+**; repo jest na 4.7.2 (ADR-008), więc wymóg jest spełniony. Nadal ZWERYFIKUJ wydanie pluginu pod 4.7: https://poingstudios.github.io/godot-admob-plugin/stable/ (Prerequisites), https://docs.gameanalytics.com/integrations/sdk/godot/ (Requirements).
2. **IAP nie ma ADR.** ADR-007 dopuszcza tylko gdUnit4, godot-admob-plugin, gameanalytics-godot, GodotFirebase. GodotGooglePlayBilling i iOS `InAppStore` wymagają nowego ADR przed dodaniem.
3. Wymagania pluginu AdMob (docs stable): Android minSdk 24, compileSdk 35+, iOS 15.0+, Xcode 15+ (preset ma `min_ios_version="13.0"` - podnieść).

## 1. Architektura w repo (nie omijać)
Cała gra gada z reklamami tylko przez `Ads` (autoload `ad_service.gd`) → `AdProvider` (`ad_provider.gd`). `FakeAdProvider` działa w edytorze/headless/testach. Prawdziwy SDK = nowa klasa `AdMobProvider extends AdProvider` (plik `src/systems/admob_provider.gd`), wybierana w `Ads._make_default_provider()` (jest tam TODO) - tylko poza edytorem i headless.
Interfejs: `initialize()`, `is_rewarded_ready()`, `show_rewarded(callback: Callable)` (callback dostaje `granted: bool`), `is_interstitial_ready()`, `show_interstitial()`, sygnały `rewarded_closed(granted)`, `interstitial_closed`.
Ad unit ID NIGDY w repo: z sekretów `ADMOB_*` (ADR-003). Do dev/testów używaj testowych ID poniżej.

## 2. Oficjalne testowe ID Google (używaj wyłącznie w dev)
| Format | Android | iOS |
|---|---|---|
| App ID | `ca-app-pub-3940256099942544~3347511713` | `ca-app-pub-3940256099942544~1458002511` |
| Rewarded | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-3940256099942544/1712485313` |
| Interstitial | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-3940256099942544/4411468910` |
| Rewarded interstitial | `ca-app-pub-3940256099942544/5354046379` | `ca-app-pub-3940256099942544/6978759866` |
| Banner (fixed) | `ca-app-pub-3940256099942544/6300978111` | `ca-app-pub-3940256099942544/2934735716` |
Źródło: developers.google.com/admob/android/test-ads, .../ios/test-ads, quick-start. Release build z testowym ID = zakaz; dev build z prawdziwym ID = ryzyko bana konta (klikanie własnych reklam).

## 3. AdMob plugin - instalacja i API (wg docs plugin "stable/latest")
Instalacja: AssetLib → "AdMob" (Poing Studios) albo release zip rozpakowany w `res://`; włącz plugin (Project Settings → Plugins); Android: włączony Gradle build; App ID w Project Settings → General → Admob → Android/iOS (ZWERYFIKUJ nazwy pól po instalacji). Nie możesz tego zrobić bez ADR + akceptacji wersji Godota (pkt 0).
Singleton `MobileAds`; inicjalizacja raz:
```gdscript
func _ready() -> void:
	MobileAds.initialize()        # DOPIERO po zgodzie (pkt 5)
```
Rewarded (GDScript wg docs plugin; **ZWERYFIKUJ nazwy względem zainstalowanej wersji** - README master i docs różnią się w API UMP):
```gdscript
var _rewarded_ad: RewardedAd
var _earned: bool = false
var _on_user_earned := OnUserEarnedRewardListener.new()
var _fs_callback := FullScreenContentCallback.new()

func load_rewarded(unit_id: String) -> void:
	if _rewarded_ad:
		_rewarded_ad.destroy()          # zawsze zwalniaj poprzednią reklamę
		_rewarded_ad = null
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_failed_to_load = func(err: LoadAdError) -> void: push_warning(err.message)
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded_ad = ad
		_rewarded_ad.full_screen_content_callback = _fs_callback
	RewardedAdLoader.new().load(unit_id, AdRequest.new(), cb)

func show_rewarded(done: Callable) -> void:
	_earned = false
	_on_user_earned.on_user_earned_reward = func(_item: RewardedItem) -> void: _earned = true
	_fs_callback.on_ad_dismissed_full_screen_content = func() -> void:
		done.call(_earned)             # nagroda DOPIERO tu, po zamknięciu
		load_rewarded(_unit_id)        # od razu preładuj następną
	_rewarded_ad.show(_on_user_earned)
```
Interstitial analogicznie: `InterstitialAdLoader`, `InterstitialAdLoadCallback`, `ad.show()`. Callbacki pełnoekranowe: `on_ad_clicked`, `on_ad_dismissed_full_screen_content`, `on_ad_failed_to_show_full_screen_content`, `on_ad_impression`, `on_ad_showed_full_screen_content`.

## 4. Rewarded flow (kolejność - nie zmieniać)
1. **Pre-check ready**: `Ads.request_rewarded(id, on_reward)` zwraca `false`, gdy `provider.is_rewarded_ready()` jest fałszem → UI ukrywa/wyszarza przycisk (nie pokazuj przycisku, którego nie da się spełnić).
2. **Show** → provider pokazuje reklamę.
3. **Callback** `granted: bool` z providera (po `on_user_earned_reward` i zamknięciu).
4. **Nagroda** tylko gdy `granted == true` (w `Ads`: `on_reward.call()`).
5. **Event GA**: `Ads` już loguje `ads:rewarded:<placement>:granted|skipped|unavailable` przez `Analytics.track_design`. Dodatkowo (gdy GA SDK podłączone) `addAdEvent("show"|"reward_received"|"failed_show", "rewarded_video", "admob", placement)`.
6. Preładuj następną reklamę po zamknięciu.
Placement id (`double_coins`, `continue`, `daily_x2`) musi być zgodne z tabelą w `docs/MONETIZATION.md` i z GDD → Analityka.

## 5. Interstitial cap i kolejność zgody
- Cap w `GameConfig`: `interstitial_every_n_rounds` (3) i `interstitial_min_seconds` (90); logika w `Ads.maybe_show_interstitial(round_index)` (testy: `test_ad_service.gd`). Nigdy w pierwszej sesji/pierwszych rundach (propozycja do A/B), nigdy w trakcie rozgrywki, tylko na naturalnych przerwach (po wyniku rundy), nigdy po rewarded w tej samej przerwie.
- **Kolejność startu (obowiązkowa):** (1) `ConsentInformation` update (UMP) → (2) formularz zgody gdy wymagany (EEA/UK) → (3) iOS: ATT (jeśli używany) → (4) dopiero `MobileAds.initialize()` → (5) pierwszy `load`. Żadne żądanie reklamy przed zakończeniem (2)/(3).
UMP wg docs plugin (stable):
```gdscript
var req := ConsentRequestParameters.new()
req.tag_for_under_age_of_consent = false
UserMessagingPlatform.consent_information.update(req, _on_consent_ok, _on_consent_fail)
func _on_consent_ok() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_form_fail)
func _on_form_loaded(form: ConsentForm) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == UserMessagingPlatform.consent_information.ConsentStatus.REQUIRED:
		form.show(_on_form_dismissed)
```
`update()` wołaj przy KAŻDYM starcie. Test EEA: `ConsentDebugSettings` z `debug_geography = DebugGeography.Values.EEA` i `test_device_hashed_ids` (hash urządzenia wypisze log). ZWERYFIKUJ API względem zainstalowanej wersji (README master używa `ConsentInformation.request_consent_info_update` i `ConsentForm.load_and_show_consent_form_if_required`).
- ATT (iOS): wiadomość IDFA tworzysz w AdMob (Privacy & messaging), w `Info.plist` ustaw `NSUserTrackingUsageDescription` (opis po angielsku/lokalizacje), zlinkuj `AppTrackingTransparency`; UMP pokaże wyjaśnienie przed systemowym dialogiem (docs: privacy/user_messaging_tools/idfa_support). Dialog pojawia się tylko raz na instalację. Preset iOS: `privacy/tracking_enabled`, `privacy/tracking_domains`. Fastlane `submit_review` ma `IOS_USES_IDFA` (domyślnie true).

## 6. IAP
Produkt MVP: `remove_ads` - **non-consumable** (jednorazowy). Usuwa interstitiale (rewarded zostają dobrowolne). Flow zakupu (identyczny koncepcyjnie na obu platformach), za interfejsem `IapProvider` (analogicznie do `AdProvider`, `FakeIapProvider` do testów):
1. Połącz → 2. pobierz szczegóły produktów (cena lokalna z Store, NIE z kodu) → 3. `purchase(id)` → 4. wynik → 5. **przyznaj** dopiero przy statusie PURCHASED (nie PENDING) → 6. **potwierdź/ zakończ transakcję** → 7. zapisz `GameState.settings["ads_removed"] = true` → 8. event `Analytics.track_business(sku, amount_cents, currency)`.
**Android - GodotGooglePlayBilling** (`godot-sdk-integrations/godot-google-play-billing`, master wspiera Godot 4.2+; docs: godot-sdk-integrations.github.io/godot-google-play-billing). Wymaga Gradle build i APK/AAB wgranego do Play (testy zakupów tylko z Play Internal). API nowej wersji:
```gdscript
var billing_client: BillingClient
func _ready() -> void:
	billing_client = BillingClient.new()
	billing_client.connected.connect(_on_connected)
	billing_client.query_product_details_response.connect(_on_details)
	billing_client.query_purchases_response.connect(_on_purchases)
	billing_client.on_purchase_updated.connect(_on_purchase_updated)
	billing_client.acknowledge_purchase_response.connect(_on_ack)
	billing_client.start_connection()
func _on_connected() -> void:
	billing_client.query_product_details(["remove_ads"], BillingClient.ProductType.INAPP)
func _buy() -> void:
	billing_client.purchase("remove_ads")     # wynik w on_purchase_updated
func _process_purchase(p: Dictionary) -> void:
	if "remove_ads" in p.product_ids and p.purchase_state == BillingClient.PurchaseState.PURCHASED:
		_grant_remove_ads()
		if not p.is_acknowledged:
			billing_client.acknowledge_purchase(p.purchase_token)   # BEZ tego Google zwraca pieniądze po 3 dniach
```
Przy starcie i po `billing_resume`/powrocie do apki wołaj `query_purchases(BillingClient.ProductType.INAPP)` (= **restore** na Androidzie). Starsza wersja pluginu (docs Godot 4.4 i starsze) ma inne API (`payment.querySkuDetails`, `purchase`, singleton `GodotGooglePlayBilling`) - sprawdź, którą masz. **ZWERYFIKUJ:** Google Play wymaga Billing Library 8+ dla nowych aplikacji/aktualizacji od 31.08.2026 (wyjątek do 1.11.2026; https://developer.android.com/google/play/billing/deprecation-faq) - potwierdź, że wybrane wydanie pluginu ją zawiera.
**iOS - StoreKit** (Godot iOS plugin `InAppStore`, repo `godotengine/godot-ios-plugins`, budowany ze źródeł; strona docs jest oznaczona jako nieaktualna): singleton `Engine.get_singleton("InAppStore")`; metody `request_product_info({"product_ids": [..]})`, `purchase({"product_id": ..})`, `restore_purchases()`, `set_auto_finish_transaction(true)` / `finish_transaction(id)`; wyniki przez kolejkę `get_pending_event_count()` / `pop_pending_event()` (zdarzenia `type`: `product_info`, `purchase`, `restore`; `result`: `"ok"`/`"error"`). Odpytuj kolejkę np. co 1 s timerem. ZWERYFIKUJ aktualny stan i zgodność z Godot 4.7: https://docs.godotengine.org/en/4.7/tutorials/platform/ios/plugins_for_ios.html.
**Restore purchases to WYMÓG Apple** (Guideline 3.1.1: "make sure you have a restore mechanism for any restorable in-app purchases") - przycisk "Przywróć zakupy" w Ustawieniach, wołający `restore_purchases()`; bez niego odrzucenie.
Weryfikacja zakupu: MVP bez własnego serwera = ufamy sygnałowi Store + `signature` z Play; ryzyko cheatingu zaakceptowane (zapisz w ADR). Własny backend/RTDN poza zakresem.

## 7. Eventy GA (Business/Ad/Resource)
SDK GameAnalytics (gdextension) - singleton `GameAnalytics`; w repo przez `Analytics`/`AnalyticsProvider`:
- Zakup: `Analytics.track_business(sku, amount_cents, currency)` → `addBusinessEvent("USD", 399, "remove_ads", "ads", "settings_shop", {})` (wartość w centach; pola: currency, amount, itemType, itemId, cartType).
- Reklama (do dodania w `AnalyticsProvider`, jeśli brak): `addAdEvent(action, adType, adSdkName, adPlacement, opts)` gdzie `action` ∈ `clicked|show|failed_show|reward_received`, `adType` ∈ `video|rewarded_video|playable|interstitial|offer_wall|banner`, `adSdkName` = `"admob"`, opcjonalnie `noAdReason` ∈ `unknown|offline|no_fill|internal_error|invalid_request|unable_to_precache`.
- Waluta: `track_resource("Source"|"Sink", currency, amount, itemType, itemId)`; design: `track_design("ads:rewarded:double_coins:granted")` (1–5 segmentów po `:`, max 64 znaki).
Każda zmiana listy eventów → zaktualizuj Data Safety i Privacy Labels (`docs/RELEASE_CHECKLIST.md`).

## 8. Polityki - nie łamać
- Rewarded zawsze dobrowolny, nagroda widoczna przed startem; brak nagród za instalację/odwiedzenie innych aplikacji (Apple 3.2.2(x) zabrania wymuszania pobrań innych aplikacji; nagradzanie za obejrzenie reklamy jest dozwolone).
- Brak "clickbaitu": przycisk "Zamknij" nigdy nie udaje elementu gry, reklama nie wyskakuje przypadkiem (nie pod palcem w trakcie rozgrywki), brak interstitiali przy starcie i wyjściu z aplikacji.
- Limity częstotliwości z `GameConfig` (cap + min sekundy). Nie klikaj własnych reklam (konto AdMob).
- Dzieci: w Play Console → App content → Target audience. Jeśli grupa obejmuje <13, obowiązują Families Policy (certyfikowane SDK reklam, brak personalizacji) i `tag_for_under_age_of_consent`. Casual gry dla dorosłych: zadeklaruj 13+/18+ zgodnie z prawdą (ZWERYFIKUJ aktualne zasady: https://support.google.com/googleplay/android-developer/answer/9893335).
- Apple 5.1.1/5.1.2: polityka prywatności, opis zbieranych danych, ATT przed śledzeniem.
- Test: zawsze `FakeAdProvider` w testach i `make playtest`; na urządzeniu najpierw testowe ID, potem "test devices" z własnym ID.
