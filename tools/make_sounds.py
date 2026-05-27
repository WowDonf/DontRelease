#!/usr/bin/env python3
"""
DontRelease "Whomp" sound generator.

Synthesizes the 4 Whomp variants as sad-trombone descending patterns and
writes them to:
  - Sounds/whomp1.ogg  - 1-note "wah"
  - Sounds/whomp2.ogg  - 2-note "wah wah"
  - Sounds/whomp3.ogg  - 3-note "wah wah wah"
  - Sounds/whomp4.ogg  - 4-note "wah wah wah wah"

Each pattern is a sequence of descending brass-like notes; the final note
is longer and pitch-bends downward to give the characteristic "sad
trombone" tail. Brass timbre is approximated by summing weighted
harmonics (fundamental + 5 partials) and applying an ADSR envelope plus
light vibrato.

Stdlib-only. Requires `ffmpeg` on PATH for the WAV - OGG step (the native
ffmpeg vorbis encoder is fine; it just needs `-strict experimental` and
stereo upmix, both handled here).
"""
import math
import os
import struct
import subprocess
import sys
import wave
from pathlib import Path

REPO_ROOT  = Path(__file__).resolve().parent.parent
SOUNDS_DIR = REPO_ROOT / "Sounds"
SOUNDS_DIR.mkdir(exist_ok=True)

SAMPLE_RATE = 44100

# Brass-like harmonic spectrum: strong fundamental, decaying partials.
# Real trombone has more energy in 2nd-4th harmonics than a sine tone;
# this approximation gives a recognizably "brassy" timbre without
# resorting to FM synthesis or formant filtering.
HARMONIC_WEIGHTS = [1.0, 0.65, 0.50, 0.32, 0.20, 0.12]
HARMONIC_NORM    = sum(HARMONIC_WEIGHTS)

# Vibrato: subtle frequency modulation for organic feel.
VIBRATO_RATE_HZ    = 5.0
VIBRATO_DEPTH_FRAC = 0.008   # +/- 0.8% frequency wobble

# ADSR envelope parameters (fractions of total note duration where noted).
ATTACK_SECS         = 0.030
DECAY_SECS          = 0.050
SUSTAIN_LEVEL       = 0.78
RELEASE_FRAC        = 0.30

# Pattern timing.
NOTE_DURATION_SECS  = 0.20    # non-final notes
TAIL_DURATION_SECS  = 0.42    # final "waaah" note (longer)
TAIL_BEND_SEMITONES = -2.0    # pitch bend at end of tail
GAP_SECS            = 0.04    # silence between notes

# Pitch design.
# Base note: G3 (~196 Hz) - sits in the comfortable trombone range and
# is recognizably "low brass" without being subsonic on small speakers.
BASE_FREQ_HZ        = 196.00
STEP_SEMITONES      = -2.0    # each note descends 2 semitones from prev


def semitones_to_ratio(semis):
    return 2.0 ** (semis / 12.0)


def synth_note(freq, duration, bend_to=None):
    """Render one brass-ish note as a list of float samples in [-1, 1]."""
    n = int(duration * SAMPLE_RATE)
    attack_n  = int(ATTACK_SECS * SAMPLE_RATE)
    decay_n   = int(DECAY_SECS  * SAMPLE_RATE)
    release_n = int(RELEASE_FRAC * n)
    sustain_n = max(0, n - attack_n - decay_n - release_n)

    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE

        # Optional linear pitch glide from `freq` to `bend_to` across the
        # whole note. Used on the tail to bend downward into "waaah".
        if bend_to is not None:
            f = freq + (bend_to - freq) * (i / n)
        else:
            f = freq

        # Vibrato as small frequency modulation around the current pitch.
        f *= 1.0 + VIBRATO_DEPTH_FRAC * math.sin(2 * math.pi * VIBRATO_RATE_HZ * t)

        # Sum the harmonic series. Each harmonic at h*f, weighted.
        sample = 0.0
        for h, w in enumerate(HARMONIC_WEIGHTS, start=1):
            sample += w * math.sin(2 * math.pi * f * h * t)
        sample /= HARMONIC_NORM

        # ADSR envelope.
        if i < attack_n:
            env = i / attack_n if attack_n > 0 else 1.0
        elif i < attack_n + decay_n:
            env = 1.0 - (1.0 - SUSTAIN_LEVEL) * ((i - attack_n) / decay_n)
        elif i < attack_n + decay_n + sustain_n:
            env = SUSTAIN_LEVEL
        else:
            rel_pos = (i - attack_n - decay_n - sustain_n) / max(1, release_n)
            env = SUSTAIN_LEVEL * max(0.0, 1.0 - rel_pos)

        # 0.55 headroom so the WAV doesn't clip when harmonics align.
        out[i] = sample * env * 0.55

    return out


def sad_trombone_pattern(num_notes):
    """Build a `num_notes`-step descending pattern. Last note is the tail."""
    samples = []
    gap = [0.0] * int(GAP_SECS * SAMPLE_RATE)

    for i in range(num_notes):
        is_tail = (i == num_notes - 1)
        freq = BASE_FREQ_HZ * semitones_to_ratio(i * STEP_SEMITONES)

        if is_tail:
            duration = TAIL_DURATION_SECS
            bend_to  = freq * semitones_to_ratio(TAIL_BEND_SEMITONES)
        else:
            duration = NOTE_DURATION_SECS
            bend_to  = None

        samples.extend(synth_note(freq, duration, bend_to))
        if not is_tail:
            samples.extend(gap)

    return samples


def write_wav(samples, path):
    """Write float [-1, 1] samples as 16-bit mono PCM WAV."""
    clipped = [max(-1.0, min(1.0, s)) for s in samples]
    ints    = [int(s * 32767) for s in clipped]
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack(f"<{len(ints)}h", *ints))


def wav_to_ogg(wav_path, ogg_path):
    """Encode mono WAV - stereo Vorbis OGG via ffmpeg.

    The native ffmpeg vorbis encoder only accepts stereo input, so we
    upmix mono - stereo with -ac 2. Requires -strict experimental.
    """
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
    for i in range(1, 5):
        wav = SOUNDS_DIR / f"whomp{i}.wav"
        ogg = SOUNDS_DIR / f"whomp{i}.ogg"
        samples = sad_trombone_pattern(i)
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
