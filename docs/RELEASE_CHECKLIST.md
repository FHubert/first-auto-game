# Checklista przed tagiem

Każdy punkt sprawdzamy przed `git tag`. Niezaznaczony punkt oznacza brak wydania.

## Jakość
- [ ] Testy zielone: `make check` (lint + gdUnit4 + export-check) na tagowanym commicie.
- [ ] Playtest bez softlocka: `game/test/reports/playtest.json` bez softlocka.
- [ ] Crash-free na Firebase Test Lab.
- [ ] `make perf` na CI (`game/test/reports/perf.json`) i ten sam scenariusz na urządzeniu budżetowym (T-054) — iloraz telefon/CI wpisany do ADR-011/ADR-014 jako uzupełnienie w nowym ADR, nie edycją.
- [ ] Screenshoty aktualne (`make screenshots`).
- [ ] Changelog w `fastlane/metadata`.
- [ ] Adapter SDK (reklamy, IAP, zgoda, powiadomienia, analityka) dopisany do `PAIRS` w `test_provider_contracts.gd` i zielony przed podpięciem w `App`/autoloadzie (Faza 5).

## Google Play
- [ ] Data Safety zgodne z eventami w `docs/GDD.md` → Analityka oraz z SDK (AdMob, GameAnalytics).
  Tabela odpowiedzi Data Safety (aktualizować przy każdej zmianie listy eventów; całość ZWERYFIKUJ przed wysłaniem formularza):

  | Typ danych (Play) | Zbierane | Udostępniane | Cel | Opcjonalne | Źródło/eventy |
  |---|---|---|---|---|---|
  | Device or other IDs | tak | tak (AdMob, GameAnalytics) | Analytics, Advertising | nie | SDK: AdMob, GA |
  | App interactions | tak | tak (GA) | Analytics | nie | level_start, level_complete, level_fail, level_pause, tutorial_step, nav, daily_share, level_stuck, booster_used, daily_reward_claimed, streak_changed, daily_challenge_complete, theme_unlocked, coins_earned, session_start, session_end, daily_month_goal, config_variant, notif_scheduled, save_recovered, level_assist, level_attempt, notif_permission |
  | App info and performance (Diagnostics) | ZWERYFIKUJ (czy GA zbiera crash logs) | ZWERYFIKUJ | Analytics | nie | SDK |
  | Purchase history | tak | nie | App functionality | nie | iap_purchase |
  | Advertising interactions | tak | tak (AdMob) | Advertising | nie | rewarded_offered, rewarded_completed, interstitial_shown, ads_watchdog, ads_load |
  | Approximate location | ZWERYFIKUJ (IP → kraj) | ZWERYFIKUJ (AdMob/GA) | Analytics, Advertising | nie | SDK |
  | Consent (informacyjnie, nie jest „danymi" w Play) | - | - | - | - | consent_result |
  | Dane osobowe wpisywane przez gracza | nie | nie | - | - | brak kont i pól tekstowych |

- [ ] UMP consent przetestowany na EEA.
- [ ] Polityka prywatności: URL podany w Play Console.
- [ ] Staged rollout 10 %.

## App Store Connect
- [ ] Privacy Nutrition Labels zgodne z eventami w `docs/GDD.md` → Analityka (całość ZWERYFIKUJ przed wysłaniem):

  | Kategoria (ASC) | Linked to user | Used for tracking | Źródło |
  |---|---|---|---|
  | Identifiers → Device ID | AdMob: tak (ZWERYFIKUJ); GA: nie (ZWERYFIKUJ) | AdMob: tak, tylko po zgodzie ATT; GA: nie (ZWERYFIKUJ) | SDK; consent_result |
  | Usage Data → Product Interaction | nie (ZWERYFIKUJ) | nie | level_start, level_complete, level_fail, level_pause, tutorial_step, nav, daily_share, level_stuck, booster_used, session_start, session_end, streak_changed, daily_reward_claimed, daily_challenge_complete, theme_unlocked, coins_earned, daily_month_goal, config_variant, notif_scheduled, save_recovered, level_assist, level_attempt, notif_permission |
  | Usage Data → Advertising Data | ZWERYFIKUJ | tak, tylko po ATT | rewarded_offered, rewarded_completed, interstitial_shown, ads_watchdog, ads_load |
  | Purchases → Purchase History | nie (ZWERYFIKUJ) | nie | iap_purchase |
  | Diagnostics → Crash Data | ZWERYFIKUJ | ZWERYFIKUJ | SDK |
  | Location → Coarse Location | ZWERYFIKUJ | ZWERYFIKUJ | SDK (IP → kraj) |

- [ ] Privacy manifest iOS: plik źródłowy `game/ios/PrivacyInfo.xcprivacy` (T-064), podpięcie w presecie iOS w T-053; SDK AdMob i GameAnalytics dostarczają własne manifesty; domeny trackingu (tracking domains) ZWERYFIKUJ (lista pusta do instalacji pluginu).
- [ ] ATT prompt na iOS.
- [ ] Polityka prywatności: URL podany w App Store Connect.
- [ ] Polityka prywatności opublikowana (docs/privacy/ → GitHub Pages lub strona All In IT), URL wpisany w metadata (__PRIVACY_URL__) — wymaga Huberta
- [ ] Przegląd prawny polityki (DRAFT) — wymaga Huberta

## Wersja
- [ ] Wersja podbita przez `release.yml`, nie ręcznie.
