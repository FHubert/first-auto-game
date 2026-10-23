# KPI

Aktualizowane automatycznie przez `tools/metrics_pull.py` (scheduled task `weekly-analytics`).
Nie edytuj sekcji "Aktualne" ręcznie.

## Cele (soft launch → decyzja skaluj/pivot po 4 tygodniach)

| Metryka | Minimum (kill-line) | Cel | Świetnie |
|---|---|---|---|
| D1 retention | 25 % | 35 % | 45 % |
| D7 retention | 8 % | 12 % | 18 % |
| D30 retention | 2 % | 4 % | 7 % |
| Sesje / DAU | 2,0 | 3,0 | 4,5 |
| Śr. długość sesji | 2 min | 4 min | 6 min |
| Ad impressions / DAU | 1,5 | 3,0 | 5,0 |
| Rewarded completion rate | 60 % | 80 % | 90 % |
| ARPDAU (USD) | 0,02 | 0,05 | 0,10 |
| IAP conversion | 0,5 % | 1,5 % | 3 % |
| Crash-free sessions | 99,0 % | 99,5 % | 99,8 % |
| Store conversion (wyśw.→instal.) | 15 % | 25 % | 35 % |

## Reguły decyzyjne (stosuje skill `analytics-review`)
1. crash-free < 99,0 % → wszystko inne czeka; P0 stabilność.
2. D1 < 25 % → priorytet: FTUE/onboarding, pierwsza sesja, trudność pierwszych 5 rund.
3. D1 OK, D7 < 8 % → priorytet: meta (daily reward, streak, progresja długoterminowa, notyfikacje).
4. Retencja OK, ad impr/DAU < 1,5 → priorytet: placementy rewarded (wartość nagrody, moment), cap interstitiali.
5. Retencja OK, rewarded completion < 60 % → nagroda za słaba lub placement w złym momencie.
6. Wszystko ≥ cel przez 2 tygodnie z rzędu → `docs/STATUS.md`: faza "Scale" (rozszerz rynki, lokalizacje, mały test UA).
7. Po 4 tygodniach soft launchu D1 < 25 % mimo 2 iteracji FTUE → raport `docs/PIVOT_OR_KILL.md`, task `blocked`, pytanie do Huberta.

## Aktualne
_(brak danych — gra nie jest jeszcze wydana)_

| Tydzień | DAU | D1 | D7 | D30 | Ses/DAU | AdImp/DAU | RewComp | ARPDAU | IAP conv | Crash-free |
|---|---|---|---|---|---|---|---|---|---|---|
