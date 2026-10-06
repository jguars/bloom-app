"""Synthesise Bloom's sound effects (44.1 kHz mono 16-bit WAV) with numpy/scipy.

One warm palette for the whole app: wooden mallets, soft bells and filtered
noise, a touch of small-room reverb, peaks well below full scale so they sit
under the user's music. Everything is deterministic (fixed seed).

Run: python3 tools/sfx/make_sfx.py assets/sfx
"""
import sys
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.004, decay=6.0):
    t = t_axis(dur)
    return np.minimum(1.0, t / attack) * np.exp(-decay * t)


def tone(freq, dur, partials=((1, 1.0),), decay=6.0, attack=0.004, glide=0.0):
    """A pitched note. `glide` bends the pitch by that many semitones over the note."""
    t = t_axis(dur)
    f = freq * 2 ** (glide * t / dur / 12)
    phase = 2 * np.pi * np.cumsum(f) / SR
    v = sum(a * np.sin(m * phase) for m, a in partials)
    return v * env(dur, attack, decay)


def noise(dur, lo, hi, decay=10.0, attack=0.003):
    b, a = signal.butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return signal.lfilter(b, a, rng.uniform(-1, 1, int(SR * dur))) * env(dur, attack, decay)


def place(track, clip, at):
    s = int(SR * at)
    end = s + len(clip)
    if end > len(track):
        track = np.pad(track, (0, end - len(track)))
    track[s:end] += clip
    return track


def seq(*items, total=None):
    """items: (start_seconds, clip)."""
    n = max(int(SR * at) + len(c) for at, c in items)
    out = np.zeros(max(n, int(SR * (total or 0))))
    for at, c in items:
        out = place(out, c, at)
    return out


def room(x, size=0.18, wet=0.18):
    """A small, soft room: convolve with decaying filtered noise."""
    ir = noise(size, 300, 6000, decay=18 / size * 0.4, attack=0.001)
    ir[0] = 1.0
    y = signal.fftconvolve(x, ir)[: len(x) + int(SR * size)]
    y = np.pad(x, (0, len(y) - len(x))) * (1 - wet) + y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x)) * wet
    return y


def write(path, x, peak=0.5):
    x = np.asarray(x, dtype=np.float64)
    fade = int(SR * 0.012)
    x[-fade:] *= np.linspace(1, 0, fade)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(path, SR, (x * 32767).astype(np.int16))


MARIMBA = ((1, 1.0), (4, 0.22), (9.9, 0.04))
BELL = ((1, 1.0), (2.76, 0.32), (5.4, 0.1), (8.9, 0.04))
WOOD = ((1, 1.0), (2.3, 0.35), (4.1, 0.08))

# Notes (Hz): a C-major-pentatonic world, so every sound agrees with the others.
C5, D5, E5, G5, A5 = 523.25, 587.33, 659.25, 783.99, 880.0
C6, D6, E6, G6, A6, C7 = 1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0


SOUNDS = {
    # UI
    'tap': lambda: seq((0, tone(1240, 0.06, WOOD, decay=70)), (0, noise(0.03, 2500, 9000, decay=160) * 0.25)),
    'whoosh': lambda: (lambda n: n * np.sin(np.linspace(0, np.pi, len(n))) ** 2)(
        signal.lfilter(*signal.butter(2, 0.12, 'low'), rng.uniform(-1, 1, int(SR * 0.32))) * np.linspace(0.3, 1, int(SR * 0.32))),
    'swipe': lambda: (lambda n: n * np.sin(np.linspace(0, np.pi, len(n))))(noise(0.2, 900, 4000, decay=4)),
    'nope': lambda: seq((0, tone(330, 0.12, WOOD, decay=30)), (0.07, tone(262, 0.16, WOOD, decay=26))),
    # Session
    'tick': lambda: seq((0, tone(880, 0.09, WOOD, decay=45)), (0, noise(0.05, 3000, 9000, decay=200) * 0.35)),
    'go': lambda: room(seq((0, tone(C6, 0.5, BELL, decay=7)), (0.06, tone(G6, 0.45, BELL, decay=8) * 0.6), (0.12, tone(C7, 0.4, BELL, decay=9) * 0.4))),
    'done': lambda: room(seq((0, tone(G5, 0.4, MARIMBA, decay=9)), (0.12, tone(C6, 0.6, MARIMBA, decay=7)))),
    # Clover
    'pop': lambda: seq((0, tone(600, 0.12, ((1, 1.0), (2, 0.2)), decay=30, glide=7)), (0.0, noise(0.02, 1500, 6000, decay=250) * 0.3)),
    'purr': lambda: (lambda t: (signal.lfilter(*signal.butter(2, [60 / (SR / 2), 420 / (SR / 2)], 'band'), rng.uniform(-1, 1, len(t)))
                                * (0.55 + 0.45 * np.sin(2 * np.pi * 24 * t)) ** 2 * np.minimum(1, t / 0.15) * np.minimum(1, (t[-1] - t) / 0.3)))(t_axis(1.4)),
    # Rewards
    'coin': lambda: room(seq((0, tone(E6, 0.18, BELL, decay=22)), (0.07, tone(A6, 0.35, BELL, decay=12)))),
    'check': lambda: seq((0, tone(E5, 0.14, MARIMBA, decay=24)), (0.08, tone(A5, 0.26, MARIMBA, decay=14))),
    'uncheck': lambda: seq((0, tone(A5, 0.12, MARIMBA, decay=30) * 0.7), (0.07, tone(E5, 0.18, MARIMBA, decay=22) * 0.7)),
    'cheer': lambda: room(seq(*[(i * 0.075, tone(f, 0.55, BELL, decay=6)) for i, f in enumerate([C6, E6, G6, C7])],
                              *[(0.32 + i * 0.045, tone(f, 0.25, BELL, decay=18) * 0.35) for i, f in enumerate([G6, A6, C7, A6, C7])]), wet=0.25),
    'unlock': lambda: room(seq((0, tone(C5, 0.6, MARIMBA, decay=5)), (0.09, tone(G5, 0.55, MARIMBA, decay=6)), (0.18, tone(C6, 0.6, BELL, decay=5)),
                               (0.3, noise(0.6, 4000, 12000, decay=5) * 0.12), (0.32, tone(E6, 0.7, BELL, decay=4) * 0.6)), wet=0.3),
    'flag': lambda: room(seq((0, tone(G5, 0.3, BELL, decay=9)), (0.14, tone(C6, 0.3, BELL, decay=9)), (0.28, tone(E6, 0.3, BELL, decay=9)),
                             (0.42, tone(G6, 0.9, BELL, decay=3.5))), wet=0.3),
    'chime': lambda: room(seq((0, tone(A5, 0.7, BELL, decay=5)), (0.18, tone(E6, 0.9, BELL, decay=4) * 0.7)), wet=0.35),
    # Calm-down (urge support)
    'breathe_in': lambda: (lambda t: sum(np.sin(2 * np.pi * f * t) * a for f, a in [(C5 / 2, 1), (G5 / 2, 0.5), (E5, 0.25)]) * np.sin(np.pi * t / t[-1]) ** 2)(t_axis(4.0)),
    'breathe_out': lambda: (lambda t: sum(np.sin(2 * np.pi * f * t) * a for f, a in [(G5 / 4, 1), (D5 / 2, 0.5), (G5 / 2, 0.25)]) * np.sin(np.pi * t / t[-1]) ** 2)(t_axis(4.0)),
    'drop': lambda: seq((0, tone(900, 0.16, ((1, 1.0),), decay=20, glide=12)), (0.1, tone(1400, 0.12, ((1, 1.0),), decay=30, glide=-5) * 0.4)),
}

PEAKS = {'tap': 0.32, 'whoosh': 0.22, 'swipe': 0.25, 'purr': 0.4, 'breathe_in': 0.28, 'breathe_out': 0.28, 'nope': 0.3}

def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    out.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 2 and sys.argv[2] == 'alarms':
        for name, make in ALARMS.items():
            x = make()
            write_alarm(out / f'{name}.wav', x)
            print(f'{name:12s} {len(x) / SR:5.2f}s')
        return
    for name, make in SOUNDS.items():
        x = make()
        write(out / f'{name}.wav', x, PEAKS.get(name, 0.5))
        print(f'{name:12s} {len(x) / SR:5.2f}s')


# ---------------------------------------------------------------------------
# Wake-up alarms: 16-second loops that start soft and fill out, rendered at
# 22.05 kHz to keep the assets small. Run: make_sfx.py assets/sfx alarms
# ---------------------------------------------------------------------------
ASR = 22050


def _loop(bars, beat=0.5, n_bars=8):
    """bars: function(bar_index) -> list of (beat_offset, clip)."""
    total = n_bars * 4 * beat
    out = np.zeros(int(SR * total) + SR)
    for b in range(n_bars):
        for off, clip in bars(b):
            out = place(out, clip * min(1.0, 0.35 + b * 0.12), b * 4 * beat + off * beat)
    out = room(out[: int(SR * total)], size=0.3, wet=0.25)[: int(SR * total)]
    # A short crossfade of the tail into the head so the loop has no seam.
    xf = int(SR * 0.08)
    out[:xf] = out[:xf] * np.linspace(0, 1, xf) + out[-xf:] * np.linspace(1, 0, xf)
    return out[: len(out) - xf]


MORNING = [C5, E5, G5, A5, G5, E5, D5, E5]


def morning_purr():
    purr = SOUNDS['purr']()
    return _loop(lambda b: [(i * 0.5, tone(MORNING[(i + b) % 8] * (2 if b >= 4 and i % 2 else 1), 0.9, MARIMBA, decay=4) * 0.7) for i in range(8)]
                 + ([(0, purr * 0.35)] if b % 2 == 0 else []))


def garden_bells():
    melody = [(0, G5), (1, E6), (2, D6), (3, C6)]
    return _loop(lambda b: [(o, tone(f * (1 if b % 2 == 0 else 1.122), 1.6, BELL, decay=2.6)) for o, f in melody]
                 + [(o + 0.5, tone(C5 / 2, 1.2, MARIMBA, decay=3) * 0.5) for o in (0, 2)], beat=0.55)


def paw_patter():
    def bar(b):
        hits = [(i * 0.5, tone(1300 if i % 2 else 900, 0.08, WOOD, decay=55) * 0.6) for i in range(8)]
        tune = [(0, tone(C6, 0.4, MARIMBA, decay=8)), (1, tone(E6, 0.4, MARIMBA, decay=8)), (1.5, tone(G6, 0.4, MARIMBA, decay=8)),
                (2.5, tone(A6 if b % 2 else E6, 0.6, MARIMBA, decay=6)), (3.5, tone(G6, 0.3, MARIMBA, decay=9))]
        return hits + (tune if b >= 1 else [])
    return _loop(bar, beat=0.42)


ALARMS = {'morning_purr': morning_purr, 'garden_bells': garden_bells, 'paw_patter': paw_patter}


def write_alarm(path, x):
    x = signal.resample_poly(x, 1, 2)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    wavfile.write(path, ASR, (x * 32767).astype(np.int16))


if __name__ == '__main__':
    main()
