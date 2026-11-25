"""PA / microphone announcement cues for the Bengali control-room broadcasts."""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def save(name, x, peak=0.75):
    x = np.asarray(x, dtype=np.float64)
    x = np.clip(x / (np.max(np.abs(x)) or 1) * peak, -1, 1)
    f = int(0.02 * SR)
    x[-f:] *= np.linspace(1, 0, f)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print('wrote', name)


t = np.arange(int(1.6 * SR)) / SR
# two-tonePA chime, band-limited so it reads as a loudspeaker
c = (np.sin(2 * np.pi * 880 * t) * (t < 0.35) + np.sin(2 * np.pi * 660 * t) * ((t >= 0.42) & (t < 0.9)))
c *= np.exp(-((t - 0.18) ** 2) * 12) + np.exp(-((t - 0.62) ** 2) * 10)
c += 0.12 * np.random.uniform(-1, 1, len(t)) * np.exp(-t * 3)
save('sfx_pa_chime', c)

t2 = np.arange(int(1.0 * SR)) / SR
st = np.random.uniform(-1, 1, len(t2))
# crude loudspeaker band-pass via cumulative smoothing difference
lo = np.convolve(st, np.ones(60) / 60, mode='same')
hi = st - lo
env = np.minimum(t2 / 0.05, 1) * np.exp(-t2 * 2.5)
save('sfx_pa_static', (hi * 0.6 + lo * 0.4) * env)

t3 = np.arange(int(0.3 * SR)) / SR
save('sfx_mic_click', (np.random.uniform(-1, 1, len(t3)) * np.exp(-t3 * 45)) * (t3 < 0.06))
