#!/usr/bin/env python3
"""Phase 4 sounds for Silent Rescue: Dhaka (synthesised, no recordings, no licences).

Run: python3 tools/generate_phase4_audio.py   (numpy only). Output: assets/audio/*.wav, 22.05 kHz mono.

  sfx_intel_signal.wav  the intel beacon: a gagged hostage knocks a heel on a concrete floor -
                        knock-knock ... knock (a dull body thump plus a short scuff), with a small
                        room tail. Any file named sfx_intel_signal(.mp3/.ogg/.wav) in the "sounds"
                        folder, or set in the Sounds tab, replaces it (per gender: _f / _m).
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def onepole_lp(x, fc):
    a = np.exp(-2.0 * np.pi * fc / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def knock(rng, strength=1.0):
    n = int(0.22 * RATE)
    t = np.arange(n) / RATE
    # heel on concrete through a sandal / shoe: a low thump that drops in pitch, a soft scuff on top
    f0 = 95.0 + 25.0 * rng.random()
    phase = 2 * np.pi * np.cumsum(f0 * (1.0 + 0.6 * np.exp(-t / 0.012))) / RATE
    body = np.sin(phase) * np.exp(-t / 0.045)
    body += 0.35 * np.sin(2.1 * phase) * np.exp(-t / 0.03)
    noise = rng.standard_normal(n)
    scuff = onepole_lp(noise, 2200.0) - onepole_lp(noise, 300.0)
    scuff *= np.exp(-t / 0.012) * 0.5
    x = (body + scuff) * strength
    # soft attack so it never clicks
    x[:40] *= np.linspace(0.0, 1.0, 40)
    return x


def room(x):
    out = x.copy()
    for d, g in ((0.031, 0.32), (0.047, 0.22), (0.071, 0.16), (0.103, 0.1), (0.139, 0.06)):
        k = int(d * RATE)
        out[k:] += g * x[:-k]
    return onepole_lp(out, 3500.0)


def write(name, x):
    x = x / max(1e-6, np.max(np.abs(x))) * 0.8
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("wrote", os.path.normpath(path), "%.2f s" % (len(x) / RATE))


def intel_signal():
    rng = np.random.default_rng(4401)
    total = np.zeros(int(1.25 * RATE))
    # knock-knock ... knock (a deliberate pattern, not footsteps)
    for at, s in ((0.02, 1.0), (0.21, 0.85), (0.62, 1.0)):
        k = knock(rng, s)
        i = int(at * RATE)
        total[i:i + len(k)] += k[: len(total) - i]
    return room(total)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("sfx_intel_signal", intel_signal())
