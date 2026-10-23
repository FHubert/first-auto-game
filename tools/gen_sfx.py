#!/usr/bin/env python3
"""Procedural SFX + ambient loop (own work, no licences). Deterministic (seeded).

Usage: python3 tools/gen_sfx.py [outdir]   (default: game/assets/audio)
Writes 8 mono 16-bit 44.1 kHz WAV SFX and ambient_loop.ogg (needs ffmpeg; else ambient_loop.wav).
"""
import math
import random
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

RATE = 44100
AMBIENT_RATE = 22050
AMBIENT_SECONDS = 30
PEAK_SFX = 0.8
TAU = 2 * math.pi


def tone(f0, f1, dur, vol=0.5, attack=0.005, decay_pow=3.0, harmonic=0.0, rate=RATE):
    """Sine with linear glissando f0->f1, fast attack and decaying envelope."""
    n = int(rate * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        phase += TAU * (f0 + (f1 - f0) * t) / rate
        a = min(1.0, (i / rate) / attack) if attack > 0 else 1.0
        s = math.sin(phase) + harmonic * math.sin(2 * phase)
        out.append(vol * a * (1.0 - t) ** decay_pow * s)
    return out


def pour(base, seed):
    """Bubbling: sine with fast random-ish frequency modulation within 180-420 Hz."""
    rng = random.Random(seed)
    n = int(RATE * 0.35)
    out, phase = [], 0.0
    lfo = [rng.uniform(0, TAU) for _ in range(3)]
    for i in range(n):
        t = i / n
        f = base + 90 * math.sin(TAU * 11 * t + lfo[0]) + 40 * math.sin(TAU * 23 * t + lfo[1])
        f = max(180.0, min(420.0, f))
        phase += TAU * f / RATE
        env = min(1.0, i / (0.02 * RATE)) * (1.0 - t) ** 1.5
        trem = 0.6 + 0.4 * math.sin(TAU * 17 * t + lfo[2])
        out.append(0.5 * env * trem * math.sin(phase) + 0.03 * env * rng.uniform(-1, 1))
    return out


def error():
    n = int(RATE * 0.25)
    out = []
    for i in range(n):
        t = i / n
        s = math.sin(TAU * 160 * i / RATE) * (0.7 + 0.3 * math.sin(TAU * 30 * i / RATE))
        s = math.tanh(2.0 * s) * 0.45
        out.append(s * min(1.0, i / (0.01 * RATE)) * (1.0 - t) ** 1.2)
    return out


def ambient(seed=1):
    """Pad (A minor triad) + slow pentatonic arpeggio; 50 ms fades make the loop click-free."""
    rng = random.Random(seed)
    n = AMBIENT_RATE * AMBIENT_SECONDS
    chord = [220.0, 261.63, 329.63]
    penta = [440.0, 523.25, 587.33, 659.25, 783.99]
    step = 2.5  # seconds per arpeggio note
    notes = [rng.choice(penta) for _ in range(int(AMBIENT_SECONDS / step))]
    out = []
    for i in range(n):
        t = i / AMBIENT_RATE
        pad = sum(math.sin(TAU * f * t) for f in chord) / 3.0 * (0.8 + 0.2 * math.sin(TAU * t / 10))
        k = int(t / step)
        lt = (t - k * step) / step
        arp = math.sin(TAU * notes[k] * t) * math.sin(math.pi * lt) ** 2 * 0.35
        out.append(0.6 * pad + arp)
    fade = int(0.05 * AMBIENT_RATE)
    for i in range(fade):
        g = i / fade
        out[i] *= g
        out[n - 1 - i] *= g
    return normalize(out, 10 ** (-6 / 20))


def normalize(samples, peak):
    m = max(abs(s) for s in samples) or 1.0
    return [s * peak / m for s in samples]


def write(path, samples, rate=RATE):
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)


def sfx_set():
    chime = [a + b for a, b in zip(tone(880, 880, 0.3, 0.5, decay_pow=2.0), tone(1760, 1760, 0.3, 0.2, decay_pow=3.0))]
    ding = tone(1200, 1200, 0.12, 0.4, decay_pow=2.0) + tone(1600, 1600, 0.18, 0.4, decay_pow=2.5)
    return {
        "pour_1": pour(260, 11),
        "pour_2": pour(300, 12),
        "pour_3": pour(350, 13),
        "tube_full": chime,
        "win": tone(523, 523, 0.12) + tone(659, 659, 0.12) + tone(784, 784, 0.26, decay_pow=2.0),
        "click": tone(900, 600, 0.06),
        "error": error(),
        "coins": ding,
    }


def main(outdir="."):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    for name, samples in sfx_set().items():
        write(out / f"{name}.wav", normalize(samples, PEAK_SFX) if max(abs(s) for s in samples) > PEAK_SFX else samples)
    wav = out / "ambient_loop.wav"
    write(wav, ambient(), AMBIENT_RATE)
    if shutil.which("ffmpeg"):
        ogg = out / "ambient_loop.ogg"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3", str(ogg)],
            check=True,
        )
        wav.unlink()
    else:
        print("WARNING: ffmpeg not found, leaving ambient_loop.wav", file=sys.stderr)


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    main(sys.argv[1] if len(sys.argv) > 1 else root / "game" / "assets" / "audio")
