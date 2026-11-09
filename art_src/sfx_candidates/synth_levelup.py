"""Level-up sound candidates, synthesised (numpy, run with Blender's Python):
  A bells   - a quick rising E-major bell arpeggio (FM bells) into a shimmering chord, glitter pings
  B mecha   - a rising synth sweep into a bright detuned chord stab with a metallic ping and sparkle
  C arcade  - a fast smooth ascending run into a warm major chord with vibrato
All 44.1 kHz mono 16-bit, light Schroeder reverb, loudness matched (loudest 300 ms RMS) to the old
levelup.wav, peak <= -1 dBFS.
"""
import sys, wave, numpy as np

OUT = sys.argv[sys.argv.index('--') + 1]
OLD = sys.argv[sys.argv.index('--') + 2]
SR = 44100
rng = np.random.default_rng(7)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def env_ad(t, a, d):
    return np.minimum(t / a, 1.0) * np.exp(-np.maximum(t - a, 0.0) * d)


def bell(f, sec, decay=4.5, index=2.5):
    t = t_axis(sec)
    i = index * np.exp(-t * 8.0)
    y = np.sin(2 * np.pi * f * t + i * np.sin(2 * np.pi * 2.0 * f * t))
    y += 0.25 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-t * 9.0)
    return y * env_ad(t, 0.003, decay)


def ping(f, sec=0.25, decay=30.0):
    t = t_axis(sec)
    return np.sin(2 * np.pi * f * t) * env_ad(t, 0.001, decay)


def saw(f_of_t, sec, harmonics=24):
    t = t_axis(sec)
    ph = 2 * np.pi * np.cumsum(f_of_t(t)) / SR
    y = np.zeros_like(t)
    ff = f_of_t(t)
    for k in range(1, harmonics + 1):
        y += np.where(ff * k < 15000, np.sin(ph * k) / k, 0.0)
    return y * 0.6


def lowpass(x, cut):
    """One-pole low-pass; `cut` = Hz (scalar or per-sample array)."""
    cut = np.broadcast_to(np.asarray(cut, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y


def mix_at(buf, x, at, gain=1.0):
    i = int(at * SR)
    n = min(len(x), len(buf) - i)
    if n > 0:
        buf[i:i + n] += x[:n] * gain


def reverb(x, wet=0.25):
    out = np.zeros(len(x) + int(0.6 * SR))
    src = np.concatenate([x, np.zeros(int(0.6 * SR))])
    for d_ms, g in ((29.7, 0.77), (37.1, 0.75), (41.1, 0.73), (43.7, 0.71)):
        d = int(d_ms * SR / 1000)
        y = src.copy()
        for i in range(d, len(y)):
            y[i] += g * y[i - d]
        out += y * 0.25
    for d_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(d_ms * SR / 1000)
        y = np.zeros_like(out)
        for i in range(len(out)):
            xd = out[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -g * out[i] + xd + g * yd
        out = y
    res = src * (1 - wet) + out * wet
    return res


def loud(x):
    w = int(0.3 * SR)
    best = 0.0
    for i in range(0, max(len(x) - w, 1), 441):
        best = max(best, float(np.sqrt(np.mean(x[i:i + w] ** 2))))
    return best


def finish(x, target_rms, sec):
    x = x[:int(sec * SR)]
    fade = int(0.08 * SR)
    x[-fade:] *= np.linspace(1, 0, fade) ** 2
    x *= target_rms / max(loud(x), 1e-6)
    peak = np.max(np.abs(x))
    if peak > 0.89:
        x *= 0.89 / peak
    return x


def save(name, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(OUT + "/" + name, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("WROTE", name, round(len(x) / SR, 2), "s")


with wave.open(OLD, "rb") as w:
    old = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768
    if w.getnchannels() == 2:
        old = old.reshape(-1, 2).mean(1)
target = loud(old)
print("old loudness", round(target, 4), "peak", round(float(np.max(np.abs(old))), 3))

# --- A bells -------------------------------------------------------------------------------------
buf = np.zeros(int(2.0 * SR))
for i, f in enumerate((659.26, 830.61, 987.77, 1318.51)):
    mix_at(buf, bell(f, 1.0, 5.0), i * 0.062, 0.32)
for f in (1318.51, 1661.22, 1975.53):
    for cents in (-4, 4):
        t = t_axis(1.2)
        ff = f * 2 ** (cents / 1200)
        mix_at(buf, np.sin(2 * np.pi * ff * t) * env_ad(t, 0.02, 3.2), 0.25, 0.07)
pent = (2637.0, 2959.96, 3322.44, 3951.07, 4434.92)
for k in range(14):
    mix_at(buf, ping(pent[rng.integers(len(pent))]), 0.22 + rng.random() * 0.7, 0.05 + rng.random() * 0.06)
n = t_axis(0.3)
noise = rng.standard_normal(len(n))
riser = lowpass(noise, 600 + 5000 * (n / 0.3) ** 2) * np.sin(np.pi * np.minimum(n / 0.3, 1.0)) * 0.12
mix_at(buf, riser, 0.0)
save("cand_A_bells.wav", finish(reverb(buf, 0.28), target, 1.5))

# --- B mecha -------------------------------------------------------------------------------------
buf = np.zeros(int(2.0 * SR))
sweep = saw(lambda t: 220.0 * (4.0 ** np.minimum(t / 0.18, 1.0)), 0.2)
st = t_axis(0.2)
sweep = lowpass(sweep, 700 + 6000 * (st / 0.2)) * np.minimum(st / 0.18, 1.0) * 0.5
mix_at(buf, sweep, 0.0)
st = t_axis(1.0)
chord = np.zeros_like(st)
for f in (440.0, 554.37, 659.26, 880.0, 1108.73):
    for cents in (-7, 0, 7):
        ff = f * 2 ** (cents / 1200)
        chord += saw(lambda t, ff=ff: np.full_like(t, ff), 1.0, 16)
chord = lowpass(chord, 1500 + 6500 * np.exp(-st * 6.0)) * env_ad(st, 0.004, 3.0) * 0.12
mix_at(buf, chord, 0.18)
mix_at(buf, bell(1760.0, 0.9, 5.5, 3.5), 0.18, 0.25)
for k in range(10):
    mix_at(buf, ping(pent[rng.integers(len(pent))] * 1.12), 0.25 + rng.random() * 0.6, 0.04 + rng.random() * 0.05)
save("cand_B_mecha.wav", finish(reverb(buf, 0.22), target, 1.4))

# --- C arcade ------------------------------------------------------------------------------------
buf = np.zeros(int(2.0 * SR))


def square_note(f, sec, decay):
    t = t_axis(sec)
    y = np.zeros_like(t)
    for k in (1, 3, 5, 7, 9):
        if f * k < 14000:
            y += np.sin(2 * np.pi * f * k * t) / k
    return y * env_ad(t, 0.002, decay)


for i, f in enumerate((1046.5, 1174.66, 1318.51, 1567.98, 2093.0)):
    mix_at(buf, square_note(f, 0.2, 14.0), i * 0.045, 0.16)
st = t_axis(0.9)
vib = 1.0 + 0.004 * np.sin(2 * np.pi * 6.0 * st) * np.minimum(st / 0.2, 1.0)
for f in (1046.5, 1318.51, 1567.98, 2093.0):
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    tri = (2 / np.pi) * np.arcsin(np.sin(ph))
    mix_at(buf, tri * env_ad(st, 0.008, 3.4), 0.23, 0.11)
for k in range(8):
    mix_at(buf, ping(pent[rng.integers(len(pent))]), 0.25 + rng.random() * 0.5, 0.04 + rng.random() * 0.04)
save("cand_C_arcade.wav", finish(reverb(buf, 0.2), target, 1.3))
