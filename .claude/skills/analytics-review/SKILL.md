---
name: analytics-review
description: Uzyj w cotygodniowym przegladzie metryk (python3 tools/metrics_pull.py, KPI.md, reguly decyzyjne, przepisanie P1/P2, docs/EXPERIMENTS.md) oraz przy researchu rynku i wyborze gatunku (R-001).
---

# analytics-review — tygodniowy przegląd i research rynku

Wykonuje `monetization-analyst` (w `weekly-analytics`) albo `game-designer` (sekcja research). Dane tylko z narzędzi; brak danych = „brak danych", nigdy zgadywanie.

## Część A: tygodniowy przegląd

### A1. Pobranie metryk
```
python3 tools/metrics_pull.py --dry-run                      # gra NIE wydana / brak kluczy: losowe dane testowe, oznacz to w KPI.md
python3 tools/metrics_pull.py --ga-csv export.csv [--week 2026-W43]   # z eksportu GameAnalytics
python3 tools/metrics_pull.py --dry-run --kpi-path /tmp/kpi.md        # próba bez ruszania KPI.md
```
Skrypt dopisuje wiersz do tabeli „## Aktualne" w `KPI.md` (nagłówek: Tydzień | DAU | D1 | D7 | D30 | Ses/DAU | AdImp/DAU | RewComp | ARPDAU | IAP conv | Crash-free) i wypisuje JSON na stdout (logi na stderr). Kolumny CSV: `date,dau,sessions,d1_retention,d7_retention,d30_retention,ad_impressions,rewarded_started,rewarded_completed,iap_buyers,iap_revenue_usd,crash_free`. Źródła AdMob/Play to stuby aktywne po ustawieniu zmiennych `ADMOB_*`. Nie edytuj sekcji „Aktualne" ręcznie.
Przed wydaniem: dopisz pod tabelą linię `_Dane testowe (--dry-run), gra niewydana._`, aby reguły decyzyjne nie były liczone jako realne.

### A2. Czytanie KPI.md
Porównaj ostatni wiersz z tabelą „Cele": każda metryka → `KILL` (< kill-line), `OK` (>= kill-line, < cel), `CEL` (>= cel), `TOP` (>= „świetnie"). Dla trendu porównaj z poprzednim tygodniem (Δ). Minimalna próbka: DAU < 100 → wyniki oznacz „za mała próbka", nie zmieniaj priorytetów na ich podstawie.

### A3. Reguły decyzyjne (KPI.md) jako pseudokod
Pierwsza pasująca reguła w kolejności wyznacza priorytet P1; kolejne uzupełniają P2.
```
m = ostatni_tydzień ; prev = poprzedni_tydzień
if dau < 100 and not dry_run_ok: return "brak danych: P1 = pozyskanie ruchu / instrumentacja"
if m.crash_free < 99.0:                         # reguła 1
    P0 = "stabilność: crashe"; wszystko inne wstrzymaj
elif m.d1 < 25:                                 # reguła 2
    P1 = ["FTUE/onboarding", "pierwsza sesja", "trudność rund 1-5 (win rate >= 90%)"]
elif m.d7 < 8:                                  # reguła 3 (D1 >= 25)
    P1 = ["daily reward", "streak", "progresja długoterminowa", "notyfikacje"]
elif m.ad_impr_per_dau < 1.5:                   # reguła 4 (retencja OK)
    P1 = ["placementy rewarded (wartość nagrody, moment)", "cap interstitiali"]
elif m.rewarded_completion < 60:                # reguła 5
    P1 = ["większa nagroda rewarded", "zmiana momentu placementu"]
if wszystkie_metryki >= cel for 2 tygodnie z rzędu:   # reguła 6
    STATUS.md: faza "Scale" (rynki, lokalizacje, mały test UA)
if tygodni_soft_launchu >= 4 and m.d1 < 25 and iteracji_FTUE >= 2:   # reguła 7
    utwórz docs/PIVOT_OR_KILL.md; zadanie 'blocked'; pytanie do Huberta
```
Dodatkowo (poza regułami): ARPDAU < 0,02 przy OK retencji → hipoteza monetyzacyjna (H1–H3 w `docs/MONETIZATION.md`); IAP conv < 0,5 % → oferta/cena; store conversion < 15 % → skill `aso`.
Alarm kill-line: 2 tygodnie z rzędu wartości poniżej kill-line → zgłoś w raporcie (orkiestrator tworzy `docs/PIVOT_OR_KILL.md` i zadanie `blocked` z pytaniem).

### A4. Jak sformułować zadanie do backlogu
Format (jak w `BACKLOG.md`), max 10 zadań w P1+P2 razem, każde mieści się w ~300 liniach:
```
- [ ] P1-007 `todo` Łatwiejsze rundy 1-5 w generatorze
  KA: win rate bota w rundach 1-5 >= 85 % (test, seed 42); docelowo D1 wzrasta z 22 % do >= 25 % w 2 tygodnie po wydaniu. Metryka: D1 retention (KPI.md).
  Skill: `game-economy`
```
Wymagane: ID (`P1-NNN` / `P2-NNN`, kolejne), status `todo`, tytuł w trybie rozkazującym, KA **mierzalne** (test/liczba), **metryka** z KPI.md, która ma się zmienić, i **o ile** (z wartości do wartości), skill. Zadanie bez mierzalnego KA nie wchodzi do backlogu. Kolejność: zależności (core loop → save → UI → meta → monetyzacja), potem wpływ na metrykę z reguły.
Porządki: przenieś pozycje z `## Inbox` do P1/P2 (jeśli adresują aktywną regułę) lub `## P3`; duplikaty scal; nie ruszaj `in_progress`/`review`/`done`; zadania wymagające decyzji → `blocked` + `## Pytania do Huberta`.

### A5. Format `docs/EXPERIMENTS.md` (1 nowy eksperyment tygodniowo)
```
## EXP-007: Podwójna nagroda rewarded po rundzie
- Data startu: 2026-11-03 · Status: planned|running|done
- Hipoteza: Jeśli zwiększymy `rewarded_multiplier` z 2.0 do 3.0, ukończenia reklam wzrosną, bo nagroda jest bardziej widoczna.
- Parametr (remote config / GameConfig): `rewarded_multiplier`
- Warianty: A (kontrola) 2.0 · B 3.0 · podział 50/50
- Metryka główna: Rewarded completion (KPI.md); guardrail: D1 nie spada o > 2 pp, ARPDAU nie spada
- Min. próbka: >= 500 graczy/wariant (lub 14 dni); zatrzymaj wcześniej tylko przy guardrail
- Czas: 14 dni
- Decyzja po teście: wdrożyć B jeśli +5 pp przy braku regresji; inaczej zostaw A
- Wynik: (puste do zakończenia)
```
Testy A/B z Remote Config działają od Fazy 6 (ADR-004); wcześniej eksperyment = zmiana wartości w `GameConfig` i porównanie kohort tygodniowych (zaznacz, że jest to porównanie przed/po, nie A/B).

## Część B: Research rynku (R-001, `docs/RESEARCH.md`)

### B1. Źródła (bez płatnych narzędzi)
- **AppMagic** (free tier: top grossing/downloads, podstawowe przychody) - appmagic.rocks; **Sensor Tower blog** (raporty i top listy, sensortower.com/blog); **data.ai** (dawny App Annie; dostęp publiczny ograniczony - ZWERYFIKUJ, co jest darmowe); zakres darmowych planów się zmienia - ZWERYFIKUJ.
- **Store charts** przez `WebFetch`: Google Play top Games: `https://play.google.com/store/apps/category/GAME?hl=en&gl=US` (rynki: US, PL, DE przez `gl=`); App Store: iTunes RSS `https://rss.applemarketingtools.com/api/v2/us/apps/top-free/50/apps.json` (zamień `us`→`pl`/`de`, `top-free`→`top-paid`; ZWERYFIKUJ aktualność API) oraz iTunes Search `https://itunes.apple.com/search?term=<gatunek>&country=us&entity=software`.
- **r/gamedev** (postmortemy, wątki o monetyzacji/retencji), **Deconstructor of Fun** (deconstructoroffun.com - analizy gatunków i ekonomii gier mobilnych), GDC Vault/YouTube postmortemy, Game Developer (gamedeveloper.com).
- Każdy fakt w RESEARCH.md ma URL i datę pobrania.

### B2. Szablon oceny kandydata (3 kandydatów)
```
### Kandydat N: <gatunek/podgatunek>
- Przykłady top-10 (US/PL/DE): <tytuł - wydawca - pozycja/rynek - źródło>
- Rdzeń pętli (1 zdanie) i długość sesji
- Szac. ARPDAU: <wartość USD, metoda poniżej, zakres min–max>
- Złożoność contentu: niska|średnia|wysoka - ile unikalnego contentu na 1 h gry
- Content generowalny proceduralnie? tak|częściowo|nie - jak (seed+reguły, solver sprawdzający rozwiązywalność)
- Testowalność headless: czy bot przejdzie 200 rund bez UI
- Konkurencja ASO: PL / US / DE (liczba wyników z frazą w tytule, ich oceny, trudność wejścia)
- Czas do MVP: <tygodnie>; ryzyka: <3 punkty>
- Ocena 1-5: ARPDAU | content proceduralny | czas MVP | ASO | różnicowanie → SUMA
```
Rekomendacja: kandydat o najwyższej sumie, z uzasadnieniem w 5 zdaniach; zadanie R-001 mówi: bierz kandydata nr 1 (chyba że `## Pytania do Huberta` mówi inaczej). Zaktualizuj `docs/STATUS.md`.

### B3. Szacowanie ARPDAU z danych publicznych
1. Z AppMagic/Sensor Tower weź miesięczny przychód (grossing) tytułu i liczbę pobrań/MAU w kraju. `DAU ≈ MAU × 0,2` (stickiness casual 15–25 %; ZWERYFIKUJ dla gatunku).
2. `ARPDAU = przychód_dzienny / DAU = (przychód_miesięczny / 30) / DAU`. Podziel przychód: IAP vs reklamy (casual: reklamy zwykle 50–80 % przychodu; dane z raportów gatunku - ZWERYFIKUJ).
3. Przy braku przychodów (tytuły ad-driven nie mają IAP w rankingach grossing): `ARPDAU_ads ≈ (impresje/DAU × eCPM)/1000`; impresje/DAU ze `KPI.md` (cel 3,0); eCPM rewarded i interstitial per kraj z publicznych raportów sieci (np. AppLovin/IronSource/Unity - ZWERYFIKUJ aktualne), US wyższy niż PL ~5–10×.
4. Zawsze podawaj zakres (min–max) i założenia; ARPDAU < 0,02 USD w obu scenariuszach = kandydat odpada (kill-line KPI).
