"""Procedurally synthesises every sound effect and music loop used by the game.
Run: python3 tools/generate_audio.py   (needs numpy). Output: assets/audio/*.wav (22.05 kHz mono 16-bit)."""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1971)

def t_axis(sec): return np.arange(int(sec * SR)) / SR
def noise(sec): return rng.uniform(-1, 1, int(sec * SR))
def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR); y = np.zeros_like(x); acc = 0.0
    b = 1 - a
    for i in range(len(x)):
        acc = b * x[i] + a * acc; y[i] = acc
    return y
def lp_fast(x, cutoff, passes=1):
    # FFT brick-ish low pass (fast for long buffers)
    for _ in range(passes):
        X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
        X *= 1 / (1 + (f / cutoff) ** 4); x = np.fft.irfft(X, len(x))
    return x
def hp_fast(x, cutoff):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= (f / cutoff) ** 4 / (1 + (f / cutoff) ** 4); return np.fft.irfft(X, len(x))
def bp_fast(x, lo, hi): return hp_fast(lp_fast(x, hi), lo)
def env_exp(sec, decay, attack=0.002):
    t = t_axis(sec); e = np.exp(-t / decay); a = np.clip(t / attack, 0, 1); return e * a
def norm(x, peak=0.9):
    m = np.max(np.abs(x)); return x * (peak / m) if m > 0 else x
def loopify(x, fade=0.5):
    n = int(fade * SR); head = x[:n].copy(); body = x[n:].copy()
    w = np.linspace(0, 1, n); body[-n:] = body[-n:] * (1 - w) + head * w; return body
def save(name, x, peak=0.9):
    x = norm(x, peak); d = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())

def gunshot(sec, crack_decay, body_freq, body_decay, tail_decay, tone=0.0):
    n = noise(sec)
    crack = hp_fast(n, 1800) * env_exp(sec, crack_decay)
    body = lp_fast(noise(sec), body_freq) * env_exp(sec, body_decay) * 2.5
    thump = np.sin(2 * np.pi * (60 + 50 * np.exp(-t_axis(sec) / 0.02)) * t_axis(sec)) * env_exp(sec, body_decay * 1.2) * 0.8
    tail = lp_fast(noise(sec), 900) * env_exp(sec, tail_decay, 0.03) * 0.5
    ring = np.sin(2 * np.pi * 2300 * t_axis(sec)) * env_exp(sec, 0.03) * tone
    return crack + body + thump + tail + ring

save("sfx_rifle", gunshot(0.9, 0.012, 1400, 0.05, 0.35, 0.05))
save("sfx_type56", gunshot(0.9, 0.014, 1100, 0.06, 0.4, 0.03))
save("sfx_pistol", gunshot(0.6, 0.008, 2200, 0.03, 0.18, 0.08))
save("sfx_sniper", gunshot(1.6, 0.02, 900, 0.09, 0.8, 0.02))
save("sfx_far_shot", lp_fast(gunshot(1.2, 0.01, 700, 0.06, 0.5), 600), 0.6)

def click(sec, f, decay):
    return np.sin(2 * np.pi * f * t_axis(sec)) * env_exp(sec, decay) + hp_fast(noise(sec), 3000) * env_exp(sec, decay * 0.5)
reload = np.zeros(int(1.4 * SR))
for at, f, d in [(0.05, 900, 0.01), (0.12, 1300, 0.008), (0.75, 1100, 0.012), (0.82, 700, 0.02), (1.15, 1600, 0.01), (1.2, 2000, 0.006)]:
    c = click(0.15, f, d); i = int(at * SR); reload[i:i + len(c)] += c
save("sfx_reload", reload, 0.7)
save("sfx_empty", click(0.12, 2400, 0.006), 0.6)
sw = np.zeros(int(0.45 * SR))
for at, f in [(0.02, 600), (0.25, 1400)]:
    c = click(0.15, f, 0.015); i = int(at * SR); sw[i:i + len(c)] += c
save("sfx_switch", sw, 0.6)

def step(seed_shift, cutoff):
    s = lp_fast(noise(0.18), cutoff) * env_exp(0.18, 0.03, 0.004)
    s += hp_fast(noise(0.18), 2500) * env_exp(0.18, 0.01) * 0.15
    return s
save("sfx_step1", step(0, 500), 0.5)
save("sfx_step2", step(1, 650), 0.5)
save("sfx_step_wet", step(2, 900) + bp_fast(noise(0.18), 1500, 5000) * env_exp(0.18, 0.04) * 0.6, 0.5)
save("sfx_impact", hp_fast(noise(0.25), 700) * env_exp(0.25, 0.025) + lp_fast(noise(0.25), 400) * env_exp(0.25, 0.04), 0.6)
save("sfx_hit", lp_fast(noise(0.2), 350) * env_exp(0.2, 0.03, 0.003) * 2 + np.sin(2 * np.pi * 110 * t_axis(0.2)) * env_exp(0.2, 0.04), 0.7)
save("sfx_ricochet", np.sin(2 * np.pi * (3200 - 1800 * t_axis(0.35) / 0.35) * t_axis(0.35)) * env_exp(0.35, 0.12) * 0.6 + hp_fast(noise(0.35), 2000) * env_exp(0.35, 0.02), 0.5)

t = t_axis(0.5)
save("sfx_pickup", (np.sin(2 * np.pi * 880 * t) * (t < 0.12) + np.sin(2 * np.pi * 1320 * t) * (t >= 0.12)) * env_exp(0.5, 0.18), 0.5)
save("sfx_ui", np.sin(2 * np.pi * 1200 * t_axis(0.08)) * env_exp(0.08, 0.02), 0.4)
t = t_axis(2.0)
save("sfx_alarm", np.sign(np.sin(2 * np.pi * (650 + 250 * np.sin(2 * np.pi * 2 * t)) * t)) * 0.4 * np.clip(t / 0.05, 0, 1) * np.clip((2.0 - t) / 0.2, 0, 1), 0.45)
ex = lp_fast(noise(3.0), 220) * env_exp(3.0, 0.7, 0.005) * 3 + lp_fast(noise(3.0), 2500) * env_exp(3.0, 0.08) + np.sin(2 * np.pi * 45 * t_axis(3.0)) * env_exp(3.0, 0.4)
save("sfx_explosion", ex, 0.95)
th = lp_fast(noise(5.0), 160, 2) * (env_exp(5.0, 1.6, 0.3) + 0.5 * env_exp(5.0, 0.3, 0.01)) + lp_fast(noise(5.0), 1200) * env_exp(5.0, 0.15) * 0.3
save("sfx_thunder", th, 0.9)
t = t_axis(3.0)
horn = sum(np.sign(np.sin(2 * np.pi * f * t)) * a for f, a in [(98, 1), (147, 0.6), (196, 0.3)])
horn = lp_fast(horn, 700) * np.clip(t / 0.15, 0, 1) * np.clip((3.0 - t) / 0.4, 0, 1)
save("sfx_ship_horn", horn, 0.6)
t = t_axis(1.2)
bell = sum(np.sin(2 * np.pi * f * t) * a * np.exp(-t / d) for f, a, d in [(2450, 1, 0.25), (3920, 0.5, 0.15), (5300, 0.3, 0.08)])
bell2 = np.concatenate([bell[: int(0.12 * SR)], bell])[: len(bell)]
save("sfx_rickshaw_bell", bell + bell2 * 0.8, 0.5)
t = t_axis(0.7)
carhorn = lp_fast(np.sign(np.sin(2 * np.pi * 420 * t)) + np.sign(np.sin(2 * np.pi * 520 * t)), 2000) * np.clip(t / 0.02, 0, 1) * np.clip((0.7 - t) / 0.05, 0, 1)
save("sfx_car_horn", carhorn, 0.5)

# ---- ambience loops -------------------------------------------------------
L = 12.0
rain = bp_fast(noise(L + 0.5), 400, 7000) * 0.6 + lp_fast(noise(L + 0.5), 300) * 0.5
drops = np.zeros(len(rain))
for _ in range(900):
    i = rng.integers(0, len(drops) - 600); drops[i:i + 600] += hp_fast(noise(600 / SR), 3000) * env_exp(600 / SR, 0.004) * rng.uniform(0.2, 0.8)
save("amb_rain", loopify(rain + drops * 0.6), 0.7)
wind = lp_fast(noise(L + 0.5), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.17 * t_axis(L + 0.5)) * np.sin(2 * np.pi * 0.05 * t_axis(L + 0.5)))
save("amb_wind", loopify(wind), 0.6)
river = lp_fast(noise(L + 0.5), 700)
lap = np.zeros(len(river))
for _ in range(60):
    i = rng.integers(0, len(lap) - 9000); lap[i:i + 9000] += lp_fast(noise(9000 / SR), 900) * np.hanning(9000) * rng.uniform(0.5, 1.4)
save("amb_river", loopify(river * 0.5 + lap), 0.55)
L2 = 16.0
street = lp_fast(noise(L2 + 0.5), 250) * 0.8 + bp_fast(noise(L2 + 0.5), 300, 1500) * 0.25
for _ in range(9):
    i = rng.integers(0, len(street) - len(bell) - 1); street[i:i + len(bell)] += bell * rng.uniform(0.15, 0.4)
for _ in range(5):
    i = rng.integers(0, len(street) - len(carhorn) - 1); street[i:i + len(carhorn)] += carhorn * rng.uniform(0.1, 0.3)
for _ in range(14):  # engine passes
    n = int(rng.uniform(2, 4) * SR); i = rng.integers(0, len(street) - n - 1); tt = np.arange(n) / SR
    eng = lp_fast(np.sign(np.sin(2 * np.pi * rng.uniform(35, 70) * tt)), 300) * np.hanning(n) * rng.uniform(0.1, 0.3)
    street[i:i + n] += eng
save("amb_street", loopify(street), 0.6)
crowd = np.zeros(int((L2 + 0.5) * SR))
for _ in range(220):  # vowel-ish formant bursts = distant chatter
    n = int(rng.uniform(0.15, 0.5) * SR); tt = np.arange(n) / SR; f0 = rng.uniform(110, 240)
    v = np.sign(np.sin(2 * np.pi * f0 * tt)) * np.hanning(n)
    v = bp_fast(v, rng.uniform(300, 600), rng.uniform(1200, 2600)) * rng.uniform(0.2, 0.6)
    i = rng.integers(0, len(crowd) - n - 1); crowd[i:i + n] += v
crowd = lp_fast(crowd, 2500) + lp_fast(noise(L2 + 0.5), 400) * 0.2
save("amb_crowd", loopify(crowd), 0.55)
night = lp_fast(noise(L + 0.5), 200) * 0.15
tt = t_axis(L + 0.5)
for k in range(5):
    f = rng.uniform(4200, 5200); rate = rng.uniform(2.5, 4.5); ph = rng.uniform(0, 6)
    gate = (np.sin(2 * np.pi * rate * tt + ph) > 0.6) * (np.sin(2 * np.pi * 0.1 * tt + ph) > -0.3)
    night += np.sin(2 * np.pi * f * tt) * gate * (0.5 + 0.5 * np.sin(2 * np.pi * 40 * tt)) * 0.08
save("amb_night", loopify(night), 0.45)
hum = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(100, 0.3), (200, 0.1)]) + lp_fast(noise(L + 0.5), 900) * 0.4
save("amb_mall", loopify(hum), 0.4)

# ---- music -----------------------------------------------------------------
def flute(freq, dur, vib=5.2):
    tt = t_axis(dur); v = 1 + 0.006 * np.sin(2 * np.pi * vib * tt) * np.clip(tt / 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * v) / SR
    tone = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    breath = bp_fast(noise(dur), freq * 0.8, freq * 3) * 0.08
    e = np.clip(tt / 0.08, 0, 1) * np.clip((dur - tt) / 0.12, 0, 1)
    return (tone + breath) * e
def tanpura(dur, sa):
    tt = t_axis(dur); out = np.zeros(len(tt))
    pattern = [sa * 0.75, sa, sa, sa * 0.5]  # Pa Sa Sa Sa(low)
    step_t = 1.25
    for k in range(int(dur / step_t) + 1):
        f = pattern[k % 4]; i = int(k * step_t * SR); n = min(len(tt) - i, int(4 * SR))
        if n <= 0: break
        t2 = np.arange(n) / SR
        s = sum(np.sin(2 * np.pi * f * h * t2) * (0.5 / h) * (1 + 0.3 * np.sin(2 * np.pi * 0.7 * t2 * h)) for h in range(1, 8))
        out[i:i + n] += s * np.exp(-t2 / 2.2) * 0.35
    return out
sa = 261.63 / 1.0
# Raga Bhairav-flavoured scale: Sa komal-Re Ga Ma Pa komal-Dha Ni
r = {"S": 1, "r": 16 / 15, "G": 5 / 4, "M": 4 / 3, "P": 3 / 2, "d": 8 / 5, "N": 15 / 8, "S'": 2}
phrase = [("S", 1), ("r", .5), ("G", .5), ("M", 1), ("P", 1.5), ("d", .5), ("P", 1), ("M", .5), ("G", .5), ("r", 1), ("S", 2),
          ("G", .5), ("M", .5), ("P", 1), ("d", 1), ("N", .5), ("S'", 1.5), ("N", .5), ("d", .5), ("P", 1), ("M", .5), ("G", .5), ("r", .5), ("S", 2.5)]
mel = []
for note, beats in phrase:
    mel.append(flute(sa * 2 * r[note] / 2, beats * 0.62))
mel = np.concatenate(mel)
dur = len(mel) / SR + 1.0
bed = tanpura(dur, sa / 2)
mix = bed.copy(); mix[: len(mel)] += mel * 0.5
save("mus_menu", loopify(mix, 1.0), 0.7)
tt = t_axis(16.5)
pulse = (np.sin(2 * np.pi * 55 * tt) + 0.5 * np.sin(2 * np.pi * 82.4 * tt)) * (0.55 + 0.45 * (np.sin(2 * np.pi * 2.0 * tt) > 0.7))
dh = np.zeros(len(tt))
for k in range(int(16.5 * 2)):
    i = int(k * 0.5 * SR); n = int(0.3 * SR)
    if i + n > len(dh): break
    t2 = np.arange(n) / SR
    dh[i:i + n] += np.sin(2 * np.pi * (90 + 60 * np.exp(-t2 / 0.03)) * t2) * np.exp(-t2 / 0.12) * (1.0 if k % 4 == 0 else 0.5)
save("mus_tension", loopify(lp_fast(pulse, 400) * 0.6 + dh * 0.8 + lp_fast(noise(16.5), 120) * 0.1, 0.5), 0.6)
vic = np.concatenate([flute(sa * r[n_], b * 0.4) for n_, b in [("S", 1), ("G", 1), ("P", 1), ("S'", 3)]])
save("mus_victory", vic + tanpura(len(vic) / SR, sa / 2)[: len(vic)] * 0.6, 0.7)
print("audio done")
