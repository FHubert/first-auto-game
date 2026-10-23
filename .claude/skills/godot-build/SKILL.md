---
name: godot-build
description: Uzyj przy eksporcie Androida (AAB) i iOS z CLI, konfiguracji export_presets.cfg, wymaganiach SDK/JDK, wersjonowaniu i diagnozie bledow buildu. Nie dotyczy publikacji w sklepach (to store-release).
---

# godot-build — export Android/iOS

Godot 4.7.2 (przypięty w `Makefile`). Presety: `game/export_presets.cfg` (Android + iOS). Edycja presetów wymaga zadania w backlogu (CLAUDE.md).

## 1. Komendy exportu (CLI)
Składnia (docs 4.7): `godot --headless --path <projekt> --export-release "<nazwa presetu>" <ścieżka>`; też `--export-debug`, `--export-pack`. Binarka musi być **edytorem** (nie szablonem), a export templates zainstalowane (`make setup`). Preset w cudzysłowie; ścieżka względna jest liczona od katalogu z `project.godot` (czyli `game/`), nie od cwd.
```
# lokalnie / w CI (po inject_secrets.sh android):
.tools/godot --headless --path game --export-release "Android" ../export/android/game.aab
# debug apk bez podpisu produkcyjnego:
.tools/godot --headless --path game --export-debug "Android" /tmp/game-debug.apk
# iOS (TYLKO macOS + Xcode): generuje projekt Xcode, nie IPA
.tools/godot --headless --path game --export-release "iOS" ../export/ios/game.xcodeproj
```
W repo: preset Android ma `export_path="../export/android/game.aab"`, `gradle_build/use_gradle_build=true`, `gradle_build/export_format=1` (AAB). `make export-check` robi suchą próbę: `tools/validate_presets.py` + załadowanie projektu `--quit` (+ export debug, gdy ustawione `ANDROID_HOME`). Katalog `export/` jest ignorowany przez git.

## 2. `export_presets.cfg` - placeholdery, czego nie commitować
Sekrety to placeholdery wstrzykiwane w CI przez `tools/inject_secrets.sh android|ios`:
`__ANDROID_KEYSTORE_PATH__`, `__ANDROID_KEY_ALIAS__`, `__ANDROID_KEY_PASSWORD__` (Android), `__APPLE_TEAM_ID__` (iOS).
- NIGDY nie wpisuj prawdziwych haseł/ścieżek keystore; `make export-check` (validate_presets.py) padnie.
- Nie commituj: `*.jks`, `*.keystore`, `*.p8`, `*.p12`, `*.mobileprovision`, `.godot/export_credentials.cfg`, service account JSON.
- Godot nadpisuje opcje zmiennymi środowiskowymi: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH|_USER|_PASSWORD`, iOS `GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE` (docs 4.7).
- Keystore jednej pary: hasło keystore = hasło klucza (wymóg Godota). Hasła tylko alfanumeryczne (znaki specjalne psują export).
- "Export With Debug" musi być wyłączone przy release.

## 3. Wymagane SDK
| Godot | JDK | Android SDK Platform | Build-Tools | NDK | CMake |
|---|---|---|---|---|---|
| 4.7.2 (przypięty) | OpenJDK 17 | 36 | 36.1.0 | r29 (29.0.14206865) | 3.10.2.4988404 |
Instalacja: `sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "build-tools;36.1.0" "platforms;android-36" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;29.0.14206865"` (wersje wg źródeł Godota 4.7.2: `platform/android/java/app/config.gradle`, `detect.py`; strona docs 4.7 jest w tyle i podaje Build-Tools 35.0.1/Platform 35/NDK r28b). Ścieżki do Godota: Editor Settings → `export/android/java_sdk_path` i `android_sdk_path`. Na Linuksie nie używaj SDK z pakietów dystrybucji.
Gradle build (`use_gradle_build=true`) wymaga zainstalowanego szablonu: menu Project → Install Android Build Template (tworzy `game/android/build/`). W CI sprawdź, jak robi to `.github/workflows/build-android.yml`.
Google Play wymaga od 31.08.2026 (wyjątek do 1.11.2026) targetu API 36 (https://developer.android.com/google/play/requirements/target-sdk). Preset ma `gradle_build/target_sdk="36"`, `min_sdk="24"` (Godot 4.7.2: `DEFAULT_TARGET_SDK_VERSION=36`, `DEFAULT_MIN_SDK_VERSION=24`).
Godot 4.7.2 spełnia wymóg 4.5+ pluginów AdMob i GameAnalytics (ADR-003/004); gdUnit4 v7 (master) wymaga 4.7+. Patrz ADR-008.

## 4. Gdzie szukać przyczyn błędów exportu
1. Cały log: uruchom komendę bez filtrów, szukaj `ERROR:` i `Gradle build failed`. Dodaj `--verbose`.
2. `Could not find Android SDK / Java` → ścieżki w Editor Settings (`~/.config/godot/editor_settings-4.7.tres`) lub `ANDROID_HOME`, `JAVA_HOME`.
3. `No export template found` → `make setup` (templates w `~/.local/share/godot/export_templates/4.7.2.stable/`); wersja templates musi == wersja edytora.
4. `Invalid keystore` / `password` → placeholdery nie podmienione (`tools/inject_secrets.sh`), hasła z znakami specjalnymi.
5. Gradle: `game/android/build/` → `./gradlew assembleRelease --stacktrace` w tym katalogu pokazuje pełny błąd; `./gradlew clean` po zmianie wersji SDK/pluginu.
6. Plugin Android widoczny dopiero po włączeniu go w presecie (Plugins) i Gradle build.
7. Błąd importu zasobów w CI: najpierw `godot --headless --path game --import`.
8. iOS: błąd `JSON text did not start with array...` = zły Team ID (musi być 10 znaków `ABCDE12XYZ`); `xcode-select -p` musi wskazywać `/Applications/Xcode.app`; w nazwie projektu Xcode bez spacji.
Logi CI: `gh run view <id> --log-failed`, workflow `build-android.yml` / `build-ios.yml`.

## 5. Wersjonowanie
Nie podbijaj ręcznie. `release.yml` na tag `v*`: `version_name` = tag bez `v`, `version_code` = `GITHUB_RUN_NUMBER + 100`, a `tools/set_version.sh <name> <code>` ustawia `version/name`, `version/code` (Android), `application/short_version`, `application/version` (iOS) i `VERSION`/`BUILD_INFO` w `game/src/core/version.gd`. Format `version.gd` jest parsowany regexem - zachowaj dwie linie `const BUILD_INFO: String = "..."` i `const VERSION: String = "..."`. `version_code` musi rosnąć z każdym uploadem do Play.

## 6. Symbole debug i rozmiar AAB
- Crashe natywne w Play Console potrzebują symboli: dołącz `native-debug-symbols.zip` (generowane przez Gradle w `game/android/build/build/outputs/`; ZWERYFIKUJ ścieżkę po pierwszym buildzie) przy uploadzie.
- AAB: Play dzieli go per architektura, więc zostaw `arm64-v8a` i `armeabi-v7a` włączone (jak w presecie). W APK wyłącz jedną architekturę, by zmniejszyć plik.
- Limity rozmiaru Play (ZWERYFIKUJ aktualne: https://support.google.com/googleplay/android-developer/answer/9859372): bazowy pobierany ~200 MB; powyżej użyj Play Asset Delivery. Gra casual powinna mieć < 50 MB: kompresuj tekstury (VRAM compression w imporcie), audio OGG, usuń nieużywane zasoby przez `export_filter`.
- Shrinking Java/R8 dla pluginów (np. AdMob): https://poingstudios.github.io/godot-admob-plugin/latest/android_r8_obfuscation/.

## 7. iOS
- Export tylko na macOS z Xcode; wynik to `export/ios/game.xcodeproj` (+ `.pck`). Podpisywanie robi fastlane `ios beta` (match readonly → `build_app` → `upload_to_testflight`), patrz skill `store-release`.
- Preset ma `application/min_ios_version="13.0"`; plugin AdMob wymaga iOS 15+ i Xcode 15+ (ZWERYFIKUJ po wyborze wersji pluginu) - podnieś `min_ios_version`.
- Privacy manifest: preset ma opcje `privacy/*` (`privacy/file_timestamp_access_reasons`, `privacy/disk_space_access_reasons`, `privacy/system_boot_time_access_reasons`, `privacy/user_defaults_access_reasons`, `privacy/active_keyboard_access_reasons`, `privacy/tracking_enabled`, `privacy/tracking_domains`, `privacy/collected_data/*`) - Godot generuje z nich `PrivacyInfo.xcprivacy` aplikacji (docs: EditorExportPlatformIOS 4.7).
- Provisioning przez fastlane `match` (repo z certyfikatami, `MATCH_*` w sekretach); nigdy nie commituj `.mobileprovision`.

Źródła: docs.godotengine.org/en/4.7/tutorials/export/{exporting_projects,exporting_for_android,exporting_for_ios,android_gradle_build}.html, tutorials/editor/command_line_tutorial.html.
