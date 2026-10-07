"""Procedurally synthesizes PopCalc's sound effects.

Everything is generated from math, so the audio is original and
license-free. Re-run to regenerate:

    python tool/generate_sounds.py

Output: assets/sounds/<pack>/*.wav
"""

import math
import os
import random
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
    s.update(advanced_sounds(
        lambda st, dur, decay: bloop(note_hz(st), dur=dur, drop=0.5, decay=decay),
        random.Random(101), lambda dur, r: whoosh(dur, r, 1800, 7000)))
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
    s.update(advanced_sounds(
        lambda st, dur, decay: marimba(note_hz(st - 5), dur=dur * 2, decay=decay * 2.2),
        random.Random(102), lambda dur, r: whoosh(dur, r, 1200, 4500)))
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

    # Typewriter keeps its mechanics: pitched key strikes, the carriage
    # bell for constants, and a platen ratchet for swaps.
    def strike(st, dur, decay):
        return key(1100 * 2 ** (st / 24))

    def ratchet(dur, r):
        out = []
        for k in range(int(dur / 0.025)):
            mix(out, noise_burst(0.02, 0.004, r, hp=2500), at=int(k * 0.025 * SR))
        return out

    adv = advanced_sounds(strike, rng, ratchet)
    bell_ping = key(1500)
    mix(bell_ping, [v * 0.7 for v in bell(2637, dur=0.5, decay=0.15)], at=int(0.02 * SR))
    adv['constant'] = normalize(bell_ping, 0.5)
    s.update(adv)
    return s


# ─── Advanced mode (scientific keys + unit converter) ─────────────────────────
# Shared shapes, voiced per pack. Each gesture has a musical meaning:
# openers rise and closers fall, powers slide up, constants sparkle, 2nd
# and the mode switch play mirrored up/down figures, and swap flips two
# notes around a whoosh. Category taps are one note the app re-pitches
# along the pentatonic scale, so scrolling the tabs plays a little run.

def advanced_sounds(tone, rng, air):
    """[tone](semitone, dur, decay) is the pack's voice; [air] its texture."""
    s = {}
    fn = []
    mix(fn, tone(12, 0.09, 0.03))
    mix(fn, [v * 0.8 for v in tone(19, 0.12, 0.04)], at=int(0.04 * SR))
    s['function'] = normalize(fn, 0.5)

    s['bracket_open'] = normalize(mix(tone(7, 0.06, 0.02),
                                      [v * 0.7 for v in tone(14, 0.08, 0.03)], at=int(0.025 * SR)), 0.45)
    s['bracket_close'] = normalize(mix(tone(14, 0.06, 0.02),
                                       [v * 0.7 for v in tone(7, 0.08, 0.03)], at=int(0.025 * SR)), 0.45)

    sparkle = tone(24, 0.25, 0.07)
    mix(sparkle, [v * 0.45 for v in tone(31, 0.25, 0.06)], at=int(0.03 * SR))
    mix(sparkle, [v * 0.25 for v in tone(36, 0.2, 0.05)], at=int(0.06 * SR))
    s['constant'] = normalize(sparkle, 0.5)

    pw = []
    for k, st in enumerate([0, 7, 12, 19]):
        mix(pw, [v * (0.55 + 0.15 * k) for v in tone(st, 0.08, 0.025)], at=int(k * 0.022 * SR))
    s['power'] = normalize(pw, 0.5)

    s['shift_on'] = normalize(mix(tone(14, 0.05, 0.015),
                                  tone(21, 0.07, 0.025), at=int(0.035 * SR)), 0.42)
    s['shift_off'] = normalize(mix(tone(21, 0.05, 0.015),
                                   tone(14, 0.07, 0.025), at=int(0.035 * SR)), 0.42)

    mode_on, mode_off = [], []
    for k, st in enumerate([0, 7, 12, 16]):
        mix(mode_on, [v * (0.6 + 0.12 * k) for v in tone(st, 0.18, 0.06)], at=int(k * 0.045 * SR))
    for k, st in enumerate([16, 12, 7, 0]):
        mix(mode_off, [v * (0.95 - 0.12 * k) for v in tone(st, 0.18, 0.06)], at=int(k * 0.045 * SR))
    s['mode_on'] = normalize(mode_on, 0.55)
    s['mode_off'] = normalize(mode_off, 0.5)

    sw = [v * 0.5 for v in air(0.22, rng)]
    mix(sw, tone(12, 0.1, 0.035), at=int(0.02 * SR))
    mix(sw, tone(7, 0.14, 0.05), at=int(0.11 * SR))
    s['swap'] = normalize(sw, 0.5)

    s['category'] = normalize(tone(12, 0.06, 0.018), 0.38)

    pick = []
    mix(pick, tone(7, 0.08, 0.025))
    mix(pick, tone(12, 0.14, 0.05), at=int(0.05 * SR))
    s['unit_pick'] = normalize(pick, 0.45)
    return s


def main():
    rng = random.Random(42)
    for name, builder in [('pop', pack_pop), ('mellow', pack_mellow), ('typewriter', pack_typewriter)]:
        for sfx, buf in builder(rng).items():
            write_wav(os.path.join(ROOT, name, f'{sfx}.wav'), fade_edges(buf))
        print(f'pack {name}: done')


if __name__ == '__main__':
    main()
