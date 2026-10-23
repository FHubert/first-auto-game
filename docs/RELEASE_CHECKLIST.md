# Checklista przed tagiem

Każdy punkt sprawdzamy przed `git tag`. Niezaznaczony punkt oznacza brak wydania.

## Jakość
- [ ] Testy zielone: `make check` (lint + gdUnit4 + export-check) na tagowanym commicie.
- [ ] Playtest bez softlocka: `game/test/reports/playtest.json` bez softlocka.
- [ ] Crash-free na Firebase Test Lab.
- [ ] Screenshoty aktualne (`make screenshots`).
- [ ] Changelog w `fastlane/metadata`.

## Google Play
- [ ] Data Safety zgodne z eventami w `docs/GDD.md` → Analityka oraz z SDK (AdMob, GameAnalytics).
  Dane zbierane przez eventy GA (GDD → Analityka); aktualizować przy każdej zmianie listy eventów:
  - identyfikatory urządzenia/SDK (GameAnalytics, AdMob),
  - postęp w grze (poziomy, wygrane/porażki, boostery),
  - interakcje z reklamami (placement, wynik),
  - zakupy IAP (sku, kwota, waluta),
  - diagnostyka/sesje (start/koniec, czas),
  - wynik zgody UMP/ATT,
  - brak danych osobowych wpisywanych przez gracza.
- [ ] UMP consent przetestowany na EEA.
- [ ] Polityka prywatności: URL podany w Play Console.
- [ ] Staged rollout 10 %.

## App Store Connect
- [ ] Privacy Nutrition Labels zgodne z eventami w `docs/GDD.md` → Analityka.
- [ ] Privacy manifest iOS (`PrivacyInfo.xcprivacy`) zawiera SDK AdMob i GameAnalytics.
- [ ] ATT prompt na iOS.
- [ ] Polityka prywatności: URL podany w App Store Connect.

## Wersja
- [ ] Wersja podbita przez `release.yml`, nie ręcznie.
