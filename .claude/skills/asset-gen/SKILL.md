---
name: asset-gen
description: Uzyj przy tworzeniu lub dodawaniu grafiki, ikon, dzwiekow i fontow - generator tools/gen_assets.py, paleta, rozmiary ikon sklepowych, audio proceduralne, zasady licencji CC0/OFL i wpisy w LICENSES.md.
---

# asset-gen — grafika, dźwięk, fonty

## 1. Zasady nadrzędne
- Tylko: (a) assety WŁASNE generowane skryptami, (b) CC0 z listy poniżej, (c) fonty na licencji **OFL** (Google Fonts). Każdy obcy asset → wiersz w `docs/LICENSES.md` ZANIM trafi do repo (kolumny: asset | źródło (URL) | licencja | autor | plik w repo; własne: źródło „własny").
- Zakazane: asset z nieznaną/niepewną licencją, CC-BY-NC / CC-BY-SA / „free for personal use", cokolwiek z gier/filmów, **znane postacie i marki**, loga, rozpoznawalne style „jak X". Brak pewności = nie dodawaj.
- Styl: **flat / geometric** - proste kształty (koło, kwadrat, trójkąt, gwiazda), jednolite wypełnienia, gradient tylko tła, bez tekstur i obrysów fotorealistycznych. Spójna paleta.
- Paleta: `tools/palette.json` (`colors` ×6, `background`, `background_alt`, `accent`). Kolory w kodzie i SVG TYLKO z tej palety; zmiana palety = zmiana pliku i regeneracja wszystkiego.

## 2. `tools/gen_assets.py`
Deterministyczny generator (stdlib; PNG wymaga `pip install cairosvg`). Ten sam input = identyczny SVG.
```
python3 tools/gen_assets.py [--out DIR] [--initial F] [--palette tools/palette.json]
```
Domyślne wyjście: `game/assets/sprites/`. Generuje: `icon_1024.*` (ikona aplikacji 1024², kształt + inicjał `--initial`), `feature_graphic_1024x500.*` (Play), `shape_circle|square|triangle|star.*` (256², sprite'y), `background_720x1280.*` (gradient pionowy). Po zmianie palety: uruchom ponownie, zcommituj SVG (i PNG, jeśli generowane) razem z kodem, który ich używa.
Nowy typ assetu → dopisz funkcję w `gen_assets.py` (mała, deterministyczna) zamiast rysować ręcznie.

## 3. Organizacja plików
| Rodzaj | Ścieżka | Uwagi |
|---|---|---|
| SVG źródłowe | `game/assets/sprites/src/*.svg` | źródło prawdy; edytowalne tekstowo |
| PNG eksportowane | `game/assets/sprites/*.png` | z SVG: `cairosvg src/x.svg -o x.png -W 256 -H 256`; Godot importuje PNG (powstaje `.import` - commituj) |
| Audio | `game/assets/audio/*.wav` / `.ogg` | efekty WAV 16-bit 44.1 kHz mono, muzyka OGG |
| Fonty | `game/assets/fonts/*.ttf` | tylko OFL + wiersz w LICENSES.md |
Sprite'y UI: kwadratowe potęgi dwójki tam gdzie się da (64/128/256), z marginesem 8 px; tła pełnoekranowe 720×1280 (`display` projektu). Po dodaniu pliku uruchom `make test` (Godot wygeneruje `.import`/`.uid`).

## 4. Rozmiary sklepowe
| Zasób | Wymagania |
|---|---|
| Google Play: ikona sklepu | **512×512, 32-bit PNG (z alfą)**, max 1024 KB |
| Google Play: feature graphic | **1024×500**, JPEG lub 24-bit PNG **bez alfy** |
| Google Play: screenshoty | do 8 na typ urządzenia, proporcje 9:16 / 16:9 (szczegóły: skill `aso`) |
| iOS: ikona App Store | **1024×1024 PNG, BEZ kanału alfa**, bez zaokrągleń |
| iOS: screenshoty | brak alfy; np. 1320×2868 (6.9"); iPad 2064×2752 |
| Android launcher (preset) | main 192×192; adaptive foreground/background 432×432 (krytyczne elementy w kółku Ø 264 px), monochrome 432×432 opcjonalnie |
Ikona: **bez tekstu** (poza ewentualnie pojedynczą literą-znakiem), jedna prosta forma, wysoki kontrast, czytelna w 48 px. Usuwanie alfy dla iOS: `python3 -c "from PIL import Image; im=Image.open('icon.png').convert('RGB'); im.save('icon_ios.png')"` (wymaga Pillow) albo wyrenderuj SVG z pełnym tłem.
Źródło wymiarów Play: support.google.com/googleplay/android-developer/answer/9866151; Godot launcher icons: docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html.

## 5. Audio
**Opcja A - proceduralnie (własne, bez licencji).** Zapisz jako `tools/gen_sfx.py` (nowy plik = zadanie z backlogu) i uruchom `python3 tools/gen_sfx.py game/assets/audio`:
```python
import math, struct, sys, wave
RATE = 44100

def tone(f0, f1, dur, vol=0.5, attack=0.005, decay_pow=3.0):
    """Sinus z liniowym glissando f0->f1 i obwiednią: szybki attack + malejący decay."""
    n = int(RATE * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * (f0 + (f1 - f0) * t) / RATE
        a = min(1.0, (i / RATE) / attack) if attack > 0 else 1.0
        out.append(vol * a * (1.0 - t) ** decay_pow * math.sin(phase))
    return out

def write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))

def main(outdir):
    write(f"{outdir}/click.wav", tone(900, 600, 0.06))
    write(f"{outdir}/win.wav", tone(523, 523, 0.12) + tone(659, 659, 0.12) + tone(784, 784, 0.25, decay_pow=2.0))  # C-E-G
    write(f"{outdir}/lose.wav", tone(400, 200, 0.35, decay_pow=1.5))

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
```
Wynik: click ≈ 0,06 s, win ≈ 0,49 s, lose ≈ 0,35 s (sprawdzone). Wpis w LICENSES.md: „własny", źródło `tools/gen_sfx.py`.
**Opcja B - CC0.** Dozwolone źródła: **Kenney.nl** (całość CC0: kenney.nl/assets), **freesound.org** (TYLKO filtr licencji „Creative Commons 0"; sprawdź licencję na stronie KAŻDEGO pliku, nie pakietu), **OpenGameArt.org** (tylko wpisy z licencją CC0), **itch.io** (tylko paczki jawnie CC0). Przy każdym pliku zapisz URL strony źródłowej i autora w `docs/LICENSES.md`. CC-BY dozwolone wyjątkowo (atrybucja na ekranie Credits) - preferuj CC0.
Muzyka: krótka pętla OGG (<1 MB), głośność znormalizowana, wyciszana przy `set_app_muted` reklam.

## 6. Fonty
Tylko **SIL OFL** z Google Fonts (fonts.google.com, filtr licencji „Open Font License"). Pobierz `.ttf`, dodaj do `game/assets/fonts/`, wpisz do LICENSES.md (nazwa, URL, „OFL 1.1", autor z pliku OFL.txt) i zachowaj plik `OFL.txt` obok fontu. Sprawdź obsługę polskich znaków (ąćęłńóśźż) i znaków, których użyje UI. Nie osadzaj fontów systemowych ani z nieznanych paczek.

## 7. Checklist
- [ ] Kolory tylko z `palette.json`; styl flat/geometric.
- [ ] Brak znanych postaci/marek/logo; brak tekstu w ikonie.
- [ ] Ikona iOS bez alfa; feature graphic 1024×500; ikona Play 512 PNG 32-bit.
- [ ] Każdy obcy asset/font ma wiersz w `docs/LICENSES.md`; licencja CC0/OFL potwierdzona na stronie źródłowej.
- [ ] Pliki `.import`/`.uid` dołączone; `make test` zielone; rozmiar paczki rozsądny (PNG zoptymalizowane, audio mono).
