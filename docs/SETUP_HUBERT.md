# Konfiguracja ręczna — Hubert

Jednorazowe kroki, których Claude nie zrobi za Ciebie: konta, płatności i sekrety. Po każdym kroku zaktualizuj tabelę „Blokery wymagające Huberta" w `docs/STATUS.md`.

Zasady:
- Sekrety wklejasz wyłącznie w GitHub → Settings → Secrets and variables → Actions. Nie do repo, nie na czat.
- Konta sklepowe zakładasz na firmę All In IT sp. z o.o. Konto osobiste w Google Play ma wymóg 12 testerów × 14 dni przed produkcją.
- Hasła i klucze trzymaj w menedżerze haseł.

Repo: `https://github.com/FHubert/first-auto-game`. Owner: FHubert.

---

## 1. Konto Google Play Developer
- **Co zrobić:** załóż konto developera na firmę All In IT sp. z o.o. (opłata jednorazowa).
- **Gdzie:** https://play.google.com/console
- **Sekrety:** brak w tym kroku.

## 2. Service account dla fastlane (Google Play)
- **Co zrobić:** w Play Console → Setup → API access podłącz service account z Google Cloud, nadaj mu uprawnienia do wydawania aplikacji i pobierz klucz JSON.
- **Gdzie:** https://play.google.com/console oraz https://console.cloud.google.com/iam-admin/serviceaccounts
- **Sekrety:**
  - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` ← cała zawartość pliku JSON.

## 3. Apple Developer Program
- **Co zrobić:** zapisz się do Apple Developer Program na firmę. Wymaga danych firmy i numeru D-U-N-S.
- **Gdzie:** https://developer.apple.com/programs/
- **Sekrety:** brak w tym kroku.

## 4. Klucz App Store Connect API
- **Co zrobić:** Users and Access → Integrations → App Store Connect API → wygeneruj klucz z rolą App Manager. Plik `.p8` pobierzesz tylko raz.
- **Gdzie:** https://appstoreconnect.apple.com/access/integrations/api
- **Sekrety:**
  - `APP_STORE_CONNECT_API_KEY_ID` ← Key ID z listy kluczy.
  - `APP_STORE_CONNECT_ISSUER_ID` ← Issuer ID z góry strony.
  - `APP_STORE_CONNECT_API_KEY_P8` ← cała zawartość pliku `.p8`.

## 5. Prywatne repo na certyfikaty iOS (fastlane match)
- **Co zrobić:** utwórz prywatne repo git na certyfikaty (np. `first-auto-game-certs`). Ustal hasło szyfrowania match. Wygeneruj token dostępu do tego repo.
- **Gdzie:** https://docs.fastlane.tools/actions/match/
- **Sekrety:**
  - `MATCH_GIT_URL` ← URL repo, np. `https://github.com/FHubert/first-auto-game-certs.git`.
  - `MATCH_PASSWORD` ← hasło szyfrowania match.
  - `MATCH_GIT_BASIC_AUTHORIZATION` ← `user:token` zakodowane w base64:
    ```
    echo -n "<user>:<token>" | base64 | pbcopy
    ```

## 6. Keystore Android
- **Co zrobić:** wygeneruj keystore. Hasło i plik zapisz w menedżerze haseł i zrób kopię zapasową. Nie commituj pliku do repo.
  ```
  keytool -genkeypair -v -keystore keystore.jks -alias <ALIAS> -keyalg RSA -keysize 2048 -validity 10000
  ```
  Zakodowanie pod sekret (wynik ląduje w schowku):
  ```
  base64 -i keystore.jks | pbcopy
  ```
- **Gdzie:** `keytool` z JDK (https://adoptium.net).
- **Sekrety:**
  - `ANDROID_KEYSTORE_BASE64` ← zawartość schowka z `base64 -i keystore.jks | pbcopy`.
  - `ANDROID_KEYSTORE_PASSWORD` ← hasło keystore.
  - `ANDROID_KEY_ALIAS` ← `<ALIAS>` z komendy keytool.
  - `ANDROID_KEY_PASSWORD` ← hasło klucza.

## 7. AdMob
- **Co zrobić:** dodaj aplikację Android i aplikację iOS. Dla każdej utwórz ad unit: rewarded i interstitial.
- **Gdzie:** https://admob.google.com (Apps → Add app).
- **Sekrety:**
  - `ADMOB_APP_ID_ANDROID` ← App ID Android (`ca-app-pub-…~…`).
  - `ADMOB_APP_ID_IOS` ← App ID iOS.
  - `ADMOB_UNIT_REWARDED_ANDROID` ← ad unit ID rewarded, Android.
  - `ADMOB_UNIT_REWARDED_IOS` ← ad unit ID rewarded, iOS.
  - `ADMOB_UNIT_INTERSTITIAL_ANDROID` ← ad unit ID interstitial, Android.
  - `ADMOB_UNIT_INTERSTITIAL_IOS` ← ad unit ID interstitial, iOS.
- **Uwaga:** na emulatorze i w testach używaj testowych ad units Google. Klikanie własnych reklam grozi banem konta AdMob.

## 8. GameAnalytics
- **Co zrobić:** załóż konto, utwórz grę dla Android i iOS. Skopiuj Game Key i Secret Key z ustawień gry.
- **Gdzie:** https://gameanalytics.com
- **Sekrety:**
  - `GA_GAME_KEY` ← Game Key.
  - `GA_SECRET_KEY` ← Secret Key.

## 9. Klucz Anthropic API (tylko jeśli pętla ma działać poza Claude Code Remote)
- **Co zrobić:** wygeneruj klucz w konsoli API.
- **Gdzie:** https://console.anthropic.com
- **Sekrety:**
  - `ANTHROPIC_API_KEY` ← klucz API.

## 10. GitHub Environment `production`
- **Co zrobić:** Settings → Environments → New environment `production` → Required reviewers: dodaj siebie. Bez tego ręczny approve promocji do produkcji nie zadziała.
- **Gdzie:** https://github.com/FHubert/first-auto-game/settings/environments
- **Sekrety:** brak.

## 11. Branch protection na `main`
- **Co zrobić:** Settings → Branches → reguła dla `main`: Require a pull request before merging, Require status checks to pass → `test.yml`, bez bezpośredniego push.
- **Gdzie:** https://github.com/FHubert/first-auto-game/settings/branches
- **Sekrety:** brak.

## 12. Auto-merge
- **Co zrobić:** Settings → General → Pull Requests → zaznacz „Allow auto-merge". Pętla używa `gh pr merge --auto --squash`.
- **Gdzie:** https://github.com/FHubert/first-auto-game/settings
- **Sekrety:** brak.

## 13. Claude Code Remote environment dla repo
- **Co zrobić:** skonfiguruj environment dla tego repo zgodnie z `docs/AUTOMATION.md`.
- **Gdzie:** https://claude.ai/code
- **Sekrety:** brak (`ANTHROPIC_API_KEY` tylko przy kroku 9).

## 14. Firebase Remote Config (opcjonalnie, Faza 6)
- **Co zrobić:** pomiń teraz. Wrócisz do tego w Fazie 6.
- **Gdzie:** https://console.firebase.google.com
- **Sekrety:** brak na tym etapie.

---

Po krokach 2–9 w Settings → Secrets and variables → Actions powinno być 20 sekretów. Jeśli pominiesz krok 9, zostaje 19.
