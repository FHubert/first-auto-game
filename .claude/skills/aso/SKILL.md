---
name: aso
description: Uzyj przy pisaniu lub zmianie tytulu, opisow, keywordow, screenshotow i lokalizacji w sklepach (Google Play i App Store), badaniu slow kluczowych oraz aktualizacji fastlane/metadata.
---

# aso — optymalizacja listingu

## 1. Limity (zweryfikowane w dokumentacji sklepów)
| Pole | Play | App Store |
|---|---|---|
| Tytuł / Name | 30 znaków | 30 znaków |
| Subtitle | - | 30 znaków |
| Short description | 80 znaków | - |
| Promotional text | - | 170 znaków (zmienialny bez nowej wersji) |
| Keywords | - | **100 bajtów** (nie „znaków" - w UTF-8 znak z polską ogonkiem = 2 bajty) |
| Full description | 4000 znaków | 4000 znaków |
| What's new / changelog | 500 znaków (`changelogs/<version_code>.txt`) | 4000 znaków |
Źródła: Play https://support.google.com/googleplay/android-developer/answer/9859152; ASC https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information i .../app-information.

## 2. Zasady pól
- **Tytuł**: marka + 1 główne słowo kluczowe („Brand: Keyword"). Bez emoji, bez „#1", bez cen, bez nazw cudzych gier/marek (odrzucenie). Sprawdź wolność nazwy w Play (wyszukiwarka sklepu) i w ASC (App Store Connect → New App – nazwa musi być unikalna) oraz w rejestrach znaków (EUIPO/UPRP) - dopiero potem wybór.
- **iOS subtitle** (30): komplementarne słowa, których nie ma w tytule („Relaksująca logiczna gra"). Nie powtarzaj słów z tytułu (Apple indeksuje je razem).
- **iOS keyword field** (100 bajtów): słowa po przecinkach, **bez spacji** po przecinkach, liczba pojedyncza (Apple łączy formy), bez duplikatów z tytułem/subtitle, bez nazwy firmy i cudzych marek, słowa >2 znaki. Przykład: `puzzle,logic,brain,relax,casual,offline,match,mind` (47 B). Licz: `python3 -c "print(len('k1,k2'.encode()))"`.
- **Play short description** (80): pierwsze zdanie widoczne bez rozwijania - hak + główne słowo kluczowe, bez powielania tytułu i screenshotów.
- **Full description** (4000): struktura: (1) hak 2 linie, (2) 3–5 punktów cech (- lub •), (3) „Dlaczego pokochasz" (emocje), (4) informacja o reklamach i zakupach („Gra zawiera opcjonalne reklamy nagradzane i zakup usuwający reklamy" - wymóg uczciwości), (5) kontakt/polityka. Słowo kluczowe 3–5× naturalnie (Play indeksuje opis; App Store nie indeksuje opisu).

## 3. Research słów kluczowych bez płatnych narzędzi
1. **Autocomplete sklepów**: wpisz rdzeń („puzzle", „match") w pasek wyszukiwania Play i App Store w danym kraju/języku, zapisz podpowiedzi (kolejność ≈ popularność). Dla Play: `WebFetch` na `https://play.google.com/store/search?q=<fraza>&c=apps&hl=pl&gl=PL`. Dla iOS: `https://itunes.apple.com/search?term=<fraza>&country=pl&entity=software&limit=25` (publiczne API iTunes Search, JSON: nazwy, kategorie, oceny).
2. **Konkurencja**: top 10–20 wyników dla frazy → tytuły, subtitle, pierwsze zdania opisu; policz częstość słów (które słowa mają wszyscy). Luka = fraza z mało wynikami, ale sensowną podpowiedzią.
3. **Google Trends** (trends.google.com): porównaj 3–5 fraz, filtr kraj + „Google Play"/„Web", okres 12 mies. - wybór między synonimami.
4. Ocena frazy 1–5: trafność (czy to nasza gra), popularność (pozycja w autocomplete), konkurencja (ile aplikacji z frazą w tytule i ich ocen). Zapisz w tabeli `docs/ASO.md` (20 keywordów: kolumny keyword, wolumen szac., konkurencja).
5. Wszystko, czego nie dało się sprawdzić, oznacz `ZWERYFIKUJ`. Nie wymyślaj wolumenów - pisz „niski/średni/wysoki" z uzasadnieniem (pozycja w autocomplete).

## 4. Screenshoty i ikona
- **5 screenshotów**, kolejność: #1 = HAK (najważniejsza mechanika + krótki nagłówek 3–5 słów, czytelny w miniaturce), #2 core loop, #3 progresja/nagrody, #4 meta (daily, streak), #5 social proof/kolekcja. Tekst duży, kontrast, bez UI sklepu i ramek urządzeń z cudzymi logo.
- **Google Play**: do 8 na typ urządzenia; PNG/JPEG; telefon: proporcje 16:9 lub 9:16 (ZWERYFIKUJ minimum liczby i zakres pikseli dla telefonów: https://support.google.com/googleplay/android-developer/answer/9866151; tablety/Chromebook min. 4 zrzuty, 1080–7680 px); **ikona 512×512, 32-bit PNG z alfą, max 1024 KB**; **feature graphic 1024×500**, JPEG lub 24-bit PNG bez alfy.
- **App Store Connect**: wymagany co najmniej 1 zrzut dla iPhone (Dynamic Island, medium) i, gdy aplikacja działa na iPadzie, dla iPada 13". Rozmiary (portret): iPhone 6.9" `1320×2868` (też `1290×2796`, `1260×2736`), iPhone 6.3" `1206×2622` / `1179×2556`; iPad 13" `2064×2752`. Do 10 zrzutów na rozmiar; JPEG/PNG **bez kanału alfa**; wystarczy największy rozmiar - ASC skaluje w dół. Źródło: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications (rozmiary zmieniają się z nowymi iPhone'ami - sprawdź przed generowaniem).
- **Ikona iOS**: 1024×1024 PNG, bez alfa, bez zaokrągleń (Apple zaokrągla). Obie ikony: bez tekstu, jedna prosta forma, wysoki kontrast (skill `asset-gen`).
- Zrzuty generuje `make screenshots` (`tools/gen_screenshots.sh`) do `fastlane/metadata/`; każdy nowy ekran = wpis w skrypcie.

## 5. Lokalizacja (soft launch)
| Język | Locale Play | Locale iOS | Uwagi |
|---|---|---|---|
| polski | `pl-PL` | `pl` | rynek domowy, test copy |
| angielski (US) | `en-US` | `en-US` | język bazowy/fallback, główny rynek monetyzacji |
| portugalski (BR) | `pt-BR` | `pt-BR` | tani CPI, duży wolumen; tłumacz natywnie, nie dosłownie |
| filipiński | `fil` | brak osobnego (użyj `en-US`) | soft launch testowy; ZWERYFIKUJ kod w Play Console |
| niemiecki | `de-DE` | `de-DE` | wysokie ARPDAU; wymaga poprawnych form grzecznościowych |
Tłumaczenie: najpierw tytuł+short+keywords, potem opis. Keywordy pisz od nowa per język (nie tłumacz 1:1) i sprawdź autocomplete tego kraju. `asset-worker` robi tłumaczenia mechaniczne wg listy od orkiestratora.

## 6. A/B listingu
- Google Play: **Store listing experiments** (Play Console → Grow → Store listing experiments): testuj ikonę, feature graphic, screenshoty, short/full description; min. 7 dni i kilkaset instalacji na wariant; mierz „first-time installers" (KPI: Store conversion kill-line 15 %, cel 25 %). ZWERYFIKUJ aktualne limity w konsoli.
- App Store: **Product Page Optimization** (do 3 wariantów, ikona + screenshoty + app preview; nie testuje tytułu/opisu); także Custom Product Pages pod kampanie.
- Jeden test = jedna zmiana (wynik do `docs/EXPERIMENTS.md`).

## 7. Aktualizacja `fastlane/metadata`
Struktura (fastlane `supply`/`deliver`): `fastlane/metadata/android/<locale>/{title.txt,short_description.txt,full_description.txt,changelogs/<version_code>.txt,images/}` oraz `fastlane/metadata/ios/<locale>/{name.txt,subtitle.txt,keywords.txt,description.txt,promotional_text.txt,release_notes.txt,privacy_url.txt}`. Aktualnie istnieją locale `en-US` i `pl-PL` dla Androida z tekstem `TBD by aso skill` - lane `android upload` pomija metadata, dopóki tekst „TBD" jest obecny (`metadata_ready?`).
Procedura: (1) wartości z `docs/ASO.md` → pliki; (2) sprawdź długości: `wc -m plik` (znaki) i `wc -c` (bajty dla keywords); (3) usuń „TBD by aso skill"; (4) każdy plik kończy się nową linią, bez końcowych spacji; (5) PR z opisem zmian i tabelą długości. Plików `Fastfile`/`Appfile` nie ruszaj (zablokowane).
