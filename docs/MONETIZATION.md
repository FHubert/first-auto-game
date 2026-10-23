# Monetyzacja

Status: DRAFT
Źródło: `docs/GDD.md` (Ekonomia, Meta) · Progi: `KPI.md` · Parametry: `game/src/systems/config.gd` (GameConfig)

## Model
*Rewarded ads jako główne źródło przychodu, IAP jako dodatek. Opisz, za co gracz płaci i dlaczego nie wpływa to na wygraną.*

- Model: rewarded ads (główny) + IAP (dodatkowy).
- Brak banneru w MVP.
- Propozycja: IAP nie daje przewagi, której gracz nie zdobędzie w grze.

## Placementy
*Każdy placement: moment w sesji, nagroda, cap. Wartość `id` musi być zgodna z eventami w `docs/GDD.md` → Analityka.*

| id | moment | nagroda | cap |
|---|---|---|---|
| | | | |
| | | | |
| | | | |

## Produkty IAP
*Każdy produkt: sku, cena w USD (tier sklepu) i zawartość. Produkt wchodzi do tabeli dopiero po zatwierdzeniu w GDD.*

| sku | cena USD | zawartość |
|---|---|---|
| | | |

## Zasady
- Brak banneru w MVP.
- Interstitial: cap czytany z `GameConfig`, nigdy wpisany na sztywno w scenie.
- Rewarded: zawsze dobrowolny; gracz widzi nagrodę przed startem reklamy.
- Propozycja: brak interstitiali w pierwszej sesji (onboarding), do weryfikacji w A/B.
- Consent: UMP przed pierwszym żądaniem reklamy (EEA); ATT prompt na iOS przed śledzeniem.
- Każda reklama i zakup przechodzą przez `AdProvider` (ADR-003); w testach działa `FakeAdProvider`.

## Hipotezy do A/B
*Każda hipoteza: co zmieniamy, która metryka z `KPI.md` ma wzrosnąć i do jakiego progu. Testy A/B działają dopiero od Fazy 6 (Firebase Remote Config, ADR-004).*

| id | hipoteza | metryka | próg (KPI.md) | wariant A | wariant B |
|---|---|---|---|---|---|
| H1 (przykład) | Podwojona nagroda rewarded po rundzie zwiększa ukończenia reklam | Rewarded completion | ≥ 80 % | 1× nagroda | 2× nagroda |
| H2 (przykład) | Interstitial co 5 rund zamiast co 3 nie obniża D1 | Ad impressions / DAU, D1 | ≥ 3,0 przy D1 ≥ 35 % | co 3 rundy | co 5 rund |
| H3 (przykład) | Pakiet startowy w IAP podnosi konwersję | IAP conversion | ≥ 1,5 % | brak oferty | oferta po 1. sesji |
