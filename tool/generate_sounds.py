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


def pack_clay(rng):
    """Soft, damp thumps: a dull body with a short squish, no ring."""
    def voice(st, dur, decay):
        f = note_hz(st - 17)
        body = chirp(f * 1.9, f, dur, decay * 0.9, curve=0.009)
        mix(body, [v * 0.22 for v in noise_burst(0.03, 0.008, rng, hp=300, lp=1400)])
        return lowpass(body, 1500)
    return material_pack(voice, rng, clear_from=2600, clear_to=500,
                         win=(0, 4, 7, 12), win_gap=0.07)


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


def pack_candy(rng):
    """Sweet, bouncy blips that hop upward, like popping candy."""
    def voice(st, dur, decay):
        f = note_hz(st + 7)
        pop = chirp(f * 0.62, f, dur, decay, curve=0.016)
        mix(pop, [v * 0.3 for v in chirp(f * 1.3, f * 2, dur * 0.7, decay * 0.5,
                                         curve=0.02)], at=int(0.012 * SR))
        return pop
    return material_pack(voice, rng, clear_from=9000, clear_to=2000,
                         win=(0, 4, 7, 12, 16), win_gap=0.05)


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
    ('clay', pack_clay), ('chrome', pack_chrome), ('glass', pack_glass),
    ('wood', pack_wood), ('candy', pack_candy), ('neon', pack_neon),
    ('mech_clicky', pack_mech('clicky')),
    ('mech_tactile', pack_mech('tactile')),
    ('mech_linear', pack_mech('linear')),
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
    for k, (name, builder) in enumerate(MATERIAL_PACKS):
        for sfx, buf in builder(random.Random(100 + k)).items():
            write_wav(os.path.join(ROOT, name, f'{sfx}.wav'), fade_edges(buf))
        print(f'material {name}: done')


if __name__ == '__main__':
    main()
