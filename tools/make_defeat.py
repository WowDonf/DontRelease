#!/usr/bin/env python3
"""
DontRelease "Defeat" sound generator.

Synthesizes an ORIGINAL somber JRPG-style game-over sting -- the kind of
slow minor-key lament you hear when the party wipes -- and writes it to:
  - Sounds/defeat.ogg

This is an original composition (its own melody and chord progression),
written to evoke the *mood* of a classic role-playing-game defeat screen.
It does not reproduce any copyrighted theme.

Construction:
  1. A soft "strings" pad sustains the chord under each bar (slow attack,
     gentle vibrato, full harmonic series).
  2. A "bell" melody (fast attack, exponential decay -- celesta-ish)
     carries a descending lament on top.
  3. The piece walks a minor cadence (i - VI - iv - V) and lands on a low,
     heavy tonic chord: the "you lost" thud of finality.

Brass-free; the timbres and the WAV->OGG encode otherwise mirror
make_sounds.py so the file sits next to the existing Sounds set.

Stdlib-only. Requires `ffmpeg` on PATH for the WAV -> OGG step (native
vorbis encoder; needs `-strict experimental` and stereo upmix, both
handled here).
"""
import math
import struct
import subprocess
import wave
from pathlib import Path

REPO_ROOT  = Path(__file__).resolve().parent.parent
SOUNDS_DIR = REPO_ROOT / "Sounds"
SOUNDS_DIR.mkdir(exist_ok=True)

SAMPLE_RATE = 44100

# Pad ("strings"): full, slowly-bowed harmonic series.
PAD_WEIGHTS = [1.0, 0.6, 0.4, 0.28, 0.18, 0.12, 0.08]
PAD_NORM    = sum(PAD_WEIGHTS)

# Bell ("celesta"): odd-leaning partials, struck and decaying.
BELL_WEIGHTS = [1.0, 0.0, 0.55, 0.0, 0.30, 0.18, 0.10]
BELL_NORM    = sum(BELL_WEIGHTS)

VIBRATO_RATE_HZ    = 4.5
VIBRATO_DEPTH_FRAC = 0.006

A4_HZ = 440.0
_NOTE_SEMITONES = {
    "C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4,
    "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2,
}


def note_freq(name, octave):
    semis = _NOTE_SEMITONES[name] + (octave - 4) * 12
    return A4_HZ * (2.0 ** (semis / 12.0))


# ---------------------------------------------------------------------
# Voices
# ---------------------------------------------------------------------
def synth_pad(freq, duration, gain):
    """Sustained bowed-string-ish note: slow attack, long sustain, soft
    release, gentle vibrato."""
    n = int(duration * SAMPLE_RATE)
    if n <= 0:
        return []
    attack_n  = int(0.18 * SAMPLE_RATE)
    release_n = int(0.30 * SAMPLE_RATE)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq * (1.0 + VIBRATO_DEPTH_FRAC * math.sin(2 * math.pi * VIBRATO_RATE_HZ * t))
        sample = 0.0
        for h, w in enumerate(PAD_WEIGHTS, start=1):
            sample += w * math.sin(2 * math.pi * f * h * t)
        sample /= PAD_NORM

        if i < attack_n:
            env = i / attack_n
        elif i > n - release_n:
            env = max(0.0, (n - i) / release_n)
        else:
            env = 1.0
        out[i] = sample * env * gain
    return out


def synth_bell(freq, duration, gain):
    """Struck bell/celesta tone: instant attack, exponential decay."""
    n = int(duration * SAMPLE_RATE)
    if n <= 0:
        return []
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        sample = 0.0
        for h, w in enumerate(BELL_WEIGHTS, start=1):
            if w:
                sample += w * math.sin(2 * math.pi * freq * h * t)
        sample /= BELL_NORM
        # Strike envelope: tiny attack, then exponential ring-out.
        attack_n = int(0.006 * SAMPLE_RATE)
        if i < attack_n:
            env = i / attack_n
        else:
            env = math.exp(-3.2 * (t - attack_n / SAMPLE_RATE))
        out[i] = sample * env * gain
    return out


# ---------------------------------------------------------------------
# Mixing helpers
# ---------------------------------------------------------------------
def add_at(buf, samples, start):
    end = start + len(samples)
    if end > len(buf):
        buf.extend([0.0] * (end - len(buf)))
    for i, s in enumerate(samples):
        buf[start + i] += s


def secs(x):
    return int(x * SAMPLE_RATE)


# ---------------------------------------------------------------------
# Arrangement -- key of A minor.
# Progression: Am  -  F  -  Dm  -  E(maj)  ->  low Am (the death blow).
# Melody: a descending lament that sighs down to the tonic.
# ---------------------------------------------------------------------
BAR_SECS = 0.95

CHORDS = [
    [("A", 3), ("C", 4), ("E", 4)],   # i   Am
    [("F", 3), ("A", 3), ("C", 4)],   # VI  F
    [("E", 3), ("G#", 3), ("B", 3)],  # V   E major (leading, tense)
]

# Melody notes per bar: (name, octave, beats). 4 beats per bar.
# Melodic but not a straight tumbling descent -- it rises and falls so it
# reads as a phrase rather than a repetitive "wah wah wah" sigh.
MELODY = [
    [("E", 5, 2), ("A", 4, 2)],       # over Am: leap down, settle
    [("C", 5, 2), ("E", 5, 2)],       # over F:  lift back up
    [("B", 4, 2), ("E", 4, 2)],       # over E:  gentle settle to close
]

PAD_GAIN  = 0.035
BELL_GAIN = 0.42
FINAL_GAIN = 0.06


def build_defeat():
    buf = []
    beat_secs = BAR_SECS / 4.0

    # Bells only -- no sustained pad/drone underneath.
    for bar in range(len(CHORDS)):
        bar_start = secs(bar * BAR_SECS)
        beat_cursor = 0.0
        for name, octave, beats in MELODY[bar]:
            note_start = bar_start + secs(beat_cursor * beat_secs)
            dur = beats * beat_secs
            add_at(buf, synth_bell(note_freq(name, octave), dur, BELL_GAIN), note_start)
            beat_cursor += beats

    # Final low bell strike to seal it -- the screen going dark.
    final_start = secs(len(CHORDS) * BAR_SECS)
    add_at(buf, synth_bell(note_freq("A", 3), 1.0, BELL_GAIN * 0.85), final_start)

    buf.extend([0.0] * secs(0.15))
    return buf


def normalize(samples, peak=0.92):
    hi = max((abs(s) for s in samples), default=0.0)
    if hi <= 0:
        return samples
    g = peak / hi
    return [s * g for s in samples]


def write_wav(samples, path):
    clipped = [max(-1.0, min(1.0, s)) for s in samples]
    ints    = [int(s * 32767) for s in clipped]
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack(f"<{len(ints)}h", *ints))


def wav_to_ogg(wav_path, ogg_path):
    subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(wav_path),
            "-ac", "2",
            "-c:a", "vorbis", "-strict", "experimental",
            "-b:a", "96k",
            str(ogg_path),
        ],
        check=True,
    )


def main():
    wav = SOUNDS_DIR / "defeat.wav"
    ogg = SOUNDS_DIR / "defeat.ogg"
    samples = normalize(build_defeat())
    write_wav(samples, wav)
    try:
        wav_to_ogg(wav, ogg)
    finally:
        wav.unlink(missing_ok=True)
    duration = len(samples) / SAMPLE_RATE
    size_kb  = ogg.stat().st_size / 1024
    print(f"wrote {ogg.relative_to(REPO_ROOT)}  ({duration:.2f}s, {size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
