"""Synthesizes the clear, combo, fever and perfect-clear sound effects into assets/sfx/.

Every pitch is rendered into its own file (no pitch_scale at runtime, which made high combos
shrill) and every file peaks at PEAK_DB, so a clear, a combo and a fever or perfect sound can
overlap without clipping.

  clear_1..clear_4   line clear by number of lines (soft pop + a growing major chord)
  combo_1..combo_12  mallet notes climbing a pentatonic scale, one per combo step
  fever              riser into a bright chord (fever starts)
  perfect            sparkling arpeggio over a low boom (board emptied)
  b_*                블록 기사단 battle sounds (played quietly, see LaneBattle._sfx):
                     b_hit, b_arrow, b_magic, b_death, b_cannon, b_horn, b_roar, b_summon, b_castle

Usage: python tools/generate_sfx.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
PEAK_DB = -6.0
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "sfx"))

random.seed(7)


def note(name):
    """'C5' -> Hz (A4 = 440)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    return 440.0 * 2 ** ((names[name[0]] + 12 * (int(name[-1]) - 4)) / 12)


def silence(sec):
    return [0.0] * int(RATE * sec)


def mix(dst, src, at=0.0, gain=1.0):
    start = int(at * RATE)
    if len(dst) < start + len(src):
        dst.extend([0.0] * (start + len(src) - len(dst)))
    for i, v in enumerate(src):
        dst[start + i] += v * gain
    return dst


def mallet(freq, dur=0.5, bright=0.35):
    """Marimba-like note: soft attack, the upper partials die out faster than the fundamental."""
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.004)
        v = math.sin(2 * math.pi * freq * t) * math.exp(-t * 6.0)
        v += bright * math.sin(2 * math.pi * freq * 4.0 * t) * math.exp(-t * 28.0)
        v += 0.18 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-t * 14.0)
        out.append(v * attack)
    return out


def bell(freq, dur=0.9):
    """Glassy bell for sparkle: inharmonic partials with long, gentle decay."""
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.002)
        v = (math.sin(2 * math.pi * freq * t) * math.exp(-t * 4.0)
             + 0.4 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t * 7.0)
             + 0.2 * math.sin(2 * math.pi * freq * 5.4 * t) * math.exp(-t * 12.0))
        out.append(v * attack)
    return out


def pop(dur=0.12):
    """Soft 'pop' for a clearing line: a short low thump plus a quick filtered noise puff."""
    n = int(RATE * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / RATE
        thump = math.sin(2 * math.pi * (180 - 900 * t) * t) * math.exp(-t * 40)
        lp += (random.uniform(-1, 1) - lp) * 0.25
        out.append(0.8 * thump + 0.5 * lp * math.exp(-t * 55))
    return out


def riser(dur=0.55):
    """Rising whoosh: noise through a sweeping resonant filter, getting louder."""
    n = int(RATE * dur)
    out = []
    low = band = 0.0
    for i in range(n):
        p = i / n
        f = 300 + 3200 * p * p
        k = 2 * math.sin(math.pi * f / RATE)
        x = random.uniform(-1, 1)
        low += k * band
        high = x - low - 0.35 * band
        band += k * high
        tone = 0.35 * math.sin(2 * math.pi * (220 + 660 * p) * (i / RATE))
        out.append((0.6 * band + tone) * (p ** 1.6))
    return out


def reverb(x, mix_amount=0.28, room=0.78):
    """Small Schroeder reverb (4 combs + 2 allpasses) for a soft tail."""
    tail = int(RATE * 0.35)
    x = x + [0.0] * tail
    combs = [1557, 1617, 1491, 1422]
    wet = [0.0] * len(x)
    for d in combs:
        buf = [0.0] * d
        idx = 0
        for i, v in enumerate(x):
            y = buf[idx]
            buf[idx] = v + y * room
            idx = (idx + 1) % d
            wet[i] += y * 0.25
    for d, g in ((225, 0.5), (556, 0.5)):
        buf = [0.0] * d
        idx = 0
        for i, v in enumerate(wet):
            y = buf[idx]
            out = -v + y
            buf[idx] = v + y * g
            idx = (idx + 1) % d
            wet[i] = out
    return [(1 - mix_amount) * a + mix_amount * b for a, b in zip(x, wet)]


def fade_tail(x, sec=0.05):
    n = min(len(x), int(RATE * sec))
    for i in range(n):
        x[len(x) - n + i] *= 1 - i / n
    return x


def write(name, x, peak_db=PEAK_DB):
    x = fade_tail(x)
    peak = max(abs(v) for v in x) or 1.0
    scale = (10 ** (peak_db / 20)) / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in x))
    print(f"{name}.wav  {len(x) / RATE:.2f}s")


def main():
    # Line clears: a pop and a major chord that grows with the number of lines
    chord = ["C4", "E4", "G4", "C5", "E5"]
    for lines in range(1, 5):
        x = pop()
        for k in range(min(lines + 1, len(chord))):
            mix(x, mallet(note(chord[k]), 0.55, 0.25), at=0.01 + 0.025 * k, gain=0.55)
        if lines >= 4:
            mix(x, bell(note("C6"), 0.8), at=0.08, gain=0.3)
        write(f"clear_{lines}", reverb(x, 0.22))

    # Combos: one mallet note per step, climbing a major pentatonic scale, with an octave shimmer
    scale = ["E4", "G4", "A4", "C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6"]
    for i, name in enumerate(scale, 1):
        f = note(name)
        x = mallet(f, 0.6, 0.3)
        mix(x, mallet(f * 2, 0.35, 0.15), at=0.045, gain=0.28)
        write(f"combo_{i}", reverb(x, 0.3))

    # Fever: whoosh up into a bright chord
    x = riser()
    for k, name in enumerate(["C5", "E5", "G5", "C6"]):
        mix(x, mallet(note(name), 0.9, 0.35), at=0.52 + 0.02 * k, gain=0.5)
    mix(x, bell(note("E6"), 1.0), at=0.56, gain=0.25)
    write("fever", reverb(x, 0.3), PEAK_DB + 1.0)

    # Perfect clear: low boom and a sparkling rising arpeggio
    x = []
    boom = [math.sin(2 * math.pi * (70 - 20 * (i / RATE)) * (i / RATE)) * math.exp(-(i / RATE) * 7) for i in range(int(RATE * 0.6))]
    mix(x, boom, gain=0.9)
    for k, name in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"]):
        mix(x, bell(note(name), 0.9), at=0.05 + 0.07 * k, gain=0.35)
    write("perfect", reverb(x, 0.32), PEAK_DB + 1.0)
    battle_sounds()


def noise_lp(dur, cutoff_start, cutoff_end, decay):
    """Noise through a one-pole low-pass whose cutoff sweeps, with an exponential decay."""
    n = int(RATE * dur)
    out, lp = [], 0.0
    for i in range(n):
        p = i / n
        k = cutoff_start + (cutoff_end - cutoff_start) * p
        lp += (random.uniform(-1, 1) - lp) * k
        out.append(lp * math.exp(-(i / RATE) * decay))
    return out


def sweep(f0, f1, dur, decay, shape="sin"):
    n = int(RATE * dur)
    out, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (i / n)
        ph += 2 * math.pi * f / RATE
        v = math.sin(ph) if shape == "sin" else (2 * ((ph / (2 * math.pi)) % 1.0) - 1)
        out.append(v * math.exp(-t * decay) * min(1.0, t / 0.003))
    return out


def battle_sounds():
    random.seed(11)
    # Melee hit: low thump + a short bright click
    x = sweep(160, 60, 0.14, 30)
    mix(x, noise_lp(0.05, 0.6, 0.2, 70), gain=0.6)
    write("b_hit", x)
    # Arrow: quick airy whoosh with a tick at the end
    x = noise_lp(0.12, 0.08, 0.5, 18)
    mix(x, sweep(2400, 1800, 0.02, 120), at=0.1, gain=0.5)
    write("b_arrow", x)
    # Magic: sparkly zap falling in pitch
    x = sweep(1400, 300, 0.25, 12)
    mix(x, bell(note("E6"), 0.25), gain=0.25)
    write("b_magic", x)
    # Death: soft poof + falling blip
    x = noise_lp(0.25, 0.3, 0.04, 14)
    mix(x, sweep(700, 180, 0.16, 16), gain=0.5)
    write("b_death", x)
    # Cannon: big boom with a crackling tail
    x = sweep(90, 35, 0.8, 5)
    mix(x, noise_lp(0.6, 0.5, 0.03, 6), gain=0.7)
    write("b_cannon", reverb(x, 0.25), PEAK_DB + 1.0)
    # Horn: two low brassy notes (big wave coming)
    x = []
    for at, f in ((0.0, note("D3")), (0.38, note("A3"))):
        n = sweep(f, f, 0.5, 1.5, "saw")
        for i in range(len(n)):
            n[i] *= min(1.0, i / (RATE * 0.05))
        mix(x, n, at=at, gain=0.6)
    write("b_horn", reverb(x, 0.3))
    # Roar: growling low noise with a wobble (boss)
    n = int(RATE * 0.9)
    x, lp = [], 0.0
    for i in range(n):
        t = i / RATE
        lp += (random.uniform(-1, 1) - lp) * 0.08
        growl = math.sin(2 * math.pi * (85 + 25 * math.sin(2 * math.pi * 9 * t)) * t)
        env = min(1.0, t / 0.08) * math.exp(-max(0.0, t - 0.4) * 5)
        x.append((0.7 * lp + 0.5 * growl) * env)
    write("b_roar", reverb(x, 0.25))
    # Summon: tiny rising two-note chime
    x = mallet(note("G5"), 0.18, 0.2)
    mix(x, mallet(note("D6"), 0.2, 0.2), at=0.06, gain=0.8)
    write("b_summon", x)
    # Castle hit: heavy stone thud
    x = sweep(110, 45, 0.3, 14)
    mix(x, noise_lp(0.2, 0.25, 0.05, 20), gain=0.7)
    write("b_castle", x)


if __name__ == "__main__":
    main()
