"""Combat sounds, synthesised in layers (numpy; no recordings, no AI):
  beam_shot     Beam Rifle: a bright FM zap sweeping down + a sub thump + a sizzling noise tail
  gatling_shot  Gatling round: a sharp crack + a body thump + a mechanical clack (short: it fires 16/s)
  pistol_shot   Dual Beam Pistols: a quick high zap with a tick
  drone_shot    Bit Drone: a tiny zap
  death_boom    big robot destroyed: a deep boom + metal debris rattle + crackling tail
  heartbeat     low-armour warning: a soft lub-dub
  boss_braam    boss arrival: a low detuned brass-like swell with a filter sweep
All 44.1 kHz mono 16-bit, peak <= -1 dBFS, loudness matched (loudest 100 ms RMS) to
assets/audio/sfx/beam_rifle.wav, x LEVEL per sound.

py -3 art_src/sfx/make_combat_sfx.py <out_dir> <reference.wav>
"""
import sys, wave, os
import numpy as np

OUT = sys.argv[1]
REF = sys.argv[2]
SR = 44100
rng = np.random.default_rng(11)
os.makedirs(OUT, exist_ok=True)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def env(t, a, d):
    return np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-np.maximum(t - a, 0.0) * d)


def sweep_phase(f0, f1, sec, curve=3.0):
    t = t_axis(sec)
    f = f1 + (f0 - f1) * np.exp(-(t / sec) * curve)
    return 2 * np.pi * np.cumsum(f) / SR, t


def sweep_sine(f0, f1, sec, curve=3.0):
    ph, t = sweep_phase(f0, f1, sec, curve)
    return np.sin(ph), t


def onepole_lp(x, hz):
    a = np.exp(-2 * np.pi * np.asarray(hz) / SR)
    a = np.broadcast_to(a, x.shape)
    y = np.empty_like(x)
    z = 0.0
    for i in range(len(x)):
        z = (1 - a[i]) * x[i] + a[i] * z
        y[i] = z
    return y


def hp(x, hz):
    return x - onepole_lp(x, hz)


def bp(x, lo, hi):
    return onepole_lp(hp(x, lo), hi)


def noise(sec):
    return rng.uniform(-1, 1, int(sec * SR))


def reverb(x, mix=0.18, size=1.0):
    y = np.concatenate([x, np.zeros(int(0.5 * SR))])
    out = np.zeros_like(y)
    for d, g in ((1116, 0.78), (1188, 0.77), (1277, 0.76), (1356, 0.75)):
        d = int(d * size)
        buf = np.zeros_like(y)
        for i in range(d, len(y)):
            buf[i] = y[i - d] + g * buf[i - d]
        out += buf
    out = onepole_lp(out, 5000.0) / 4.0
    return y * (1 - mix) + out * mix


def pad(x, sec):
    return np.concatenate([x, np.zeros(max(0, int(sec * SR) - len(x)))])[: int(sec * SR)]


def mixdown(*layers):
    n = max(len(l) for l in layers)
    y = np.zeros(n)
    for l in layers:
        y[: len(l)] += l
    return y


def rms_peak(x, win=0.1):
    w = int(win * SR)
    if len(x) <= w:
        return np.sqrt(np.mean(x ** 2))
    c = np.cumsum(np.concatenate([[0], x ** 2]))
    return np.sqrt(np.max(c[w:] - c[:-w]) / w)


def read_wav(path):
    with wave.open(path) as f:
        d = np.frombuffer(f.readframes(f.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
        if f.getnchannels() == 2:
            d = d.reshape(-1, 2).mean(axis=1)
    return d


TARGET = rms_peak(read_wav(REF))


def save(name, x, level=1.0, fade=0.02):
    x = x - np.mean(x)
    n = int(fade * SR)
    if n:
        x[-n:] *= np.linspace(1, 0, n)
    x *= TARGET * level / max(rms_peak(x), 1e-9)
    peak = np.max(np.abs(x))
    if peak > 0.891:
        x *= 0.891 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("WROTE", name, round(len(x) / SR, 2), "s")


# --- Beam Rifle ---------------------------------------------------------------------------------
def beam_shot():
    sec = 0.5
    ph, t = sweep_phase(2600, 380, sec, 5.0)
    mph, _ = sweep_phase(5200, 900, sec, 6.0)
    fm = np.sin(ph + 2.2 * np.exp(-t * 14) * np.sin(mph))
    zap_l = fm * env(t, 0.002, 9.0) * 0.55
    thump, tt = sweep_sine(120, 45, 0.16, 4.0)
    thump = thump * env(tt, 0.002, 26.0) * 0.9
    sizzle = bp(noise(sec), 2500, 9000) * env(t, 0.004, 7.0) * 0.35
    sizzle *= 0.6 + 0.4 * np.sin(2 * np.pi * 60 * t)  # crackle wobble
    click = hp(noise(0.012), 3000) * env(t_axis(0.012), 0.0005, 300) * 0.8
    return reverb(mixdown(zap_l, thump, sizzle, click), 0.14, 0.8)


def gatling_shot():
    sec = 0.2
    t = t_axis(sec)
    crack = hp(noise(0.03), 1800) * env(t_axis(0.03), 0.0005, 160) * 1.0
    body, tb = sweep_sine(170, 70, 0.09, 3.0)
    body = body * env(tb, 0.001, 45) * 0.9
    low = onepole_lp(noise(sec), 400) * env(t, 0.001, 30) * 0.9
    clack = bp(noise(0.02), 900, 3500) * env(t_axis(0.02), 0.0005, 250) * 0.5
    clack = np.concatenate([np.zeros(int(0.035 * SR)), clack])
    return mixdown(crack, body, low, clack)


def pistol_shot():
    sec = 0.16
    z, t = sweep_sine(2100, 650, sec, 6.0)
    zap = np.sign(z) * np.abs(z) ** 0.6 * env(t, 0.001, 24) * 0.5
    zap = onepole_lp(zap, 6000.0)
    tick = hp(noise(0.006), 4000) * 0.9
    body, tb = sweep_sine(220, 110, 0.05, 3.0)
    return mixdown(zap, tick, body * env(tb, 0.001, 70) * 0.5)


def drone_shot():
    z, t = sweep_sine(3400, 1400, 0.09, 5.0)
    return z * env(t, 0.001, 40) * 0.6 + hp(noise(0.09), 5000) * env(t, 0.001, 60) * 0.2


def death_boom():
    sec = 1.5
    t = t_axis(sec)
    boom, _ = sweep_sine(85, 32, sec, 2.5)
    boom = boom * env(t, 0.003, 3.2) * 1.0
    rumble = onepole_lp(noise(sec), 180) * env(t, 0.01, 2.2) * 2.2
    blast = onepole_lp(noise(sec), 1800) * env(t, 0.001, 9.0) * 0.9
    crack = hp(noise(0.04), 2000) * env(t_axis(0.04), 0.0005, 90) * 0.9
    # Metal debris: short resonant pings scattered over the first half second.
    deb = np.zeros(len(t))
    for i in range(14):
        at = int(rng.uniform(0.04, 0.7) * SR)
        f = rng.uniform(1400, 4200)
        d = int(0.09 * SR)
        tt = t_axis(0.09)
        ping = np.sin(2 * np.pi * f * tt) * np.sin(2 * np.pi * f * 1.37 * tt) * env(tt, 0.0005, rng.uniform(40, 70))
        deb[at:at + d] += ping[: max(0, min(d, len(t) - at))] * rng.uniform(0.08, 0.2)
    # Crackling fire tail.
    crk = np.zeros(len(t))
    for i in range(70):
        at = int(rng.uniform(0.15, 1.3) * SR)
        crk[at] = rng.uniform(-1, 1)
    crk = hp(onepole_lp(crk, 3000), 600) * 2.5 * env(t, 0.3, 1.6)
    return reverb(mixdown(boom, rumble, blast, crack, deb, crk), 0.12, 1.2)


def heartbeat():
    out = np.zeros(int(0.7 * SR))
    for at, a in ((0.0, 1.0), (0.2, 0.7)):
        b, tb = sweep_sine(70, 40, 0.18, 3.0)
        b = onepole_lp(b * env(tb, 0.006, 20), 300)
        i = int(at * SR)
        out[i:i + len(b)] += b * a
    return out


def boss_braam():
    sec = 3.2
    t = t_axis(sec)
    y = np.zeros(len(t))
    for f, a in ((55.0, 1.0), (55.4, 0.9), (82.4, 0.55), (110.2, 0.5), (109.6, 0.45)):
        ph = 2 * np.pi * f * t + rng.uniform(0, 6)
        saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
        y += saw * a
    cutoff = 200 + 1500 * np.minimum(t / 0.5, 1.0) * np.exp(-t * 0.7)
    y = onepole_lp(onepole_lp(y, cutoff), cutoff)
    y *= env(t, 0.06, 0.9)
    hit = onepole_lp(noise(sec), 220) * env(t, 0.002, 4.0) * 2.0
    return reverb(mixdown(y * 0.6, hit), 0.25, 1.4)


save("beam_shot", beam_shot(), 1.0)
save("gatling_shot", gatling_shot(), 0.9, 0.005)
save("pistol_shot", pistol_shot(), 0.75, 0.005)
save("drone_shot", drone_shot(), 0.6, 0.005)
save("death_boom", death_boom(), 1.15)
save("heartbeat", heartbeat(), 0.8)
save("boss_braam", boss_braam(), 1.1)
