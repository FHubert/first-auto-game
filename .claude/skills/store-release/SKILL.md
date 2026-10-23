---
name: store-release
description: Uzyj przy wydaniach i publikacji - lane fastlane, sciezka Google Play (Internal do Production), Data Safety, App Store Connect/TestFlight, Privacy Labels i PrivacyInfo.xcprivacy, odrzucenia ze sklepow, RELEASE_CHECKLIST.
---

# store-release — publikacja w Google Play i App Store

Pipeline: tag `v*` → `release.yml`: `prepare` (wersja) → `changelog` → `android` (AAB → Play **internal**) + `ios` (TestFlight) → `promote` (środowisko **production**, ręczna zgoda Huberta) → Play staged rollout 10 % + zgłoszenie do App Review (bez auto-release). Nic nie trafia na produkcję bez approve (ADR-005).

## 1. Lane fastlane (`fastlane/Fastfile`, `APP_ID = pl.allinit.firstautogame`)
| Lane | Co robi |
|---|---|
| `android upload track:<t>` | wgrywa `export/android/game.aab` na tor `<t>` (domyślnie `internal`); metadata/obrazy/changelog wgrywane tylko gdy gotowe (brak tekstu `TBD by aso skill`); `release_status` z `PLAY_RELEASE_STATUS` (domyślnie `completed`; dla nowej apki przed pierwszym review użyj `draft`) |
| `android internal` | skrót: `upload(track: "internal")` |
| `android promote_production` | promuje wydanie z `internal` na `production` z rolloutem `0.1` (10 %), bez ponownego uploadu AAB; opcjonalnie `VERSION_CODE` |
| `ios beta` | `match` (appstore, readonly) → podpis projektu Xcode → `build_app` (`export/ios/game.xcodeproj`, scheme `game`) → `upload_to_testflight` (changelog z `CHANGELOG`) |
| `ios submit_review` | `deliver` z `IOS_BUILD_NUMBER`: zgłasza przetworzony build do App Review, `automatic_release: false`, deklaracje IDFA (`IOS_USES_IDFA`), `export_compliance_uses_encryption: false` |
Lokalnie: `bundle exec fastlane android internal` (wymaga `GOOGLE_PLAY_JSON_KEY_PATH`), `bundle exec fastlane ios beta` (wymaga `APP_STORE_CONNECT_KEY_PATH`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APPLE_TEAM_ID`, `MATCH_*`). Plików lane NIE edytujesz (zablokowane w `.claude/settings.json`) - zmiana lane = zadanie dla człowieka.

## 2. Google Play: ścieżka torów
1. **Internal testing** (do 100 testerów, bez review, minuty) - tu ląduje każdy build z `release.yml`.
2. **Closed testing** - lista testerów (e-mail/Google Group). ZWERYFIKUJ wymóg dla nowych kont osobistych (12 testerów × 14 dni przed produkcją, `docs/SETUP_HUBERT.md`); konto firmowe (organizacja) może go nie mieć: https://support.google.com/googleplay/android-developer/answer/14151465.
3. **Open testing** (opcjonalnie) - publiczna beta.
4. **Production** - rollout etapowy zaczynaj od 10 % (`promote_production`), podnoś do 50 % → 100 % po 2–3 dniach bez wzrostu crashy (Play Console → Android vitals).
- **Play App Signing**: Google trzyma klucz podpisujący; Ty podpisujesz upload key (keystore z sekretów). Zgub upload key = reset w Play Console (support). Backup keystore w menedżerze haseł.
- **AAB** (nie APK) - wymóg nowych aplikacji. Preset ma `gradle_build/export_format=1`.
- **Target API**: od 31.08.2026 nowe aplikacje i aktualizacje muszą celować w **Android 16 (API 36)** (możliwy wniosek o przedłużenie do 1.11.2026). Preset ma `target_sdk="35"` → przed pierwszym wydaniem podnieść do 36 (skill `godot-build`). Źródło: https://support.google.com/googleplay/android-developer/answer/11926878.
- **Play Billing Library 8+** od tej samej daty (jeśli jest IAP): https://developer.android.com/google/play/billing/deprecation-faq.

## 3. Data Safety form (Play Console → App content) - mapa eventów
Formularz musi odpowiadać faktycznym danym SDK i eventom z `docs/GDD.md` → Analityka. Podstawa: strona Google "Google Play data disclosure" dla Mobile Ads SDK (https://developers.google.com/admob/android/privacy/play-data-disclosure) + dokumentacja GameAnalytics. ZWERYFIKUJ przed wysłaniem - Ty odpowiadasz za treść formularza.
| Źródło | Dane (typ w formularzu Play) | Cel | Udostępniane? |
|---|---|---|---|
| AdMob / Google Mobile Ads SDK | adres IP (Device or other IDs / Approximate location), interakcje z produktem (App activity), informacje diagnostyczne (App info and performance), identyfikatory urządzenia/konta (Device or other IDs: Android Ad ID, app set ID) | Advertising or marketing, Analytics, Fraud prevention | tak (Google) |
| GameAnalytics | identyfikator urządzenia/użytkownika (Device or other IDs), zdarzenia gry design/progression/resource (App activity), crashe/błędy (App info and performance), zdarzenia business (Purchase history) | Analytics | wg polityki GA (ZWERYFIKUJ) |
| Google Play Billing | historia zakupów obsługiwana przez Google | App functionality | nie (Google = platforma) |
| Gra (save lokalny) | brak wysyłki | - | - |
Dodatkowo: szyfrowanie w tranzycie (TLS) = tak; możliwość usunięcia danych: podaj procedurę (e-mail/formularz) lub „brak kont – dane nie są powiązane z użytkownikiem" tylko jeśli to prawda. Wyłączenie Ad ID (manifest) zmienia odpowiedzi. Polityka prywatności: publiczny URL (wymagany w Play i ASC). Zmiana listy eventów lub SDK → aktualizuj formularz przed wydaniem.

## 4. App Store Connect
- **TestFlight**: build z `ios beta`; Internal (do 100 członków zespołu, bez review) → External (wymaga Beta App Review). `uses_non_exempt_encryption: false` jest w lane - zostaw, jeśli gra używa tylko HTTPS.
- **Privacy Nutrition Labels** (App Privacy w ASC): analogicznie do Data Safety. Typowo dla gry z AdMob+GA: Identifiers (Device ID) – używane do śledzenia (jeśli ATT zgoda) i analityki; Usage Data (Product Interaction, Advertising Data); Diagnostics (Crash Data, Performance Data); Purchases. Oznacz „Used to Track You", jeśli dane łączone z danymi innych firm dla reklam.
- **PrivacyInfo.xcprivacy** (privacy manifest): wymagany od 1.05.2024 - build bez opisanych „required reason API" jest odrzucany przez ASC. Pięć kategorii (Apple: `NSPrivacyAccessedAPIType`): `NSPrivacyAccessedAPICategoryFileTimestamp`, `NSPrivacyAccessedAPICategorySystemBootTime`, `NSPrivacyAccessedAPICategoryDiskSpace`, `NSPrivacyAccessedAPICategoryActiveKeyboards`, `NSPrivacyAccessedAPICategoryUserDefaults`. Każdy SDK dostarcza własny manifest w xcframework (AdMob/UMP, GameAnalytics) - ZWERYFIKUJ po buildzie: sprawdź, czy w `export/ios/` są pliki `PrivacyInfo.xcprivacy` SDK; a manifest samej gry generuj z opcji presetu iOS (`privacy/file_timestamp_access_reasons`, `privacy/disk_space_access_reasons`, `privacy/system_boot_time_access_reasons`, `privacy/user_defaults_access_reasons`, `privacy/tracking_enabled`, `privacy/tracking_domains`, `privacy/collected_data/*`). Konkretne kody powodów (np. `C617.1`, `CA92.1`) bierz z https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api - nie zgaduj.
  Dla reklam: `NSPrivacyTracking = true` i lista `NSPrivacyTrackingDomains`, gdy gra śledzi (po ATT).
- **ATT**: `NSUserTrackingUsageDescription` w Info.plist + prompt przez UMP (skill `ads-iap`); bez promptu nie wolno czytać IDFA.
- Screenshoty wymagane: iPhone 6.9"/6.5"/6.3" wg tabeli ASC (skill `aso`), iPad 13" gdy gra działa na iPadzie (`targeted_device_family`).
- Eksport: `export_compliance_uses_encryption` = false (tylko standardowe HTTPS).

## 5. Najczęstsze odrzucenia gier z reklamami (Apple App Review Guidelines)
| Wytyczna | Typowa przyczyna | Co zrobić |
|---|---|---|
| **2.1 App Completeness** | crash przy starcie/na iPadzie, martwy przycisk, placeholdery, brak danych demo | przetestuj na iPadzie (apka iPhone działa na iPad w trybie zgodności - sprawdź layout `canvas_items`/`expand`), usuń „TBD", podaj działające konto testowe jeśli jest login |
| **4.3 Spam / Copycats** | szablonowa gra podobna do innych/klon | wyróżnij: unikalny motyw/mechanika/grafika, opisz różnice w Review Notes; nie używaj nazw i grafik z innych gier |
| **5.1.1 Data Collection** | brak polityki prywatności, ATT bez uzasadnienia, niezgodne labels | URL polityki w ASC i w apce (Ustawienia), poprawny opis ATT, labels = faktyczne SDK |
| **3.1.1 In-App Purchase** | brak „Restore Purchases", odblokowanie spoza IAP | przycisk Restore w Ustawieniach; wszystko płatne tylko przez IAP |
| **2.3 / 4.0 Metadata/Design** | screenshoty niezgodne z aplikacją, zbędny tekst „Android" | zrzuty z prawdziwej gry, brak wzmianek o innych platformach |
Pełne wytyczne: https://developer.apple.com/app-store/review/guidelines/. Google Play: odrzucenia dotyczą głównie polityk Ads, Families, Data Safety niezgodnego z SDK i targetu API.

## 6. Co zrobić przy odrzuceniu
1. Skopiuj dosłownie treść odrzucenia (numer wytycznej, data, wersja) do `docs/REVIEW_RESPONSES.md`.
2. Ustal: (a) naprawa w kodzie/metadanych → nowy build, (b) nieporozumienie → odpowiedź bez zmian.
3. Wzorzec odpowiedzi (krótko, rzeczowo, bez emocji, po angielsku):
```
Hello App Review team,
Thank you for the feedback on submission <ID>, guideline <X.Y.Z>.
What we changed: <1-3 bullet points; version/build number>.
Where to see it: <ekran / ścieżka w apce / krok 1-2-3>.
Test notes: <konto/demo, jak wywołać funkcję, ustawienia regionu dla zgody UMP>.
If anything is still unclear, please tell us which screen or flow to adjust.
Best regards, All In IT sp. z o.o.
```
4. Nowy build = nowy tag (patch bump) przez `release-manager`; po poprawce odpowiedz w Resolution Center. Nie zgłaszaj tego samego builda 2× bez zmian.
5. Szkice odpowiedzi trzymaj w `docs/REVIEW_RESPONSES.md`; wysyła człowiek.

## 7. RELEASE_CHECKLIST (`docs/RELEASE_CHECKLIST.md`) - jak odhaczać
Dla KAŻDEGO punktu zapisz dowód. Automatyzowalne: `make check` na tagowanym commicie; `playtest.json` bez softlocka (`make playtest`); screenshoty aktualne (`make screenshots`); changelog w `fastlane/metadata/android/<locale>/changelogs/<version_code>.txt` (<=500 znaków; CI generuje z `feat|fix|perf`); wersja przez `release.yml`. Człowiek: Crash-free Firebase Test Lab, UMP na EEA (VPN/`debug_geography`), Data Safety, Privacy Labels, URL polityki, ATT. Brak choćby jednego punktu = brak tagu (`release-manager` dopisuje braki jako P0).
Przed pierwszym wydaniem sprawdź też: `Fastfile` `metadata_ready?` (żadnego „TBD by aso skill"), ikony i feature graphic (skill `asset-gen`), target API 36, min iOS zgodny z pluginami, `docs/SETUP_HUBERT.md` (sekrety ustawione).
