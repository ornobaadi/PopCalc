"""Procedurally synthesizes PopCalc's sound effects.

Everything is generated from math, so the audio is original and
license-free. Re-run to regenerate:

    python tool/generate_sounds.py

Output: assets/sounds/<pack>/*.wav
"""

import math
import os
import random
import shutil
import struct
import wave

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')

# C-major pentatonic, so any sequence of typed digits sounds musical.
PENTA = [0, 2, 4, 7, 9]


def note_hz(semitones_from_c5):
    return 523.25 * 2 ** (semitones_from_c5 / 12)


def digit_semitone(d):
    """Digit 0-9 -> pentatonic step across two octaves."""
    return PENTA[d % 5] + 12 * (d // 5)


# ─── Helpers ──────────────────────────────────────────────────────────────────

def silence(sec, sr=SR):
    return [0.0] * int(sec * sr)


def mix(dst, src, at=0):
    need = at + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[at + i] += v
    return dst


def normalize(buf, peak):
    """Loudness-maximize: normalize, soft-clip drive, then set the peak.

    [peak] is the relative level (0-1) between effects in a pack; everything
    is pushed hard because short UI blips on phone speakers read as quiet.
    """
    m = max((abs(v) for v in buf), default=0.0) or 1.0
    drive = 2.4
    k = math.tanh(drive)
    level = min(0.98, 0.98 * (0.55 + 0.45 * peak / 0.7))
    return [math.tanh(drive * v / m) / k * level for v in buf]


def fade_edges(buf, sr=SR, ms=3):
    """Tiny fades at both ends so nothing ever clicks."""
    n = min(len(buf) // 2, int(sr * ms / 1000))
    for i in range(n):
        g = i / n
        buf[i] *= g
        buf[-1 - i] *= g
    return buf


def lowpass(buf, cutoff, sr=SR):
    rc = 1.0 / (2 * math.pi * cutoff)
    a = (1 / sr) / (rc + 1 / sr)
    out, y = [], 0.0
    for v in buf:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(buf, cutoff, sr=SR):
    rc = 1.0 / (2 * math.pi * cutoff)
    a = rc / (rc + 1 / sr)
    out, y, prev = [], 0.0, 0.0
    for v in buf:
        y = a * (y + v - prev)
        prev = v
        out.append(y)
    return out


def write_wav(path, buf, sr=SR):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32767)) for v in buf))


# ─── Voices ───────────────────────────────────────────────────────────────────

def bloop(freq, dur=0.1, drop=1.6, decay=0.042, shape='sine'):
    """Bubbly pop: pitch falls quickly into [freq] with a fast decay."""
    n = int(dur * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1 + drop * math.exp(-t / 0.007))
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) + 0.22 * math.sin(2 * phase)
        if shape == 'tri':
            s = 2 / math.pi * math.asin(math.sin(phase)) + 0.22 * math.sin(2 * phase)
        env = min(1.0, t / 0.001) * math.exp(-t / decay)
        out.append(s * env)
    return out


def marimba(freq, dur=0.35, decay=0.11):
    """Soft wooden mallet: fundamental + quickly fading 4th harmonic."""
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.002) * math.exp(-t / decay)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.35 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-t / 0.018)
             + 0.12 * math.sin(2 * math.pi * freq * 10 * t) * math.exp(-t / 0.006)
             + 0.25 * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-t / 0.05))
        out.append(s * env)
    return out


def noise_burst(dur, decay, rng, hp=1500, lp=9000):
    n = int(dur * SR)
    raw = [rng.uniform(-1, 1) * math.exp(-(i / SR) / decay) for i in range(n)]
    return lowpass(highpass(raw, hp), lp)


def resonant_click(freq, dur, decay):
    n = int(dur * SR)
    return [math.sin(2 * math.pi * freq * i / SR) * math.exp(-(i / SR) / decay)
            for i in range(n)]


def bell(freq, dur=0.9, decay=0.3):
    """Inharmonic metal bell (typewriter carriage bell)."""
    partials = [(1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12)]
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        s = sum(a * math.sin(2 * math.pi * freq * r * t) * math.exp(-t / (decay / r ** 0.5))
                for r, a in partials)
        out.append(s * min(1.0, t / 0.001))
    return out


def sweep(f0, f1, dur, decay=None, shape='sine'):
    n = int(dur * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        p = i / n
        f = f0 * (f1 / f0) ** p
        phase += 2 * math.pi * f / SR
        s = math.sin(phase)
        if shape == 'tri':
            s = 2 / math.pi * math.asin(s)
        env = min(1.0, t / 0.002) * (math.exp(-t / decay) if decay else (1 - p))
        out.append(s * env)
    return out


def whoosh(dur, rng, f_from, f_to):
    """Filtered noise swept in brightness, bell-shaped envelope."""
    n = int(dur * SR)
    out, y = [], 0.0
    for i in range(n):
        p = i / n
        cutoff = f_from * (f_to / f_from) ** p
        rc = 1.0 / (2 * math.pi * cutoff)
        a = (1 / SR) / (rc + 1 / SR)
        y += a * (rng.uniform(-1, 1) - y)
        out.append(y * math.sin(math.pi * p) ** 1.5)
    return out


# ─── Packs ────────────────────────────────────────────────────────────────────
# Every pack exposes the same file names so the app can swap freely.

def pack_pop(rng):
    s = {}
    for d in range(10):
        s[f'digit_{d}'] = normalize(bloop(note_hz(digit_semitone(d))), 0.5)
    s['operator'] = normalize(mix(bloop(note_hz(0), dur=0.11, decay=0.045, shape='tri'),
                                  bloop(note_hz(7), dur=0.1, decay=0.04), at=int(0.035 * SR)), 0.55)
    s['utility'] = normalize(bloop(note_hz(19), dur=0.06, drop=0.6, decay=0.02), 0.45)
    s['backspace'] = normalize(sweep(note_hz(12), note_hz(2), 0.11, decay=0.05), 0.5)
    s['clear'] = normalize(mix(whoosh(0.3, rng, 9000, 1400),
                               [v * 0.6 for v in sweep(note_hz(12), note_hz(-5), 0.27, decay=0.1)]), 0.6)
    # Rising arpeggio C-E-G-C + sparkle: the "you did it" moment.
    win = []
    for k, st in enumerate([0, 4, 7, 12]):
        mix(win, [v * (0.7 + 0.1 * k) for v in bloop(note_hz(st), dur=0.35, drop=0.4, decay=0.12)],
            at=int(k * 0.055 * SR))
    mix(win, [v * 0.35 for v in bloop(note_hz(24), dur=0.4, drop=0.1, decay=0.15)], at=int(0.22 * SR))
    s['success'] = normalize(win, 0.7)
    err = []
    mix(err, bloop(note_hz(2), dur=0.14, drop=0.3, decay=0.06, shape='tri'))
    mix(err, bloop(note_hz(1), dur=0.18, drop=0.3, decay=0.07, shape='tri'), at=int(0.12 * SR))
    s['error'] = normalize(err, 0.6)
    s.update(scientific_sounds(
        lambda st, dur, decay: bloop(note_hz(st), dur=dur, drop=0.5, decay=decay)))
    return s


def pack_mellow(rng):
    s = {}
    for d in range(10):
        s[f'digit_{d}'] = normalize(marimba(note_hz(digit_semitone(d))), 0.6)
    op = marimba(note_hz(-5), dur=0.3, decay=0.09)
    s['operator'] = normalize(mix(op, [v * 0.5 for v in marimba(note_hz(2), dur=0.3, decay=0.09)]), 0.6)
    s['utility'] = normalize(marimba(note_hz(19), dur=0.15, decay=0.04), 0.45)
    bs = []
    mix(bs, marimba(note_hz(7), dur=0.2, decay=0.06))
    mix(bs, [v * 0.7 for v in marimba(note_hz(4), dur=0.2, decay=0.06)], at=int(0.05 * SR))
    s['backspace'] = normalize(bs, 0.5)
    s['clear'] = normalize(mix(whoosh(0.35, rng, 6000, 1100),
                               [v * 0.5 for v in marimba(note_hz(-12), dur=0.4, decay=0.15)]), 0.6)
    win = []
    for k, st in enumerate([0, 7, 12, 16, 19]):
        mix(win, marimba(note_hz(st), dur=0.8, decay=0.25), at=int(k * 0.07 * SR))
    s['success'] = normalize(win, 0.7)
    err = []
    mix(err, marimba(note_hz(-6), dur=0.35, decay=0.1))
    mix(err, marimba(note_hz(-7), dur=0.35, decay=0.1), at=int(0.14 * SR))
    s['error'] = normalize(err, 0.6)
    s.update(scientific_sounds(
        lambda st, dur, decay: marimba(note_hz(st - 5), dur=dur * 2, decay=decay * 2)))
    return s


def pack_typewriter(rng):
    def key(body_hz, weight=1.0):
        click = noise_burst(0.05, 0.006, rng, hp=2000, lp=10000)
        body = resonant_click(body_hz, 0.06, 0.012)
        thud = resonant_click(max(600, body_hz / 2), 0.06, 0.02)
        return mix(mix(click, [v * 0.7 for v in body]), [v * 0.3 * weight for v in thud])

    s = {}
    for d in range(10):
        # Tiny per-key variation, like real keys.
        s[f'digit_{d}'] = normalize(key(1800 + d * 45 + rng.uniform(-30, 30)), 0.5)
    s['operator'] = normalize(key(1100, weight=2.0), 0.58)
    s['utility'] = normalize(noise_burst(0.035, 0.006, rng, hp=3000), 0.45)
    s['backspace'] = normalize(mix(key(1300), [v * 0.4 for v in noise_burst(0.08, 0.02, rng)], at=int(0.02 * SR)), 0.45)
    # Carriage return: ratchet zip + clunk.
    cr = []
    for k in range(9):
        mix(cr, [v * (0.4 + k * 0.04) for v in noise_burst(0.02, 0.004, rng, hp=2500)], at=int(k * 0.022 * SR))
    mix(cr, key(1000, weight=2.0), at=int(0.21 * SR))
    s['clear'] = normalize(cr, 0.5)
    win = key(1500)
    mix(win, [v * 0.9 for v in bell(2093)], at=int(0.03 * SR))
    s['success'] = normalize(win, 0.6)
    err = []
    mix(err, key(900, weight=2.0))
    mix(err, key(860, weight=2.0), at=int(0.1 * SR))
    s['error'] = normalize(err, 0.55)
    # Pitched key strikes; π and e ring the carriage bell.
    sci = scientific_sounds(lambda st, dur, decay: key(1100 * 2 ** (st / 24)))
    ping = key(1500)
    mix(ping, [v * 0.7 for v in bell(2637, dur=0.5, decay=0.15)], at=int(0.02 * SR))
    sci['constant'] = normalize(ping, 0.5)
    s.update(sci)
    return s


# ─── Material packs ───────────────────────────────────────────────────────────
# Exclusive packs that ship with a material skin (look + sound + haptics sold
# as one set). Same file names as the packs above. They live in their own
# folders and are not offered in the sound-pack picker.

def partials(freq, spec, dur, attack=0.001):
    """Sum of decaying sine partials: spec is [(ratio, level, decay_s)]."""
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        s = sum(a * math.sin(2 * math.pi * freq * r * t) * math.exp(-t / d)
                for r, a, d in spec)
        out.append(s * min(1.0, t / attack))
    return out


def chirp(f0, f1, dur, decay, shape='sine', curve=0.012):
    """Pitch glides from f0 to f1 exponentially fast, then decays."""
    n = int(dur * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = f1 + (f0 - f1) * math.exp(-t / curve)
        phase += 2 * math.pi * f / SR
        s = math.sin(phase)
        if shape == 'square':
            s = (1.0 if s >= 0 else -1.0) * 0.6 + 0.4 * s
        elif shape == 'saw':
            s = 2 * ((phase / (2 * math.pi)) % 1.0) - 1
        out.append(s * min(1.0, t / 0.001) * math.exp(-t / decay))
    return out


def material_pack(voice, rng, op_st=-5, win=(0, 4, 7, 12), win_gap=0.06,
                  clear_from=7000, clear_to=1200, sci_shift=0):
    """Builds a full pack from one [voice](semitone, dur, decay) function."""
    s = {}
    for d in range(10):
        s[f'digit_{d}'] = normalize(voice(digit_semitone(d), 0.16, 0.05), 0.52)
    op = voice(op_st, 0.2, 0.07)
    mix(op, [v * 0.7 for v in voice(op_st + 7, 0.18, 0.06)], at=int(0.03 * SR))
    s['operator'] = normalize(op, 0.56)
    s['utility'] = normalize(voice(19, 0.09, 0.025), 0.45)
    bs = voice(9, 0.12, 0.04)
    mix(bs, [v * 0.7 for v in voice(2, 0.12, 0.04)], at=int(0.04 * SR))
    s['backspace'] = normalize(bs, 0.5)
    clear = whoosh(0.3, rng, clear_from, clear_to)
    mix(clear, [v * 0.6 for v in voice(-7, 0.3, 0.1)], at=int(0.08 * SR))
    s['clear'] = normalize(clear, 0.58)
    chime = []
    for k, st in enumerate(win):
        mix(chime, [v * (0.7 + 0.08 * k) for v in voice(st, 0.5, 0.16)],
            at=int(k * win_gap * SR))
    s['success'] = normalize(chime, 0.68)
    err = voice(-6, 0.2, 0.07)
    mix(err, voice(-7, 0.24, 0.08), at=int(0.12 * SR))
    s['error'] = normalize(err, 0.58)
    s.update(scientific_sounds(
        lambda st, dur, decay: voice(st + sci_shift, dur, decay)))
    return s


def pack_chrome(rng):
    """Cold, hard pings: bright inharmonic metal with a quick shimmer."""
    spec = [(1.0, 1.0, 0.09), (2.41, 0.55, 0.06), (3.93, 0.35, 0.04),
            (6.2, 0.22, 0.025), (9.1, 0.12, 0.015)]

    def voice(st, dur, decay):
        scaled = [(r, a, d * decay / 0.05) for r, a, d in spec]
        ping = partials(note_hz(st + 5), scaled, dur * 1.6)
        mix(ping, [v * 0.3 for v in noise_burst(0.012, 0.002, rng, hp=5000, lp=14000)])
        return highpass(ping, 500)
    return material_pack(voice, rng, clear_from=12000, clear_to=2500,
                         win=(0, 7, 12, 19), win_gap=0.05)


def pack_glass(rng):
    """Delicate, ringing taps, like a fingernail on a wine glass."""
    def voice(st, dur, decay):
        f = note_hz(st + 12)
        ring = partials(f, [(1.0, 1.0, decay * 3.2), (2.0, 0.18, decay * 1.4),
                            (3.01, 0.3, decay * 1.1), (5.2, 0.14, decay * 0.5)],
                        dur * 2.4)
        mix(ring, [v * 0.25 for v in noise_burst(0.008, 0.0015, rng, hp=6000, lp=15000)])
        return highpass(ring, 700)
    return material_pack(voice, rng, clear_from=14000, clear_to=4000,
                         win=(0, 4, 7, 11, 14), win_gap=0.065, sci_shift=-5)


def pack_wood(rng):
    """Dry woodblock knocks: a hollow tock with almost no sustain."""
    def voice(st, dur, decay):
        f = note_hz(st - 7)
        tock = partials(f, [(1.0, 1.0, decay * 0.55), (2.7, 0.4, decay * 0.25),
                            (5.1, 0.2, decay * 0.12)], dur)
        mix(tock, [v * 0.35 for v in noise_burst(0.015, 0.003, rng, hp=900, lp=5000)])
        return lowpass(tock, 5200)
    return material_pack(voice, rng, clear_from=4500, clear_to=700,
                         win=(0, 7, 12, 16), win_gap=0.075)


def pack_neon(rng):
    """Buzzing synth zaps: a square-wave tube flickering on."""
    def voice(st, dur, decay):
        f = note_hz(st - 5)
        zap = chirp(f * 2.6, f, dur, decay * 1.1, shape='square', curve=0.01)
        mix(zap, [v * 0.35 for v in chirp(f * 2, f * 2.02, dur, decay * 0.8,
                                          shape='saw', curve=0.01)])
        mix(zap, [v * 0.18 for v in noise_burst(0.02, 0.005, rng, hp=3000, lp=9000)])
        return lowpass(zap, 6500)
    return material_pack(voice, rng, clear_from=10000, clear_to=900,
                         win=(0, 7, 12, 19), win_gap=0.055)


# ─── Cinematic drops ──────────────────────────────────────────────────────────
# Mirage and Reckoning are built from film-score ingredients instead of
# pitched blips: low drums, choir vowels, brass, clock ticks and tolling metal,
# each with a short hall tail. Original synthesis only; no sample, melody or
# score is borrowed.

def biquad_bp(buf, freq, q):
    """Band-pass resonator (constant 0 dB peak), used for choir formants."""
    w0 = 2 * math.pi * freq / SR
    alpha = math.sin(w0) / (2 * q)
    a0 = 1 + alpha
    a1 = -2 * math.cos(w0) / a0
    a2 = (1 - alpha) / a0
    b0 = alpha / a0
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in buf:
        y = b0 * (x - x2) - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def fade_out(buf, ms=80):
    n = min(len(buf), int(SR * ms / 1000))
    for i in range(n):
        buf[-1 - i] *= i / n
    return buf


def hall(buf, wet=0.3, size=1.0, tail=0.6):
    """A small Schroeder hall: four combs and two all-passes, plus a tail."""
    n = len(buf) + int(tail * SR)
    src = list(buf) + [0.0] * (n - len(buf))
    acc = [0.0] * n
    for d, fb in ((0.0297, 0.80), (0.0371, 0.78), (0.0411, 0.76), (0.0437, 0.74)):
        dl = max(2, int(d * size * SR))
        line, idx = [0.0] * dl, 0
        for i in range(n):
            y = line[idx]
            line[idx] = src[i] + y * fb
            acc[i] += y
            idx = idx + 1 if idx + 1 < dl else 0
    for d, g in ((0.005, 0.7), (0.0017, 0.7)):
        dl = max(2, int(d * SR))
        line, idx = [0.0] * dl, 0
        for i in range(n):
            wd = line[idx]
            w = acc[i] + g * wd
            line[idx] = w
            acc[i] = -g * w + wd
            idx = idx + 1 if idx + 1 < dl else 0
    return fade_out([src[i] + wet * 0.5 * acc[i] for i in range(n)])


def sub_drum(f, dur, decay, rng, punch=1.0):
    """A big skin drum: the pitch drops onto [f]; two harmonics ride along so
    phone speakers, which cannot play the fundamental, still carry it."""
    n = int(dur * SR)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph += 2 * math.pi * f * (1 + 1.2 * math.exp(-t / 0.018)) / SR
        s = math.sin(ph) + 0.55 * math.sin(2 * ph) + 0.3 * math.sin(3 * ph)
        out.append(s * min(1.0, t / 0.0008) * math.exp(-t / decay))
    mix(out, [v * 0.5 * punch for v in noise_burst(0.02, 0.004, rng, hp=300, lp=2500)])
    return out


def bronze(f, dur, decay):
    return partials(f, [(1.0, 1.0, decay), (2.0, 0.5, decay * 0.7),
                        (2.76, 0.45, decay * 0.55), (5.4, 0.2, decay * 0.3),
                        (8.1, 0.1, decay * 0.2)], dur, attack=0.002)


def iron(f, dur, decay):
    """Struck iron: inharmonic, hard, short."""
    return partials(f, [(1.0, 1.0, decay), (1.5, 0.35, decay * 0.8),
                        (2.32, 0.55, decay * 0.6), (3.8, 0.3, decay * 0.4),
                        (5.9, 0.18, decay * 0.25)], dur, attack=0.0008)


def toll(f, dur):
    """A great bell: a hum below, a minor third in the strike."""
    return partials(f, [(0.5, 0.6, dur * 0.5), (1.0, 1.0, dur * 0.45),
                        (1.19, 0.5, dur * 0.35), (1.5, 0.4, dur * 0.3),
                        (2.0, 0.45, dur * 0.25), (2.51, 0.25, dur * 0.15),
                        (3.9, 0.15, dur * 0.1)], dur, attack=0.003)


VOWELS = {  # (centre Hz, level, Q) for the first three formants
    'aa': [(730, 1.0, 11), (1090, 0.5, 12), (2440, 0.25, 14)],
    'oo': [(300, 1.0, 8), (870, 0.35, 10), (2240, 0.12, 14)],
    'ee': [(270, 1.0, 8), (2290, 0.45, 14), (3010, 0.2, 16)],
}


def choir(freq, dur, vowel, rng, attack=0.3, release=0.4, vib=5.2):
    """One sustained sung voice: a breathy saw through vowel formants."""
    n = int(dur * SR)
    src, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ph = (ph + freq * (1 + 0.006 * math.sin(2 * math.pi * vib * t)
                           * min(1.0, t / 0.4)) / SR) % 1.0
        src.append((2 * ph - 1) * 0.8 + rng.uniform(-1, 1) * 0.08)
    out = [0.0] * n
    for fc, g, q in VOWELS[vowel]:
        for i, v in enumerate(biquad_bp(src, fc, q)):
            out[i] += v * g
    for i in range(n):
        t = i / SR
        out[i] *= min(1.0, t / attack) * min(1.0, (dur - t) / release)
    return out


def brass(freq, dur, rng, swell=0.06, bright=3000, cents=(-9, 0, 9, -4, 6)):
    """Low brass: detuned saws whose filter opens with the swell, then closes."""
    n = int(dur * SR)
    ratios = [2 ** (c / 1200) for c in cents]
    phases = [rng.random() for _ in cents]
    out, y = [], 0.0
    for i in range(n):
        t = i / SR
        s = 0.0
        for k, r in enumerate(ratios):
            phases[k] = (phases[k] + freq * r / SR) % 1.0
            s += 2 * phases[k] - 1
        s /= len(ratios)
        cut = 250 + (bright - 250) * min(1.0, t / swell) * math.exp(
            -max(0.0, t - swell) / (dur * 0.5))
        y += (1 - math.exp(-2 * math.pi * cut / SR)) * (s - y)
        out.append(y * min(1.0, t / (swell * 0.6)) * math.exp(-t / (dur * 0.45)))
    return out


def clock_tick(rng, tock=False):
    """A mechanical clock tick; the tock is a little lower and duller."""
    t = noise_burst(0.02, 0.0025, rng, hp=3500, lp=12000)
    mix(t, [v * 0.7 for v in resonant_click(1900 if tock else 2400, 0.03, 0.004)])
    mix(t, [v * 0.5 for v in resonant_click(200 if tock else 260, 0.05, 0.01)])
    return t


def riser(dur, rng, f0, f1):
    """Noise that brightens and swells into the beat."""
    n = int(dur * SR)
    out, y = [], 0.0
    for i in range(n):
        p = i / n
        rc = 1.0 / (2 * math.pi * f0 * (f1 / f0) ** p)
        y += ((1 / SR) / (rc + 1 / SR)) * (rng.uniform(-1, 1) - y)
        out.append(y * p ** 2.2)
    return out


DUNE_SCALE = [0, 1, 4, 5, 7, 8, 10, 12, 13, 16]   # D phrygian dominant
DOOM_SCALE = [0, 2, 3, 5, 7, 8, 10, 12, 14, 15]   # D natural minor
D2, D3, D4 = -34, -22, -10                        # semitones from C5


def pack_mirage(rng):
    """Dune at night: thumper drums, falling sand, a wailing choir."""
    def thump(st, dur=0.3, decay=0.09, punch=1.0, sand=0.5):
        k = sub_drum(note_hz(D3 + st), dur, decay, rng, punch)
        mix(k, [v * 0.6 for v in sub_drum(note_hz(D2 + st), dur, decay * 1.2, rng, 0.0)])
        mix(k, [v * sand for v in noise_burst(0.07, 0.02, rng, hp=2200, lp=8000)])
        return k

    s = {}
    for d in range(10):
        s[f'digit_{d}'] = normalize(hall(thump(DUNE_SCALE[d]), 0.16, 0.7, 0.25), 0.52)
    op = sub_drum(note_hz(D2), 0.5, 0.16, rng, 1.3)
    mix(op, [v * 0.45 for v in bronze(note_hz(D4), 0.6, 0.35)], at=int(0.012 * SR))
    s['operator'] = normalize(hall(op, 0.3, 0.9, 0.4), 0.58)
    flick = noise_burst(0.06, 0.012, rng, hp=3000, lp=11000)
    mix(flick, [v * 0.4 for v in bronze(note_hz(12), 0.2, 0.05)])
    s['utility'] = normalize(flick, 0.45)
    back = list(reversed(noise_burst(0.14, 0.04, rng, hp=1500, lp=7000)))
    mix(back, [v * 0.7 for v in sub_drum(note_hz(D3 - 5), 0.15, 0.05, rng)],
        at=int(0.1 * SR))
    s['backspace'] = normalize(back, 0.5)
    storm = riser(0.55, rng, 600, 7000)
    mix(storm, sub_drum(note_hz(D2 - 5), 0.7, 0.25, rng, 1.5), at=int(0.4 * SR))
    s['clear'] = normalize(hall(storm, 0.25, 1.0, 0.5), 0.6)
    win = []
    for st, vowel in ((D3, 'oo'), (D3 + 7, 'aa'), (D4, 'aa'), (D4 + 7, 'ee')):
        mix(win, [v * (0.8 if st < D4 else 0.6)
                  for v in choir(note_hz(st), 1.25, vowel, rng, attack=0.22, release=0.5)])
    mix(win, [v * 0.9 for v in thump(0, 0.5, 0.18, 1.4)])
    mix(win, [v * 0.8 for v in thump(7, 0.4, 0.14, 1.2)], at=int(0.17 * SR))
    mix(win, [v * 0.4 for v in bronze(note_hz(D4), 1.0, 0.5)])
    s['success'] = normalize(hall(win, 0.38, 1.2, 0.9), 0.7)
    # The worm: a low growl sliding down, a voice moaning under it.
    n = int(0.8 * SR)
    ph, worm = 0.0, []
    for i in range(n):
        t = i / SR
        ph += 2 * math.pi * (70 - 36 * t / 0.8) / SR
        amp = math.sin(math.pi * min(1.0, t / 0.8)) ** 0.7
        growl = 0.6 + 0.4 * math.sin(2 * math.pi * 23 * t)
        worm.append((math.sin(ph) + 0.6 * math.sin(2 * ph) + 0.45 * math.sin(3 * ph)
                     + 0.3 * math.sin(4 * ph)) * growl * amp)
    mix(worm, [v * 0.6 for v in choir(note_hz(D2 + 12), 0.8, 'oo', rng, 0.15, 0.4)])
    mix(worm, [v * 0.15 for v in noise_burst(0.8, 0.3, rng, hp=100, lp=900)])
    s['error'] = normalize(hall(worm, 0.25, 1.0, 0.4), 0.62)

    # The hold-the-sun egg (played by the screen, not by keys): a thumper that
    # speeds up under a rising rumble, then the worm rising out of the sand
    # with a warm, enormous hum rather than a snarl.
    charge = []
    gap, at, k = 0.55, 0.0, 0
    while at < 2.1:
        mix(charge, [v * (0.5 + 0.5 * at / 2.2) for v in
                     sub_drum(note_hz(D2 + (0 if k % 2 == 0 else -5)), 0.28, 0.09, rng, 1.2)],
            at=int(at * SR))
        gap = max(0.1, gap * 0.86)
        at += gap
        k += 1
    mix(charge, [v * 0.5 for v in riser(2.2, rng, 300, 5000)])
    s['worm_charge'] = normalize(charge, 0.62)
    rise = sub_drum(note_hz(D2 - 5), 1.6, 0.5, rng, 1.8)
    mix(rise, [v * 0.7 for v in riser(1.4, rng, 700, 3500)])
    mix(rise, [v * 0.6 * math.sin(math.pi * i / int(4.5 * SR)) ** 0.8 for i, v in
               enumerate(noise_burst(4.5, 9.0, rng, hp=700, lp=4500))], at=int(0.2 * SR))
    for st, vowel, lvl in ((D2 + 12, 'oo', 1.0), (D3 + 7, 'aa', 0.75), (D4, 'oo', 0.5)):
        mix(rise, [v * lvl for v in choir(note_hz(st), 5.0, vowel, rng,
                                          attack=1.4, release=1.6, vib=3.6)], at=int(0.5 * SR))
    mix(rise, [v * 0.6 for v in brass(note_hz(D2), 4.5, rng, swell=1.4, bright=1500)],
        at=int(0.6 * SR))
    for k, st in enumerate((D4, D4 + 7, D4 + 12)):
        mix(rise, [v * 0.35 for v in bronze(note_hz(st), 1.6, 0.8)], at=int((2.5 + 0.12 * k) * SR))
    s['worm_rise'] = normalize(hall(rise, 0.4, 1.4, 1.6), 0.72)

    def tone(st, dur, decay):
        p = partials(note_hz(st - 5), [(1.0, 1.0, decay * 2), (2.0, 0.25, decay * 1.2),
                                       (3.0, 0.1, decay * 0.7)], dur * 1.4, attack=0.004)
        mix(p, [v * 0.25 for v in noise_burst(dur, decay, rng, hp=3000, lp=8000)])
        return p
    s.update(scientific_sounds(tone))
    return s


def pack_reckoning(rng):
    """The last minute: clock ticks, struck iron, brass, a tolling bell."""
    def strike(st, dur=0.26, decay=0.07, tock=False):
        k = clock_tick(rng, tock)
        mix(k, [v * 0.9 for v in iron(note_hz(D3 + st), dur, decay)], at=int(0.003 * SR))
        mix(k, [v * 0.6 for v in sub_drum(note_hz(D2 + st), 0.18, 0.05, rng, 0.8)])
        return k

    s = {}
    for d in range(10):
        s[f'digit_{d}'] = normalize(hall(strike(DOOM_SCALE[d], tock=d % 2 == 1), 0.14, 0.6, 0.2), 0.52)
    op = brass(note_hz(D2), 0.42, rng, swell=0.05, bright=2600)
    mix(op, [v * 0.7 for v in brass(note_hz(D2 + 7), 0.42, rng, swell=0.05, bright=2600)])
    mix(op, sub_drum(note_hz(D2), 0.3, 0.09, rng, 1.2))
    mix(op, [v * 0.5 for v in iron(note_hz(D3), 0.3, 0.1)])
    s['operator'] = normalize(hall(op, 0.25, 0.9, 0.35), 0.58)
    tk = clock_tick(rng)
    mix(tk, [v * 0.35 for v in iron(note_hz(12), 0.12, 0.03)])
    s['utility'] = normalize(tk, 0.45)
    back = list(reversed(noise_burst(0.12, 0.03, rng, hp=1200, lp=8000)))
    mix(back, clock_tick(rng, True), at=int(0.11 * SR))
    s['backspace'] = normalize(back, 0.5)
    rise = riser(0.5, rng, 300, 6000)
    mix(rise, sub_drum(note_hz(D2), 0.8, 0.28, rng, 1.6), at=int(0.45 * SR))
    mix(rise, [v * 0.6 for v in iron(note_hz(D2 + 12), 0.7, 0.3)], at=int(0.45 * SR))
    s['clear'] = normalize(hall(rise, 0.28, 1.0, 0.5), 0.6)
    win = []
    for st, lvl in ((D2, 1.0), (D2 + 7, 0.85), (D3, 0.9), (D3 + 3, 0.65)):
        mix(win, [v * lvl for v in brass(note_hz(st), 1.1, rng, swell=0.12, bright=3400)])
    mix(win, [v * 1.2 for v in sub_drum(note_hz(D2 - 5), 1.0, 0.3, rng, 1.8)])
    mix(win, [v * 0.35 for v in bronze(note_hz(D4 + 12), 1.0, 0.45)], at=int(0.06 * SR))
    s['success'] = normalize(hall(win, 0.34, 1.2, 0.9), 0.7)
    err = toll(note_hz(D3), 1.1)
    mix(err, toll(note_hz(D3 - 6), 1.0), at=int(0.36 * SR))
    mix(err, [v * 0.8 for v in brass(note_hz(D2 - 6), 0.7, rng, swell=0.08, bright=1800)])
    mix(err, sub_drum(note_hz(D2 - 6), 0.5, 0.2, rng, 1.4))
    s['error'] = normalize(hall(err, 0.3, 1.1, 0.5), 0.62)

    # The hold-the-clock egg (not keys, played by the screen itself): a charge
    # that climbs three octaves under accelerating ticks, a boom that tolls,
    # and the low voice that arrives with the mask.
    n = int(2.2 * SR)
    ph = [0.0, 0.0, 0.0]
    charge = []
    for i in range(n):
        p = i / n
        f = note_hz(D2) * 8 ** p
        v = 0.0
        for k, det in enumerate((0.994, 1.0, 1.007)):
            ph[k] = (ph[k] + f * det / SR) % 1.0
            v += 2 * ph[k] - 1
        charge.append(v / 3 * (0.15 + 0.85 * p ** 1.6))
    charge = lowpass(charge, 3500)
    mix(charge, [v * 0.8 for v in riser(2.2, rng, 400, 9000)])
    gap, at, k = 0.34, 0.0, 0
    while at < 2.15:
        mix(charge, [v * (0.4 + 0.6 * at / 2.2) for v in clock_tick(rng, k % 2 == 1)],
            at=int(at * SR))
        gap = max(0.05, gap * 0.9)
        at += gap
        k += 1
    s['warp_charge'] = normalize(charge, 0.62)
    boom = sub_drum(note_hz(D2 - 5), 1.8, 0.5, rng, 2.0)
    mix(boom, [v * 0.9 for v in noise_burst(0.9, 0.22, rng, hp=120, lp=7000)])
    mix(boom, [v * 0.8 for v in toll(note_hz(D3), 2.6)], at=int(0.04 * SR))
    mix(boom, [v * 0.6 for v in iron(note_hz(D2), 1.6, 0.6)])
    mix(boom, [v * 0.7 for v in brass(note_hz(D2), 2.0, rng, swell=0.05, bright=3600)])
    s['warp_boom'] = normalize(hall(boom, 0.4, 1.3, 1.4), 0.75)
    voice = []
    for st, vowel, lvl in ((D3, 'oo', 1.0), (D3 + 7, 'aa', 0.7), (D4, 'oo', 0.5)):
        mix(voice, [v * lvl for v in choir(note_hz(st), 2.8, vowel, rng,
                                           attack=0.9, release=1.0, vib=4.2)])
    mix(voice, [v * 0.8 for v in brass(note_hz(D2), 2.6, rng, swell=0.7, bright=1800)])
    mix(voice, [v * 1.1 for v in sub_drum(note_hz(D2), 1.2, 0.4, rng, 1.2)],
        at=int(0.9 * SR))
    s['warp_voice'] = normalize(hall(voice, 0.4, 1.3, 1.2), 0.7)

    def tone(st, dur, decay):
        return lowpass(iron(note_hz(st - 12), dur * 1.4, decay * 1.5), 7000)
    s.update(scientific_sounds(tone))
    return s


# Mechanical: three switch types. Keys are unpitched, with a tiny per-key
# variation like real boards, so every digit differs slightly but none sings.
#   clicky   sharp click on the way down, then the bottom-out
#   tactile  soft bump, then a deep "thock"
#   linear   one smooth, muted bottom-out

def mech_key(rng, kind, weight=1.0, tune=1.0):
    out = []
    if kind == 'clicky':
        # Click jacket snapping, high and thin.
        mix(out, [v * 0.9 for v in noise_burst(0.012, 0.0016, rng, hp=4200, lp=13000)])
        mix(out, [v * 0.55 for v in resonant_click(5200 * tune, 0.012, 0.0022)])
        # Bottom-out a moment later.
        at = int(0.021 * SR)
        mix(out, [v * 0.8 * weight for v in noise_burst(0.03, 0.006, rng, hp=900, lp=6000)], at=at)
        mix(out, [v * 0.6 * weight for v in resonant_click(1150 * tune, 0.05, 0.011)], at=at)
        mix(out, [v * 0.3 * weight for v in resonant_click(420 * tune, 0.06, 0.018)], at=at)
    elif kind == 'tactile':
        # Rounded bump, no click.
        mix(out, [v * 0.35 for v in noise_burst(0.014, 0.004, rng, hp=1200, lp=4200)])
        at = int(0.017 * SR)
        mix(out, [v * 0.7 * weight for v in noise_burst(0.035, 0.008, rng, hp=350, lp=3200)], at=at)
        mix(out, [v * 0.95 * weight for v in resonant_click(300 * tune, 0.09, 0.024)], at=at)
        mix(out, [v * 0.4 * weight for v in resonant_click(760 * tune, 0.05, 0.012)], at=at)
    else:  # linear
        mix(out, [v * 0.55 * weight for v in noise_burst(0.03, 0.007, rng, hp=250, lp=2300)])
        mix(out, [v * 1.0 * weight for v in resonant_click(210 * tune, 0.1, 0.028)])
        mix(out, [v * 0.3 * weight for v in resonant_click(520 * tune, 0.05, 0.013)])
        out = lowpass(out, 2600)
    return out


def pack_mech(kind):
    def build(rng):
        def key(weight=1.0, tune=1.0):
            return mech_key(rng, kind, weight=weight, tune=tune)

        s = {}
        for d in range(10):
            s[f'digit_{d}'] = normalize(key(tune=1.0 + (d - 4.5) * 0.012 + rng.uniform(-0.02, 0.02)), 0.5)
        # Bigger keys: stabilised, lower and heavier.
        s['operator'] = normalize(key(weight=1.5, tune=0.82), 0.56)
        s['utility'] = normalize(key(weight=0.8, tune=1.12), 0.44)
        s['backspace'] = normalize(key(weight=1.2, tune=0.9), 0.48)
        # Clear: a quick roll across a row, then the spacebar.
        roll = []
        for k in range(5):
            mix(roll, [v * (0.5 + 0.08 * k) for v in key(weight=0.7, tune=1.1 - k * 0.03)],
                at=int(k * 0.034 * SR))
        mix(roll, key(weight=1.8, tune=0.7), at=int(0.2 * SR))
        s['clear'] = normalize(roll, 0.55)
        # Success: Enter, landing with a little spring ping.
        win = key(weight=1.7, tune=0.76)
        mix(win, [v * 0.25 for v in partials(1760, [(1.0, 1.0, 0.09), (2.76, 0.4, 0.05)], 0.3)],
            at=int(0.03 * SR))
        s['success'] = normalize(win, 0.62)
        err = key(weight=1.6, tune=0.72)
        mix(err, key(weight=1.6, tune=0.7), at=int(0.1 * SR))
        s['error'] = normalize(err, 0.55)
        # Scientific keys: the same switch, pitched a little by figure.
        s.update(scientific_sounds(
            lambda st, dur, decay: key(weight=0.9, tune=2 ** ((st - 12) / 30))))
        return s
    return build


MATERIAL_PACKS = [
    # Clay and candy were retired; None keeps their slots because the seed
    # is 100 + index and moving the rest would change their sounds.
    None, ('chrome', pack_chrome), ('glass', pack_glass),
    ('wood', pack_wood), None, ('neon', pack_neon),
    ('mech_clicky', pack_mech('clicky')),
    ('mech_tactile', pack_mech('tactile')),
    ('mech_linear', pack_mech('linear')),
    # Appended last: the seed is 100 + index, so order must never change.
    ('mirage', pack_mirage), ('reckoning', pack_reckoning),
]


# ─── Scientific keys ──────────────────────────────────────────────────────────
# One short figure per kind of key, voiced by each pack, so the tray is
# readable by ear: trig waves up and back, logs settle on a calm interval,
# powers climb, roots step down, brackets open upward and close downward,
# constants sparkle, ! knocks three times, and 2nd climbs or drops.

def scientific_sounds(tone):
    """[tone](semitone, dur, decay) is the pack's voice."""
    def seq(notes, gap, dur=0.09, decay=0.03):
        out = []
        for k, (st, level) in enumerate(notes):
            mix(out, [v * level for v in tone(st, dur, decay)], at=int(k * gap * SR))
        return out

    s = {}
    s['trig'] = normalize(seq([(7, 0.8), (14, 1.0), (7, 0.7)], 0.034), 0.5)
    log = tone(0, 0.14, 0.05)
    mix(log, [v * 0.8 for v in tone(7, 0.14, 0.05)])
    s['log'] = normalize(log, 0.5)
    s['power'] = normalize(seq([(7, 0.7), (12, 0.85), (19, 1.0)], 0.028), 0.5)
    s['root'] = normalize(seq([(19, 1.0), (12, 0.8)], 0.04, dur=0.11, decay=0.035), 0.5)
    s['bracket_open'] = normalize(seq([(7, 0.75), (12, 1.0)], 0.024, dur=0.07, decay=0.022), 0.48)
    s['bracket_close'] = normalize(seq([(12, 1.0), (7, 0.75)], 0.024, dur=0.07, decay=0.022), 0.48)
    s['constant'] = normalize(seq([(24, 1.0), (31, 0.5), (36, 0.3)], 0.03, dur=0.2, decay=0.06), 0.5)
    s['factorial'] = normalize(seq([(12, 0.6), (12, 0.75), (14, 1.0)], 0.03, dur=0.06, decay=0.018), 0.5)
    s['shift_on'] = normalize(seq([(14, 0.8), (21, 1.0)], 0.035, dur=0.07, decay=0.022), 0.45)
    s['shift_off'] = normalize(seq([(21, 1.0), (14, 0.8)], 0.035, dur=0.07, decay=0.022), 0.45)
    return s


# ─── Shared sounds ────────────────────────────────────────────────────────────
# Played the same whichever pack is chosen.
#   launch.wav  the typewriter carriage-return "skrr" (its clear sound)
#   detent.wav  one notch of a swipe-to-step control, like a slider
#               clicking into place

def detent(rng):
    tick = noise_burst(0.018, 0.0025, rng, hp=2500, lp=9000)
    mix(tick, [v * 0.6 for v in resonant_click(2300, 0.018, 0.003)])
    mix(tick, [v * 0.35 for v in resonant_click(720, 0.025, 0.006)])
    m = max(abs(v) for v in tick)
    return [v / m * 0.6 for v in tick]


def main():
    rng = random.Random(42)
    for name, builder in [('pop', pack_pop), ('mellow', pack_mellow), ('typewriter', pack_typewriter)]:
        for sfx, buf in builder(rng).items():
            write_wav(os.path.join(ROOT, name, f'{sfx}.wav'), fade_edges(buf))
        print(f'pack {name}: done')
    shutil.copyfile(os.path.join(ROOT, 'typewriter', 'clear.wav'),
                    os.path.join(ROOT, 'launch.wav'))
    write_wav(os.path.join(ROOT, 'detent.wav'), fade_edges(detent(random.Random(9)), ms=1))
    print('shared sounds: done')
    # Material packs get their own seeds, so adding one never changes the
    # packs above.
    for k, entry in enumerate(MATERIAL_PACKS):
        if entry is None:
            continue
        name, builder = entry
        for sfx, buf in builder(random.Random(100 + k)).items():
            write_wav(os.path.join(ROOT, name, f'{sfx}.wav'), fade_edges(buf))
        print(f'material {name}: done')


if __name__ == '__main__':
    main()
