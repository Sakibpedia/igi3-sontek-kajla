"""Short engine start / driving loop for the drivable Kajla vehicles."""
import numpy as np, wave, os, math
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = np.clip(x / (np.max(np.abs(x)) or 1) * peak, -1, 1)
    f = int(0.01 * SR)
    x[-f:] *= np.linspace(1, 0, f)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print('wrote', name)


t = np.arange(int(1.2 * SR)) / SR
# starter motor rising into an idle chug
f = np.cumsum(np.linspace(28, 95, len(t))) / SR
x = np.sin(2 * np.pi * f) * 0.5 + np.sin(4 * np.pi * f) * 0.2
x += np.random.uniform(-1, 1, len(t)) * 0.08 * np.exp(-t * 2)
save('sfx_engine_start', x * np.minimum(t / 0.05, 1) * np.exp(-t * 1.1))

t2 = np.arange(int(1.8 * SR)) / SR
f2 = 78 + 12 * np.sin(2 * np.pi * 2.4 * t2)
y = np.sin(2 * np.pi * np.cumsum(f2) / SR) * 0.45 + np.sin(4 * np.pi * np.cumsum(f2) / SR) * 0.18
y += np.random.uniform(-1, 1, len(t2)) * 0.05
save('sfx_engine_loop', y)
