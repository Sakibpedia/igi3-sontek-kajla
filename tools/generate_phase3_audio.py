"""Phase 3 sound set for Silent Rescue: Dhaka - every sound synthesised here (no recordings, no downloads).
Run: python3 tools/generate_phase3_audio.py   (numpy + scipy). Output: assets/audio/*.wav, 22.05 kHz mono.

Dhaka soundscape loops (traffic with bus / CNG / rickshaw horns and bells, crows, heavy rain on tin roofs),
explosives (grenade, Molotov, time bomb), movement (concrete steps, crawling, splashes, swim strokes,
landing, parachute), urban gunshot echo tails, helicopter, vending machine, MCQ chimes, handcuffs ...
and gendered human non-speech sounds for hostages and Alpha Team (breathing, nose breathing, sighs, gasps,
coughs, relief, drinking, lifting effort) made with a glottal pulse source through vowel formant filters:
women ~210 Hz voice with higher formants, men ~115 Hz.
"""
import os
import numpy as np
from scipy.signal import lfilter, butter, sosfilt
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(2026)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def noise(n):
    return rng.standard_normal(int(n))


def bp(x, lo, hi, order=2):
    sos = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype="band", output="sos")
    return sosfilt(sos, x)


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f / (SR / 2), 0.99), output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f / (SR / 2), btype="high", output="sos"), x)


def reson(x, f, bw):
    # two-pole resonator (formant)
    r = np.exp(-np.pi * bw / SR)
    th = 2 * np.pi * f / SR
    a = [1, -2 * r * np.cos(th), r * r]
    b = [1 - r]
    return lfilter(b, a, x)


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fade(x, a=0.005, r=0.05):
    n = len(x)
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na > 0:
        e[:na] = np.linspace(0, 1, na)
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, nr)
    return x * e


def loopify(x, fd=0.6):
    n = int(fd * SR)
    head, body = x[:n].copy(), x[n:].copy()
    w = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * (1 - w) + head * w
    return body


def save(name, x, peak=0.9):
    x = norm(np.nan_to_num(x), peak)
    d = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(d.tobytes())


def place(buf, snd, at, gain=1.0):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(snd))
    buf[i:j] += snd[: j - i] * gain


# --------------------------------------------------------------------------- voice source
VOWELS = {
    # F1, F2, F3 (male); women are scaled ~1.17
    "a": (730, 1090, 2440), "aa": (700, 1220, 2600), "o": (570, 840, 2410), "u": (300, 870, 2240),
    "e": (530, 1840, 2480), "h": (600, 1500, 2500), "m": (250, 1200, 2300),
}


def glottal(f0_curve, open_q=0.6):
    """Rosenberg-like glottal flow derivative from an f0 contour (Hz per sample)."""
    ph = np.cumsum(f0_curve / SR) % 1.0
    flow = np.where(ph < open_q, 0.5 - 0.5 * np.cos(np.pi * ph / open_q), np.cos(np.pi * (ph - open_q) / (2 * (1 - open_q))))
    flow = np.where(ph < open_q, flow, np.maximum(flow, 0))
    return np.diff(flow, prepend=0) * SR / 400.0


def vocal(dur, female, vowel="a", f0=None, f0_end=None, voiced=1.0, breath=0.3, jitter=0.012):
    """Short non-speech vocalisation: glottal pulses + aspiration through 3 formants."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = (205.0 if female else 112.0) if f0 is None else f0
    end = base * 0.82 if f0_end is None else f0_end
    f0c = np.linspace(base, end, n) * (1 + jitter * lp(noise(n), 18) * 3)
    src = glottal(f0c) * voiced
    asp = hp(noise(n), 400) * breath * 0.6
    ex = src + asp
    k = 1.17 if female else 1.0
    F = VOWELS[vowel]
    y = reson(ex, F[0] * k, 90) * 1.0 + reson(ex, F[1] * k, 120) * 0.55 + reson(ex, F[2] * k, 180) * 0.3
    # lip radiation + nasal-ish damping for low female / male balance
    y = hp(y, 90)
    return y


def env_ar(n, att, rel, shape=1.0):
    e = np.ones(n)
    na, nr = max(1, int(att * SR)), max(1, int(rel * SR))
    e[:na] = np.linspace(0, 1, na) ** shape
    e[-nr:] *= np.linspace(1, 0, nr) ** shape
    return e


# --------------------------------------------------------------------------- gendered human sounds
def breath_cycle(female, intensity=1.0, nose=False):
    """One inhale + exhale. Mouth: wider band; nose (taped mouth): narrow, higher, hissy, quieter."""
    k = 1.15 if female else 1.0
    inh_d = rng.uniform(0.7, 1.0) / intensity ** 0.3
    exh_d = rng.uniform(0.8, 1.2) / intensity ** 0.3
    gap = rng.uniform(0.05, 0.15)
    tot = inh_d + gap + exh_d + 0.2
    out = np.zeros(int(tot * SR))
    if nose:
        inh = bp(noise(inh_d * SR), 1800 * k, 5200 * k) * 0.5 + reson(noise(inh_d * SR), 2600 * k, 500) * 0.4
        exh = bp(noise(exh_d * SR), 1200 * k, 4200 * k) * 0.45 + reson(noise(exh_d * SR), 900 * k, 300) * 0.3
    else:
        inh = bp(noise(inh_d * SR), 700 * k, 3800 * k) + reson(noise(inh_d * SR), 1500 * k, 400) * 0.5
        exh = bp(noise(exh_d * SR), 400 * k, 2600 * k) + reson(noise(exh_d * SR), 750 * k, 250) * 0.6
    inh *= env_ar(len(inh), inh_d * 0.6, inh_d * 0.35, 1.5)
    exh *= env_ar(len(exh), exh_d * 0.15, exh_d * 0.7, 1.3)
    place(out, inh, 0.0, 0.6)
    place(out, exh, inh_d + gap, 0.75 * intensity)
    return out


def sigh(female):
    d = rng.uniform(1.1, 1.5)
    v = vocal(d, female, "aa", voiced=0.35, breath=1.0)
    n = len(v)
    e = env_ar(n, 0.08, d * 0.75, 1.4)
    pre = bp(noise(0.45 * SR), 800, 3500) * env_ar(int(0.45 * SR), 0.3, 0.12)
    out = np.zeros(n + len(pre))
    place(out, pre, 0, 0.35)
    place(out, v * e, 0.42, 1.0)
    return out


def gasp(female):
    d = 0.35
    inh = bp(noise(d * SR), 900, 4500) + vocal(d, female, "a", f0=(330 if female else 170), f0_end=(380 if female else 190), voiced=0.25, breath=0.8) * 0.6
    return inh * env_ar(len(inh), 0.04, 0.2, 1.2)


def cough(female):
    out = np.zeros(int(1.2 * SR))
    for i in range(rng.integers(1, 3)):
        d = 0.18
        burst = vocal(d, female, "h", f0=(240 if female else 130), voiced=0.5, breath=1.4) + bp(noise(d * SR), 300, 3000) * 0.8
        burst *= env_ar(len(burst), 0.005, 0.15, 2.0)
        place(out, burst, 0.05 + i * 0.32)
    return out


def relief(female):
    d = 1.0
    v = vocal(d, female, "aa", f0=(230 if female else 125), f0_end=(170 if female else 95), voiced=0.7, breath=0.6)
    return v * env_ar(len(v), 0.06, 0.7, 1.3)


def effort(female):
    """Lifting someone: braced short grunt, then a held, strained exhale while standing up."""
    out = np.zeros(int(1.3 * SR))
    g = vocal(0.22, female, "u", f0=(190 if female else 105), f0_end=(230 if female else 125), voiced=0.9, breath=0.5)
    g *= env_ar(len(g), 0.01, 0.1, 1.5)
    h = vocal(0.75, female, "a", f0=(215 if female else 118), f0_end=(185 if female else 100), voiced=0.45, breath=0.9, jitter=0.03)
    h *= env_ar(len(h), 0.05, 0.4, 1.2)
    place(out, g, 0.0, 1.0)
    place(out, h, 0.25, 0.8)
    return out


def drink(female):
    out = np.zeros(int(2.4 * SR))
    for i in range(4):
        gulp = vocal(0.12, female, "u", f0=(170 if female else 95), voiced=0.6, breath=0.2) + reson(noise(0.12 * SR), 350, 120) * 0.4
        gulp *= env_ar(len(gulp), 0.01, 0.08, 1.5)
        place(out, gulp, 0.15 + i * 0.45 + rng.uniform(-0.04, 0.04))
    exh = bp(noise(0.5 * SR), 500, 2500) * env_ar(int(0.5 * SR), 0.05, 0.35)
    place(out, exh, 1.9, 0.6)
    return out


def shift_cloth():
    d = 0.6
    x = bp(noise(d * SR), 1500, 7000) * (0.3 + 0.7 * np.abs(lp(noise(d * SR), 12)))
    return x * env_ar(len(x), 0.05, 0.3)


# --------------------------------------------------------------------------- Dhaka soundscape
def horn(kind):
    if kind == "bus":  # two-tone air / electric horn
        d = rng.uniform(0.5, 1.2)
        t = t_axis(d)
        x = np.sign(np.sin(2 * np.pi * 330 * t)) * 0.5 + np.sign(np.sin(2 * np.pi * 415 * t)) * 0.5
        x = bp(x, 250, 2500)
    elif kind == "cng":  # thin high bulb horn of auto-rickshaws
        d = rng.uniform(0.15, 0.3)
        t = t_axis(d)
        x = bp(np.sign(np.sin(2 * np.pi * 620 * t)), 400, 3000)
    elif kind == "car":
        d = rng.uniform(0.2, 0.6)
        t = t_axis(d)
        x = bp(np.sign(np.sin(2 * np.pi * 440 * t)) + 0.6 * np.sign(np.sin(2 * np.pi * 550 * t)), 300, 2800)
    else:  # bicycle-rickshaw bell: ring-ring
        d = 0.7
        t = t_axis(d)
        x = np.zeros(len(t))
        for k in range(2):
            tt = t - k * 0.18
            m = tt >= 0
            x[m] += (np.sin(2 * np.pi * 2400 * tt[m]) + 0.6 * np.sin(2 * np.pi * 3550 * tt[m]) + 0.3 * np.sin(2 * np.pi * 5200 * tt[m])) * np.exp(-tt[m] / 0.12)
    return x * env_ar(len(x), 0.01, 0.06)


def traffic(sec=24.0):
    n = int(sec * SR)
    t = np.arange(n) / SR
    rumble = lp(noise(n), 180, 4) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.07 * t))
    engines = np.zeros(n)
    for _ in range(9):  # passing vehicles: filtered noise with a swell
        c = rng.uniform(0, sec)
        w = rng.uniform(2.5, 5.0)
        sw = np.exp(-((t - c) / (w * 0.5)) ** 2)
        f = rng.uniform(70, 160)
        eng = bp(noise(n), f, f * 6) * sw
        engines += eng * rng.uniform(0.3, 0.7)
    murmur = bp(noise(n), 250, 1600) * 0.08 * (0.6 + 0.4 * np.abs(lp(noise(n), 0.5)))
    out = rumble * 0.9 + engines * 0.6 + murmur
    for _ in range(int(sec * 0.9)):
        k = rng.choice(["bus", "cng", "car", "bell", "bell", "cng"])
        place(out, horn(k) * rng.uniform(0.08, 0.3), rng.uniform(0, sec - 1.3))
    return loopify(out, 1.0)


def crow_caw():
    d = rng.uniform(0.25, 0.4)
    n = int(d * SR)
    f0 = np.linspace(rng.uniform(520, 640), rng.uniform(430, 500), n)
    src = glottal(f0, 0.5) + hp(noise(n), 800) * 0.5
    y = reson(src, 1100, 300) + reson(src, 1700, 400) * 0.6 + reson(src, 2600, 500) * 0.3
    return y * env_ar(n, 0.02, d * 0.5, 1.2)


def crows(sec=20.0):
    out = bp(noise(sec * SR), 2000, 6000) * 0.01
    tt = 0.5
    while tt < sec - 2:
        for i in range(rng.integers(2, 4)):
            place(out, crow_caw() * rng.uniform(0.3, 0.8), tt + i * 0.42)
        tt += rng.uniform(2.0, 4.5)
    # small birds
    for _ in range(25):
        d = 0.08
        t = t_axis(d)
        f = rng.uniform(3500, 5500)
        ch = np.sin(2 * np.pi * (f * t + 8000 * t * t)) * env_ar(len(t), 0.005, 0.05)
        place(out, ch * 0.1, rng.uniform(0, sec - 0.2))
    return loopify(out, 0.8)


def rain_tin(sec=16.0):
    n = int(sec * SR)
    out = bp(noise(n), 400, 7000) * 0.25
    # drops on tin roofs: tiny pings
    for _ in range(int(sec * 140)):
        d = 0.03
        t = t_axis(d)
        f = rng.uniform(1800, 4200)
        p = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.008)
        place(out, p * rng.uniform(0.02, 0.09), rng.uniform(0, sec - 0.05))
    # gutters / drips
    out += lp(noise(n), 500) * 0.15
    return loopify(out, 0.8)


def thunder():
    d = 5.0
    n = int(d * SR)
    t = np.arange(n) / SR
    crack = hp(noise(n), 300) * np.exp(-t / 0.15) * 0.6
    roll = lp(noise(n), 160, 4) * (np.exp(-t / 1.8) * (0.6 + 0.4 * np.abs(lp(noise(n), 3))))
    return (crack + roll * 2.0) * env_ar(n, 0.01, 1.5)


def heli_loop(sec=4.0):
    n = int(sec * SR)
    t = np.arange(n) / SR
    rate = 5.75 * 2  # two-blade rotor, ~345 rpm main rotor slap
    slap = np.zeros(n)
    for k in np.arange(0, sec, 1 / rate):
        d = 0.06
        th = lp(noise(d * SR), 400) * np.exp(-np.arange(int(d * SR)) / SR / 0.02)
        place(slap, th, k)
    turb = bp(noise(n), 2500, 6000) * 0.1 + np.sin(2 * np.pi * 1450 * t) * 0.03
    body = lp(noise(n), 120) * 0.5
    return loopify(slap * 1.5 + turb + body, 0.3)


def plane_pass():
    d = 7.0
    n = int(d * SR)
    t = np.arange(n) / SR
    sw = np.exp(-((t - 3.5) / 1.8) ** 2)
    f = 95 * (1 + 0.15 * np.tanh((3.5 - t) * 0.9))  # doppler drop
    ph = np.cumsum(f / SR)
    prop = (np.sign(np.sin(2 * np.pi * ph)) * 0.3 + np.sin(2 * np.pi * ph * 2) * 0.3)
    x = lp(prop, 900) + bp(noise(n), 200, 2500) * 0.6
    return x * sw


# --------------------------------------------------------------------------- explosives, movement, misc
def explosion_tail():
    d = 2.2
    n = int(d * SR)
    t = np.arange(n) / SR
    echo = np.zeros(n)
    for k, g in [(0.18, 0.5), (0.37, 0.35), (0.62, 0.25), (0.95, 0.15)]:
        place(echo, lp(noise(0.5 * SR), 600) * np.exp(-np.arange(int(0.5 * SR)) / SR / 0.15), k, g)
    return echo * env_ar(n, 0.01, 1.0)


def gun_tail(room=False):
    d = 1.6 if not room else 0.7
    n = int(d * SR)
    out = np.zeros(n)
    taps = [(0.09, 0.45), (0.21, 0.33), (0.34, 0.25), (0.52, 0.18), (0.8, 0.1)] if not room else [(0.012, 0.6), (0.025, 0.5), (0.04, 0.42), (0.06, 0.3)]
    for k, g in taps:
        b = bp(noise(0.25 * SR), 200, 2500 if not room else 4000) * np.exp(-np.arange(int(0.25 * SR)) / SR / (0.05 if not room else 0.03))
        place(out, b, k, g)
    if room:
        out += bp(noise(n), 300, 3000) * np.exp(-np.arange(n) / SR / 0.18) * 0.25
    return out * env_ar(n, 0.002, d * 0.6)


def click(f, d=0.02, decay=0.004):
    t = t_axis(d)
    return (np.sin(2 * np.pi * f * t) + hp(noise(len(t)), 2000) * 0.5) * np.exp(-t / decay)


def step_concrete(i):
    d = 0.16
    n = int(d * SR)
    heel = lp(noise(n), 900 + i * 120) * np.exp(-np.arange(n) / SR / 0.018)
    grit = bp(noise(n), 2500, 7000) * np.exp(-np.arange(n) / SR / 0.03) * 0.25
    toe = np.zeros(n)
    place(toe, lp(noise(0.05 * SR), 1200) * np.exp(-np.arange(int(0.05 * SR)) / SR / 0.01), 0.05, 0.5)
    return heel + grit + toe


def crawl():
    d = 0.7
    x = bp(noise(d * SR), 600, 5000) * (0.3 + np.abs(lp(noise(d * SR), 8)))
    x += lp(noise(d * SR), 300) * 0.3
    return x * env_ar(len(x), 0.05, 0.3)


def splash(big=True):
    d = 1.2 if big else 0.5
    n = int(d * SR)
    t = np.arange(n) / SR
    x = bp(noise(n), 300, 6000) * np.exp(-t / (0.25 if big else 0.1))
    for _ in range(30 if big else 10):
        bd = 0.04
        bt = t_axis(bd)
        f = rng.uniform(600, 1800)
        bub = np.sin(2 * np.pi * f * bt * (1 + 2 * bt)) * np.exp(-bt / 0.012)
        place(x, bub * 0.3, rng.uniform(0.02, d * 0.7))
    return x


def stroke():
    d = 0.7
    n = int(d * SR)
    t = np.arange(n) / SR
    sw = bp(noise(n), 250, 2500) * np.exp(-((t - 0.25) / 0.12) ** 2)
    sp = np.zeros(n)
    place(sp, splash(False), 0.0, 0.3)
    return sp + sw


def parachute_open():
    d = 1.6
    n = int(d * SR)
    t = np.arange(n) / SR
    snap = lp(noise(n), 900) * np.exp(-t / 0.06) * 1.2
    flutter = bp(noise(n), 150, 1500) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * t))) * np.exp(-t / 0.6) * 0.5
    return snap + flutter


def land():
    d = 0.5
    n = int(d * SR)
    t = np.arange(n) / SR
    return lp(noise(n), 400) * np.exp(-t / 0.06) + bp(noise(n), 1000, 5000) * np.exp(-t / 0.15) * 0.3


def glass_break():
    d = 1.0
    n = int(d * SR)
    t = np.arange(n) / SR
    x = hp(noise(n), 2500) * np.exp(-t / 0.08) * 0.6
    for _ in range(40):
        sd = 0.05
        st = t_axis(sd)
        f = rng.uniform(3000, 8000)
        place(x, np.sin(2 * np.pi * f * st) * np.exp(-st / 0.01) * 0.25, rng.uniform(0.0, 0.6))
    return x


def fire_whoosh():
    d = 1.6
    n = int(d * SR)
    t = np.arange(n) / SR
    cut = 200 + 2500 * np.exp(-t / 0.3)
    x = np.zeros(n)
    base = noise(n)
    for i in range(0, n, 512):
        seg = base[i:i + 512]
        x[i:i + 512] = lp(seg, cut[i])[:len(seg)]
    return x * env_ar(n, 0.08, 1.0)


def fire_loop(sec=9.5):
    n = int(sec * SR)
    roar = lp(noise(n), 350) * 0.5
    out = roar
    for _ in range(int(sec * 35)):
        d = 0.012
        place(out, hp(noise(d * SR), 1500) * rng.uniform(0.1, 0.5), rng.uniform(0, sec - 0.02))
    return out * env_ar(n, 0.3, 1.5)


def beep(f=2600, d=0.09):
    t = t_axis(d)
    return np.sin(2 * np.pi * f * t) * env_ar(len(t), 0.003, 0.02)


def chime(right=True):
    if right:
        out = np.zeros(int(0.8 * SR))
        for i, f in enumerate([880, 1318.5]):
            t = t_axis(0.5)
            place(out, (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)) * np.exp(-t / 0.25), i * 0.13)
        return out
    t = t_axis(0.5)
    return (np.sign(np.sin(2 * np.pi * 140 * t)) * 0.5 + np.sin(2 * np.pi * 147 * t)) * env_ar(len(t), 0.01, 0.1)


def handcuff():
    out = np.zeros(int(0.9 * SR))
    for i in range(7):
        place(out, click(rng.uniform(3200, 4200), 0.03, 0.003), 0.05 + i * 0.045, 0.7)
    place(out, click(1800, 0.06, 0.01), 0.45, 1.0)
    for i in range(5):
        place(out, click(rng.uniform(3000, 4000), 0.03, 0.003), 0.55 + i * 0.045, 0.6)
    return out


def vend():
    d = 2.2
    n = int(d * SR)
    t = np.arange(n) / SR
    motor = (np.sin(2 * np.pi * 120 * t) * 0.3 + bp(noise(n), 300, 1200) * 0.2) * (t < 1.4)
    out = motor * env_ar(n, 0.05, 0.3)
    place(out, lp(noise(0.3 * SR), 300) * np.exp(-np.arange(int(0.3 * SR)) / SR / 0.05) * 1.5, 1.5)
    return out


def coin():
    t = t_axis(0.4)
    return (np.sin(2 * np.pi * 4200 * t) + 0.5 * np.sin(2 * np.pi * 6100 * t)) * np.exp(-t / 0.08)


def pump_squeak():
    d = 0.8
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 900 + 500 * np.sin(np.pi * t / d)
    sq = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * np.abs(lp(noise(n), 30)))
    gush = bp(noise(n), 300, 3000) * np.clip((t - 0.35) * 4, 0, 1) * 0.6
    clank = np.zeros(n)
    place(clank, click(700, 0.08, 0.02), 0.0, 1.0)
    return sq * 0.4 + gush + clank


def door():
    d = 1.0
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 300 + 250 * t
    creak = np.sin(2 * np.pi * np.cumsum(f) / SR) * (np.abs(lp(noise(n), 25)) * 2) * 0.3
    out = creak * env_ar(n, 0.05, 0.3)
    place(out, lp(noise(0.2 * SR), 300) * np.exp(-np.arange(int(0.2 * SR)) / SR / 0.03), 0.8, 1.2)
    return out


def chair():
    d = 0.6
    n = int(d * SR)
    f = 180 + 60 * np.sin(np.arange(n) / SR * 9)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.abs(lp(noise(n), 30)) * 2
    return x * env_ar(n, 0.05, 0.2)


def radio():
    t = t_axis(0.35)
    return bp(noise(len(t)), 800, 3000) * 0.4 + np.sin(2 * np.pi * 1600 * t) * (t < 0.08) * 0.6


def shout(female, vowels=("e", "a"), dur=0.55):
    """Loud call ("Ey!", "Oi!") - two vowels glided together, high strained pitch."""
    n1 = int(dur * 0.35 * SR)
    n2 = int(dur * 0.65 * SR)
    f0a = 300 if female else 175
    a = vocal(n1 / SR, female, vowels[0], f0=f0a, f0_end=f0a * 1.08, voiced=1.0, breath=0.35, jitter=0.02)
    b = vocal(n2 / SR, female, vowels[1], f0=f0a * 1.08, f0_end=f0a * 0.82, voiced=1.0, breath=0.4, jitter=0.02)
    x = np.concatenate([a * env_ar(len(a), 0.02, 0.02), b * env_ar(len(b), 0.02, 0.25)])
    return np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 2.2)


def metal_slide(d=0.12, f0=1800, f1=900):
    t = t_axis(d)
    f = np.linspace(f0, f1, len(t))
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.3 + hp(noise(len(t)), 2000) * 0.5) * env_ar(len(t), 0.005, d * 0.6)


def sirens(sec=30.0):
    """Distant police / ambulance sirens drifting through the city, mostly far away and muffled."""
    n = int(sec * SR)
    out = np.zeros(n)
    for start, dur, kind in ((2.0, 9.0, "wail"), (16.0, 8.0, "yelp")):
        t = t_axis(dur)
        if kind == "wail":
            f = 720 + 330 * np.sin(2 * np.pi * t / 4.5)
        else:
            f = 900 + 400 * np.abs(np.sin(2 * np.pi * t * 3.2))
        ph = np.cumsum(f * (1 + 0.004 * np.sin(2 * np.pi * 0.3 * t))) / SR
        x = np.sin(2 * np.pi * ph) + 0.35 * np.sin(4 * np.pi * ph)
        x = lp(x, 1400) * env_ar(len(x), 2.0, 2.5, 1.5)
        place(out, x * 0.25, start)
    out += lp(noise(n), 200) * 0.02
    return loopify(out, 1.0)


def chatter(sec=20.0):
    """Crowd chatter: many overlapping voiced syllables of men and women, unintelligible."""
    n = int(sec * SR)
    out = bp(noise(n), 300, 2500) * 0.03
    vowels = list(VOWELS.keys())
    for _ in range(int(sec * 9)):
        fem = rng.random() < 0.5
        d = rng.uniform(0.12, 0.35)
        v = vocal(d, fem, vowels[rng.integers(0, 5)], f0=(rng.uniform(180, 260) if fem else rng.uniform(95, 150)), voiced=0.8, breath=0.4)
        v *= env_ar(len(v), 0.03, d * 0.5, 1.3)
        place(out, lp(v, 2200) * rng.uniform(0.05, 0.2), rng.uniform(0, sec - 0.4))
    return loopify(out, 1.0)


# --------------------------------------------------------------------------- write everything
def main():
    for g, fem in (("f", True), ("m", False)):
        for i in range(1, 4):
            save("sfx_breath_%s%d" % (g, i), breath_cycle(fem, rng.uniform(0.8, 1.3)), 0.6)
            save("sfx_breath_nose_%s%d" % (g, i), breath_cycle(fem, rng.uniform(0.7, 1.0), nose=True), 0.45)
        save("sfx_sigh_" + g, sigh(fem), 0.7)
        save("sfx_gasp_" + g, gasp(fem), 0.7)
        save("sfx_cough_" + g, cough(fem), 0.7)
        save("sfx_relief_" + g, relief(fem), 0.7)
        save("sfx_effort_" + g, effort(fem), 0.75)
        save("sfx_drink_" + g, drink(fem), 0.7)
    save("sfx_shift", shift_cloth(), 0.5)
    save("amb_dhaka_traffic", traffic(), 0.8)
    save("amb_crows", crows(), 0.7)
    save("amb_rain_tin", rain_tin(), 0.7)
    save("sfx_thunder", thunder(), 0.95)
    save("amb_heli", heli_loop(), 0.9)
    save("sfx_plane_pass", plane_pass(), 0.9)
    save("sfx_explosion_tail", explosion_tail(), 0.6)
    save("sfx_tail_city", gun_tail(False), 0.6)
    save("sfx_tail_room", gun_tail(True), 0.6)
    for i in range(1, 5):
        save("sfx_step_c%d" % i, step_concrete(i), 0.7)
    save("sfx_crawl", crawl(), 0.6)
    save("sfx_splash", splash(True), 0.85)
    save("sfx_swim_stroke", stroke(), 0.6)
    save("sfx_parachute_open", parachute_open(), 0.9)
    save("sfx_land", land(), 0.8)
    save("sfx_glass_break", glass_break(), 0.8)
    save("sfx_fire_whoosh", fire_whoosh(), 0.85)
    save("sfx_fire_loop", fire_loop(), 0.7)
    save("sfx_bomb_beep", beep(), 0.6)
    save("sfx_bomb_arm", np.concatenate([beep(1800, 0.1), np.zeros(800), beep(2600, 0.1), np.zeros(800), beep(3400, 0.14)]), 0.7)
    save("sfx_pin", np.concatenate([click(3800, 0.03, 0.004), np.zeros(1500), click(2400, 0.05, 0.01)]), 0.7)
    save("sfx_lighter", np.concatenate([click(5000, 0.02, 0.003), fire_whoosh()[: int(0.4 * SR)] * 0.4]), 0.6)
    save("sfx_throw", bp(noise(0.3 * SR), 300, 2500) * env_ar(int(0.3 * SR), 0.1, 0.15), 0.6)
    save("sfx_grenade_bounce", click(900, 0.08, 0.02) + click(2200, 0.08, 0.008) * 0.5, 0.6)
    save("sfx_mcq_right", chime(True), 0.7)
    save("sfx_mcq_wrong", chime(False), 0.6)
    save("sfx_handcuff", handcuff(), 0.75)
    save("sfx_vend", vend(), 0.7)
    save("sfx_coin", coin(), 0.6)
    save("sfx_pump", pump_squeak(), 0.7)
    save("sfx_door", door(), 0.7)
    save("sfx_chair", chair(), 0.5)
    save("sfx_radio", radio(), 0.6)
    save("amb_sirens", sirens(), 0.55)
    save("amb_chatter", chatter(), 0.6)
    save("sfx_shout_m1", shout(False, ("e", "a")), 0.95)
    save("sfx_shout_m2", shout(False, ("o", "e"), 0.7), 0.95)
    save("sfx_shout_f1", shout(True, ("e", "a")), 0.95)
    save("sfx_shout_f2", shout(True, ("o", "e"), 0.7), 0.95)
    save("sfx_mag_out", np.concatenate([click(2600, 0.03, 0.004), metal_slide(0.1, 1500, 700)]), 0.7)
    save("sfx_mag_in", np.concatenate([metal_slide(0.08, 700, 1300), click(1900, 0.05, 0.008), click(3200, 0.03, 0.004) * 0.6]), 0.8)
    save("sfx_bolt", np.concatenate([metal_slide(0.09, 1200, 2200), np.zeros(int(0.05 * SR)), click(1500, 0.06, 0.01), metal_slide(0.07, 2400, 1600) * 0.8]), 0.85)
    save("sfx_headphones", np.concatenate([click(1200, 0.03, 0.006), np.zeros(600), beep(1400, 0.06)]), 0.5)
    print("phase 3 audio written to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
