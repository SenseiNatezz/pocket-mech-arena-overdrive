"""Builds assets/audio/sfx/step.wav - the walking mechs' footstep (player/mech.gd, one per footfall).
A heavy metal foot coming down: a low thump dropping in pitch, a short dull scrape of noise, and a faint
metal clank on top. 44.1 kHz mono 16-bit, about 0.17 s, peak about -6 dB like the other recordings.

  py -3 art_src/sfx/make_step.py
"""
import os, wave
import numpy as np

RATE = 44100
n = int(RATE * 0.17)
t = np.arange(n) / RATE
rng = np.random.default_rng(7)

# Thump: 95 Hz falling to 45 Hz, fast attack, ~50 ms decay.
freq = 45.0 + 50.0 * np.exp(-t / 0.03)
thump = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.05)

# Scrape: noise through a one-pole low-pass (~900 Hz), ~25 ms decay.
noise = rng.standard_normal(n)
lp = np.zeros(n)
a = 1.0 - np.exp(-2 * np.pi * 900.0 / RATE)
acc = 0.0
for i in range(n):
    acc += a * (noise[i] - acc)
    lp[i] = acc
scrape = lp / np.max(np.abs(lp)) * np.exp(-t / 0.025)

# Clank: two inharmonic partials, very short.
clank = (np.sin(2 * np.pi * 730.0 * t) + 0.6 * np.sin(2 * np.pi * 1170.0 * t)) * np.exp(-t / 0.018)

mix = 1.0 * thump + 0.45 * scrape + 0.12 * clank
mix *= np.minimum(1.0, t / 0.002)            # 2 ms attack (no click)
mix *= np.minimum(1.0, (t[-1] - t) / 0.01)   # 10 ms tail fade
mix = mix / np.max(np.abs(mix)) * 0.5

out = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx", "step.wav")
with wave.open(out, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes((mix * 32767).astype("<i2").tobytes())
print("WROTE", os.path.normpath(out), n, "samples")
