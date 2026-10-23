# Research rynku — R-001

Status: done
Skill: `analytics-review` (sekcja research) + WebSearch / WebFetch
Data rozpoczęcia: 2026-10-23

## Cel

Wybrać podgatunek casual/puzzle, w którym autonomiczna pętla AI (Godot 4.7.2, 2D, PR ≤ 300 linii, zero artystów) zbuduje MVP w 3–5 tygodni. „Wygrana" = (1) content w 100 % generowany z seeda i weryfikowany solverem headless, (2) bot przechodzi 200 rund bez UI, (3) realna ścieżka do ARPDAU ≥ 0,05 USD (kill-line 0,02) i D7 ≥ 12 % przy modelu rewarded ads + IAP.

## Metodologia

Źródła (pobrane 2026-10-23):
- Raporty gatunkowe: Naavik (dane Sensor Tower), Mobidictum (dane AppMagic), mobilegamer.biz (AppMagic), Udonis (AppMagic + Gamigion).
- Store charts: Sensor Tower „top 5" (US/DE). Listy PL nie znaleziono w źródłach publicznych → `ZWERYFIKUJ`.
- eCPM: blog.playio.co (US, 2026), Appodeal przez WN Hub (DE, Q1 2023 — dane stare, traktowane jako dolna granica).
- ASO: iTunes Search API (`https://itunes.apple.com/search?...&country=us|pl|de`) — **zapytania zablokowane w sesji (brak zgody na URL)**; zamiast tego WebSearch ograniczony do `apps.apple.com` (US, top-10 wyników). Liczby wyników i oceny PL/DE → `ZWERYFIKUJ`.
- reddit / YouTube postmortemy: nie użyte (limit zapytań); nie wpływają na ranking.

Zasady:
- Każda liczba ma źródło i datę. Szacunki oznaczone „~". Źródła na dole (sekcja „Źródła", numery [n]).
- Kryteria oceny i wagi (skala 1–5, suma ważona, max 45):

| Kryterium | Waga | Dlaczego |
|---|---|---|
| Content proceduralny + testowalność headless (seed → poziom → solver → bot 200 rund) | **×3** | krytyczne: zero artystów/level designerów, R-002 wymaga testów headless |
| ARPDAU (zakres B3) | ×2 | KPI cel 0,05, kill-line 0,02 |
| Czas do MVP | ×2 | pętla AI, PR ≤ 300 linii, MVP w kilka tygodni |
| Konkurencja ASO (PL/US/DE) | ×1 | wszystkie casual puzzle są nasycone; różnice małe |
| Różnicowanie / retencja (dane D1/D7/D30 gatunku) | ×1 | KPI D7 ≥ 12 % |

Bramka (gate): testowalność headless = „tak", inaczej kandydat odpada niezależnie od sumy.

Metoda ARPDAU (B3, pkt 3 — tytuły kandydatów są głównie ad-driven lub nie mają publicznego DAU):
- `ARPDAU = ARPDAU_ads + ARPDAU_iap`; `ARPDAU_ads = Σ_kraj udział × impresje/DAU × eCPM_blended / 1000`.
- Impresje/DAU z KPI.md: min = 1,5 (kill-line), baza = 3,0 (cel), max = 5,0 (świetnie).
- eCPM blended (mix 2 rewarded : 1 interstitial): US ~12–18 USD (rewarded US 16,49 Android / 19,63 iOS, interstitial 10,11 / 9,64 [3]); DE ~6–10 USD (rewarded iOS 10,22, interstitial iOS 7,27 / Android 4,95, Q1 2023 [4]); PL ~1,5–3 USD = założenie US/10–US/5 (brak danych → `ZWERYFIKUJ` [4]).
- Mix geo (założenie, start organiczny z lokalizacją PL/DE): 30 % US, 30 % DE, 40 % PL.
- `ARPDAU_iap ≈ odsetek DAU płacących w miesiącu × ARPPU miesięczne / 30` (założenia per kandydat).
- Wynik ads (wspólny dla kandydatów z mixem rewarded): min ~0,009, baza ~0,024, max ~0,048 USD.
- Kontrola sensu: Block Blast ~584 tys. USD/dzień z reklam [2] / 35,5 mln DAU (05.2026) [2] = **~0,0165 USD** ARPDAU globalnie (miks z dużym udziałem Tier 3).
- Stickiness (DAU/MAU) dla puzzle: Block Blast 35,5 / 208,7 mln = ~17 % [2] — zgodne z założeniem 15–25 % z B3.

## Kandydaci

| Gatunek | Top przykłady | Szac. ARPDAU | Content generowalny? | Złożoność MVP (tygodnie) | Konkurencja ASO | Ryzyka |
|---|---|---|---|---|---|---|
| 1. Sort puzzle (ball/water sort, poziomy) | Magic Sort, Hexa Sort, Water Match ASMR, Water Sort: Color Puzzle | ~0,010–0,053 (baza ~0,027) | tak — scramble od stanu rozwiązanego + solver BFS | ~3–4 | wysoka (US: 10/10 wyników z „Ball Sort" w tytule) | nasycenie klonami, D1 zależy od FTUE, IAP wymaga boosterów |
| 2. Solitaire TriPeaks lite | Disney Solitaire, Solitaire Grand Harvest, Tiki Solitaire TriPeaks | ~0,012–0,068 (baza ~0,034) | tak — losowe rozdanie z seeda + solver DFS | ~5–7 | bardzo wysoka (US: 10/10 „TriPeaks"; liderzy z dużym UA) | IAP wymaga ciężkiej mety, grafika 52 kart, długie MVP |
| 3. Block puzzle (Block Blast-like, endless) | Block Blast!, Color Block Jam, Blockudoku | ~0,008–0,033 (baza ~0,017) | tak — losowe klocki z seeda, brak poziomów | ~2–3 | bardzo wysoka (US: 10/10 „Block Puzzle") | D7 gatunku 4,1 % < kill-line 8 %, prawie zero IAP |

### Kandydat 1: Sort puzzle (ball / water sort, progresja poziomów)
- Przykłady top-10 (US/PL/DE): Magic Sort - Grand Games - #1 przychodu w podgatunku (~50 mln USD, ~18 % udziału, 2025, global) - [1]; Hexa Sort - Lion Studios - #2 (~20 mln USD, ~7 %, 2025, global) - [1]; Water Match™ ASMR Water Sort - Youyoutang Technology - top-3 pobrań puzzle Android DE, Q4 2025 (~20,8–27,4 tys./tydz.) - [5]; Water Sort: Color Puzzle Game - 100 mln+ pobrań Google Play - [6]. PL: `ZWERYFIKUJ` [9].
- Rdzeń pętli: przelewasz kolor z probówki do probówki, aż każda zawiera 1 kolor; 1 poziom = 20–60 s, sesja 3–5 poziomów = ~2–5 min.
- Szac. ARPDAU: baza ~0,027 USD; zakres ~0,010–0,053. Ads min/baza/max 0,009/0,024/0,048 + IAP (0,5–1,5 % płacących × ARPPU 5–10 USD / 30 = ~0,0008–0,005). Podgatunek: ~280 mln USD IAP w 2025, +176 % r/r, ~1 mld pobrań; monetyzacja rewarded + IAP [1]; w 2026 wyprzedził Blast jako 3. podgatunek puzzle wg IAP [7]. Nie spada pod kill-line w obu scenariuszach (max > 0,02).
- Złożoność contentu: niska — ~60–120 poziomów / 1 h gry, każdy to tylko parametry (liczba kolorów, probówek, pojemność, pustych probówek).
- Content generowalny proceduralnie? tak — seed → losowe ruchy wstecz od stanu rozwiązanego (gwarancja rozwiązywalności) + solver BFS/A* liczący min. liczbę ruchów = metryka trudności; poziom odrzucany, jeśli `min_moves` poza zakresem z `GameConfig`.
- Testowalność headless: tak — stan to tablica tablic intów, ruch = `pour(from, to)`; bot = solver; 200 poziomów w < 1 s, czysta klasa bez `Node`.
- Konkurencja ASO: US — 10/10 pierwszych wyników `apps.apple.com` dla „ball sort puzzle" ma „Ball Sort" w tytule [10]; PL / DE — `ZWERYFIKUJ` [9]. Trudność wejścia na frazę główną: wysoka; realnie long-tail (np. „sort puzzle offline", „color sort" + motyw) i lokalizacja PL/DE.
- Czas do MVP: ~3–4 tygodnie; ryzyka: (1) rynek pełen klonów → potrzebny 1 wyróżnik (np. daily seed + motyw), (2) przychód podgatunku to IAP (boostery/undo/extra tube) — MVP musi je mieć, inaczej zostaje tylko ARPDAU ads, (3) retencja US D30 ~8 % [1] dotyczy liderów z metą; nasz D7 bez mety może być niższy.
- Ocena 1-5: ARPDAU 3 | content proceduralny 5 | czas MVP 4 | ASO 2 | różnicowanie 3 → SUMA 17 (ważona: 6+15+8+2+3 = **34/45**)

### Kandydat 2: Solitaire TriPeaks lite
- Przykłady top-10 (US/PL/DE): Disney Solitaire - SuperPlay - top-5 przychodu US Q4 2025 (szczyt ~1,7 mln USD/tydz.) - [8]; Solitaire Grand Harvest - Supertreat (Playtika) - top-5 US Q4 2025 (~1 mln USD/tydz.) - [8]; Tiki Solitaire TriPeaks - Scopely - top-5 US Q4 2025 (szczyt 571 tys. USD/tydz.) - [8]; Solitaire Associations Journey - Hitapps - [8]; Candy Crush Solitaire - King - [8]. SGH: > 1 mld USD lifetime, 69 mln pobrań, RPD 14,55 USD, 67 % rynku TriPeaks w 2024 [11]. PL / DE: `ZWERYFIKUJ` [9].
- Rdzeń pętli: zdejmujesz kartę o 1 wyższą/niższą od karty na stosie, czyścisz 3 piramidy; rozdanie ~60–120 s, sesja 2–5 rozdań = ~3–6 min.
- Szac. ARPDAU: baza ~0,034 USD; zakres ~0,012–0,068. Ads jak wyżej (0,009–0,048) + IAP (1–3 % × ARPPU 10–20 USD / 30 = ~0,003–0,02). Wysoki IAP gatunku (RPD 14,55 USD [11]) wynika z rozbudowanej mety (farma/kolekcje, boostery) — bez niej IAP spada do poziomu kandydata 1. DAU liderów: `ZWERYFIKUJ` [11].
- Złożoność contentu: średnia — rozdania są losowe, ale meta (mapy, kolekcje, wydarzenia) to dużo contentu i UI.
- Content generowalny proceduralnie? tak — seed → tasowanie 52 kart + układ piramid; solver DFS z memoizacją sprawdza wygrywalność (z/bez jokera). Grafika kart generowalna, ale wymaga fontu CC0/OFL i 52 + rewersy.
- Testowalność headless: tak — stan kart w tablicach, bot = solver / zachłanny gracz; 200 rozdań bez UI.
- Konkurencja ASO: US — 10/10 pierwszych wyników dla „tripeaks solitaire" ma „TriPeaks" w tytule [12]; liderzy z budżetami UA (Playtika, Scopely, King, SuperPlay/Disney IP); PL / DE `ZWERYFIKUJ` [9].
- Czas do MVP: ~5–7 tygodni; ryzyka: (1) bez mety brak IAP, a meta to >10 PR-ów, (2) starsza grupa docelowa US z wysokim CPI, rynek skonsolidowany (67 % u lidera [11]), (3) grafika kart i animacje to więcej assetów niż u kandydatów 1 i 3.
- Ocena 1-5: ARPDAU 4 | content proceduralny 4 | czas MVP 2 | ASO 1 | różnicowanie 2 → SUMA 13 (ważona: 8+12+4+1+2 = **27/45**)

### Kandydat 3: Block puzzle (Block Blast-like, endless 8×8)
- Przykłady top-10 (US/PL/DE): Block Blast! - Hungry Studio - #1 pobrań puzzle Android DE Q4 2025 (szczyt 67,1 tys./tydz.) [5], 284 mln pobrań w 2025 (2. gra świata) [13], 70 mln DAU wg wydawcy (01.2026) [13]; Color Block Jam - Rollic - ~75 % przychodu podgatunku block (~183 mln USD w 2025) [1]; Blockudoku - [14]. PL: `ZWERYFIKUJ` [9].
- Rdzeń pętli: kładziesz 3 klocki na planszy 8×8, czyścisz linie; ruch 5–10 s, partia 3–8 min.
- Szac. ARPDAU: baza ~0,017 USD; zakres ~0,008–0,033. Prawie wyłącznie interstitiale (eCPM US ~10, DE ~6, PL ~1,2–2), IAP ~0 (Block Blast < 10 tys. USD IAP w 2025 [2]). Benchmark rzeczywisty: Block Blast ~0,0165 USD [2]. Baza < kill-line 0,02; tylko max powyżej.
- Złożoność contentu: niska — tryb endless nie potrzebuje poziomów (tryb przygodowy z celami wymaga generatora celów).
- Content generowalny proceduralnie? tak — seed → sekwencja klocków z wagami; opcjonalnie generator „ratujący" (zapewnia ≥ 1 możliwy ruch).
- Testowalność headless: tak — siatka 8×8 bitów, bot zachłanny; 200 partii bez UI.
- Konkurencja ASO: US — 10/10 pierwszych wyników dla „block puzzle game" ma „Block" w tytule [14]; dominacja Block Blast (870 mln pobrań lifetime [2]); PL / DE `ZWERYFIKUJ` [9].
- Czas do MVP: ~2–3 tygodnie; ryzyka: (1) retencja lidera D1 26,1 % / D7 4,1 % / D30 1,1 % [2] — D7 poniżej naszej kill-line 8 %, (2) brak naturalnych miejsc na rewarded (tylko revive) → ARPDAU baza < 0,02, (3) zerowe różnicowanie wobec giganta.
- Ocena 1-5: ARPDAU 2 | content proceduralny 5 | czas MVP 5 | ASO 1 | różnicowanie 1 → SUMA 14 (ważona: 4+15+10+1+1 = **31/45**)

Rozważone i odrzucone przed oceną: word puzzle (słowniki EN/PL/DE = licencje i walidacja per język), idle/incremental (słaba pętla 10–30 s, ekonomia trudna do testu solverem), deck-builder roguelite (content kart/efektów projektowany ręcznie, MVP > 8 tygodni), number merge 2048/2248 (brak publicznych danych przychodu; mechanicznie bliski block puzzle, endless bez poziomów).

## Rekomendacja

Kandydat nr 1 — **sort puzzle (ball/water sort z progresją poziomów)** — ma najwyższą sumę (34/45 ważona, 17/25 bez wag). To najszybciej rosnący duży podgatunek puzzle: ~280 mln USD IAP w 2025 (+176 % r/r) przy ~1 mld pobrań i US D30 ~8 % [1]; w 2026 wyprzedził Blast [7]. Content jest w 100 % generowalny: losowe ruchy wstecz od stanu rozwiązanego dają gwarancję rozwiązywalności, a solver BFS mierzy trudność, więc bot 200 poziomów headless to kilkadziesiąt linii czystego GDScriptu. Monetyzacja pasuje do ADR-003: naturalne placementy rewarded (dodatkowa probówka, cofnij, pomiń poziom) wspierają impresje/DAU ≥ 3, a te same boostery są towarem IAP. Grafika to kolorowe kształty — idealne dla `tools/gen_assets.py`. Najmocniejsze ryzyko: nasycenie klonami i ARPDAU bazowe ~0,027 < cel 0,05 — sprawdzimy to w soft launchu (impresje/DAU i IAP conv. w KPI.md). Wcześniej, w R-002, GDD musi zawierać 1 wyróżnik (np. daily seed + motyw) i metę D7 (streak, kolekcja motywów).

## Decyzja

- Wybrany kandydat: nr 1 (domyślnie wg `BACKLOG.md`, R-001), chyba że `## Pytania do Huberta` zawiera inną odpowiedź. → **nr 1: sort puzzle (ball/water sort, poziomy)**; `## Pytania do Huberta` w chwili decyzji było puste.
- Data decyzji: 2026-10-23
- Uzasadnienie w jednym zdaniu: Sort puzzle łączy najszybciej rosnący przychód w puzzle (~280 mln USD, +176 % r/r [1]) z w pełni proceduralnym, weryfikowalnym solverem contentem i naturalnymi placementami rewarded, co daje najlepszy stosunek ARPDAU do czasu MVP dla pętli AI.

## Źródła (pobrane 2026-10-23)

1. Naavik, „How Niche Subgenres are Reshaping the Mobile Puzzle Market", 22.02.2026 (dane Sensor Tower, 2025) — https://naavik.co/digest/how-niche-subgenres-are-reshaping-the-mobile-puzzle-market/
2. Udonis, „Block Blast Revenue, Downloads & User Statistics [2026]", 09.06.2026 (AppMagic, Gamigion) — https://www.blog.udonis.co/statistics/block-blast
3. Playio, „Rewarded ad benchmarks 2026" — https://blog.playio.co/rewarded-ad-benchmarks-2026
4. WN Hub o raporcie Appodeal (Q1 2023), 03.05.2023 — https://wnhub.io/news/art/item-40260 ; PL bez liczb, raport Q4 2024 bez danych tekstowych: https://appodeal.com/wp-content/uploads/2025/03/Quarterly_Mobile_eCPM_Report_-_Q4_2024.pdf
5. Sensor Tower, Q4 2025 Android top 5 puzzle games units DE — https://sensortower.com/blog/2025-q4-android-top-5-puzzle-games-units-de-64bc1644e1714cfff1e615fc
6. SocialPeta, „Water Sort: Color Puzzle Game surpasses 100 million downloads" (data publikacji nieznana) — https://socialpeta.com/blog/water sort-color-puzzle-game-surpasses-100-million-downloads
7. Mobidictum, „Sort, block, and screw mechanics are reshaping the puzzle games market", 21.07.2026 (AppMagic) — https://mobidictum.com/?p=407410
8. Sensor Tower, Q4 2025 unified top 5 solitaire games revenue US — https://sensortower.com/blog/2025-q4-unified-top-5-solitaire-games-revenue-us-600abc3f241bc16eb850508a
9. iTunes Search API (zablokowane w sesji) — https://itunes.apple.com/search?term=ball+sort+puzzle&country=pl&entity=software&limit=25 (analogicznie `country=de|us`, frazy „tripeaks solitaire", „block puzzle")
10. WebSearch `apps.apple.com` „ball sort puzzle app" (US, top 10), np. https://apps.apple.com/us/app/ball-sort-puzzle/id1494648714
11. mobilegamer.biz, „Data digest: Solitaire Grand Harvest hits $1bn…", 12.02.2025 (AppMagic) — https://mobilegamer.biz/data-digest-solitaire-grand-harvest-hits-1bn-earnings-from-rovio-roblox-krafton-and-square-more/
12. WebSearch `apps.apple.com` „tripeaks solitaire app" (US, top 10), np. https://apps.apple.com/us/app/tiki-solitaire-tripeaks/id892521917
13. mobilegamer.biz, „Data digest: 2025's top earning genres… Block Blast hits 70m DAU", 14.01.2026 — https://mobilegamer.biz/data-digest-2025s-top-earning-genres-appsflyer-for-sale-block-blast-hits-70m-dau-app-store-earnings-more/
14. WebSearch `apps.apple.com` „block puzzle game app" (US, top 10), np. https://apps.apple.com/us/app/blockudoku-block-puzzle-game/id1452227871
