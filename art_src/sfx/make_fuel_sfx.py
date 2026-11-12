"""Builds the FLIGHT FUEL sounds (player/mech.gd _update_fuel), 44.1 kHz mono 16-bit, peak about -6 dB:
  fuel_low.wav    two short soft beeps - the tank just dropped under a quarter while flying
  fuel_out.wav    the jets sputter and wind down - the tank ran dry and the mech drops to the ground
  fuel_ready.wav  a quick rising two-note chime with a shimmer - the tank is full and you can fly again

  py -3 art_src/sfx/make_fuel_sfx.py
"""
import os, wave
import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx")
rng = np.random.default_rng(11)


def t_of(sec):
    return np.arange(int(RATE * sec)) / RATE


def lowpass(x, hz):
    a = 1.0 - np.exp(-2 * np.pi * hz / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def soft_square(f, t, mix=0.35):
    s = np.sin(2 * np.pi * f * t)
    return (1 - mix) * s + mix * np.tanh(4 * s)


def fade(x, a=0.003, r=0.012):
    t = np.arange(len(x)) / RATE
    return x * np.minimum(1, t / a) * np.minimum(1, (t[-1] - t) / r)


def save(name, x, peak=0.5):
    x = x / np.max(np.abs(x)) * peak
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("wrote", name, "%.2f s" % (len(x) / RATE))


# fuel_low: beep (1046 Hz) - gap - beep, each 70 ms with a fast decay; a cockpit warning, not an alarm.
def beep(f, sec):
    t = t_of(sec)
    return fade(soft_square(f, t) * np.exp(-t / 0.06) + 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.03))
low = np.concatenate([beep(1046, 0.075), np.zeros(int(RATE * 0.05)), beep(1046, 0.11)])
save("fuel_low.wav", low, 0.42)

# fuel_out: thruster roar (filtered noise) chopped into 3 sputters, under a tone falling 300 -> 55 Hz.
t = t_of(0.62)
roar = lowpass(rng.standard_normal(len(t)), 1400) * 3.0
chop = np.ones_like(t)
for c0, c1 in [(0.12, 0.16), (0.24, 0.29), (0.36, 0.43)]:
    chop[(t > c0) & (t < c1)] = 0.15
chop = lowpass(chop, 60)
freq = 55 + 245 * np.exp(-t / 0.18)
whine = np.sin(2 * np.pi * np.cumsum(freq) / RATE)
out = (0.7 * roar * chop * np.exp(-t / 0.25) + 0.8 * whine * np.exp(-t / 0.3))
save("fuel_out.wav", fade(out, 0.004, 0.06), 0.5)

# fuel_ready: G5 then D6 (bright, short), the second note held with a soft high shimmer.
def note(f, sec, dec):
    t = t_of(sec)
    return (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) + 0.12 * np.sin(2 * np.pi * 3 * f * t)) * np.exp(-t / dec)
a = fade(note(784, 0.07, 0.05))
b = note(1175, 0.32, 0.12)
tb = t_of(0.32)
b = fade(b + 0.18 * np.sin(2 * np.pi * 2350 * tb) * np.sin(2 * np.pi * 9 * tb) ** 2 * np.exp(-tb / 0.15), 0.003, 0.05)
save("fuel_ready.wav", np.concatenate([a, b]), 0.42)
