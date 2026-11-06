#!/usr/bin/env python3
"""Compare emulator audio against a reference emulator's APU state.

FCEUX exposes the APU's per-channel audio state through its Lua `sound.get()`
API (`frame,p1_freq,p1_vol,...,tri_freq,...`); this build cannot record WAV
from the CLI, so the reference for pitch is that per-frame channel state, and
the signal under test is the audio this project synthesises.

Usage:
    audio_check.py --wav mine.wav --ref apu_fceux.csv [--fps 60.0988]

It estimates the fundamental of the harmonic mix in short windows and reports
how it relates to the reference channel frequencies for the same frame:

  ratio ~1.0   the melody sounds at the emulator's pitch
  ratio ~2.0   an octave too high (timer clocked at the wrong rate)
  ratio ~0.5   an octave too low

Pure Python on purpose: no third-party dependencies.
"""

import argparse
import math
import struct
import sys


def read_wav(path):
    data = open(path, "rb").read()
    assert data[:4] == b"RIFF" and data[8:12] == b"WAVE", "not a RIFF/WAVE file"
    pos = 12
    fmt = None
    payload = None
    while pos + 8 <= len(data):
        kind = data[pos:pos + 4]
        (length,) = struct.unpack("<I", data[pos + 4:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif kind == b"data":
            payload = body
        pos += 8 + length + (length & 1)
    assert fmt and payload is not None, "missing fmt/data chunk"
    channels, rate, bits = fmt[1], fmt[2], fmt[5]
    if bits == 16:
        n = len(payload) // 2
        samples = list(struct.unpack("<%dh" % n, payload[: n * 2]))
    elif bits == 8:
        samples = [(b - 128) << 8 for b in payload]
    else:
        raise SystemExit(f"unsupported bit depth {bits}")
    if channels > 1:
        samples = [sum(samples[i:i + channels]) / channels for i in range(0, len(samples), channels)]
    return rate, samples


def read_ref(path):
    rows = []
    with open(path) as f:
        header = f.readline().strip().split(",")
        for line in f:
            parts = line.strip().split(",")
            if len(parts) != len(header):
                continue
            rows.append(dict(zip(header, parts)))
    return rows


def lowpass_decimate(samples, factor):
    """Boxcar low-pass followed by decimation; enough for fundamental tracking."""
    out = []
    acc = 0
    for i, s in enumerate(samples):
        acc += s
        if i >= factor:
            acc -= samples[i - factor]
        if (i + 1) % factor == 0:
            out.append(acc / factor)
    return out


def estimate_pitch(window, fs, min_hz=55.0, max_hz=1400.0):
    """Normalised autocorrelation pitch estimate; returns Hz or None."""
    n = len(window)
    mean = sum(window) / n
    x = [v - mean for v in window]
    energy = sum(v * v for v in x)
    if energy <= 1e-6:
        return None
    min_lag = max(2, int(fs / max_hz))
    max_lag = min(n // 2, int(fs / min_hz))
    best_lag, best_val = None, 0.0
    for lag in range(min_lag, max_lag):
        num = 0.0
        for i in range(n - lag):
            num += x[i] * x[i + lag]
        denom = energy
        r = num / denom
        if r > best_val:
            best_val, best_lag = r, lag
    if best_lag is None or best_val < 0.25:
        return None
    return fs / best_lag


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wav", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--fps", type=float, default=60.0988)
    ap.add_argument("--decimate", type=int, default=8)
    ap.add_argument("--window-ms", type=float, default=46.0)
    args = ap.parse_args()

    rate, samples = read_wav(args.wav)
    ref = read_ref(args.ref)
    ds = lowpass_decimate(samples, args.decimate)
    fs = rate / args.decimate
    win = int(fs * args.window_ms / 1000.0)
    step = int(fs / args.fps)

    ratios = []
    detail = []
    for frame in range(0, min(len(ref), len(ds) // max(step, 1))):
        start = frame * step
        if start + win > len(ds):
            break
        window = ds[start:start + win]
        pitch = estimate_pitch(window, fs)
        if pitch is None:
            continue
        row = ref[frame]
        candidates = []
        for key in ("p1_freq", "p2_freq", "tri_freq"):
            try:
                f = float(row[key])
            except (KeyError, ValueError):
                continue
            if 55.0 <= f <= 1400.0:
                candidates.append(f)
        if not candidates:
            continue
        # Compare with the closest reference pitch and with its octaves.
        best = min(candidates, key=lambda c: abs(math.log2(pitch / c)))
        ratios.append(pitch / best)
        detail.append((frame, pitch, best, pitch / best))

    if not ratios:
        print("no pitch measurements (silence?)")
        return 1

    ratios.sort()
    in_tune = sum(1 for r in ratios if abs(r - 1.0) < 0.05)
    octave_up = sum(1 for r in ratios if abs(r - 2.0) < 0.1)
    octave_down = sum(1 for r in ratios if abs(r - 0.5) < 0.05)
    n = len(ratios)
    print(f"measured {n} pitched frames from {args.wav}")
    print(f"  median ratio to reference: {ratios[n // 2]:.3f}")
    print(f"  within 5% of the reference pitch: {in_tune}/{n} ({100 * in_tune / n:.1f}%)")
    print(f"  one octave high: {octave_up}/{n} ({100 * octave_up / n:.1f}%)")
    print(f"  one octave low:  {octave_down}/{n}")
    worst = sorted(detail, key=lambda d: -abs(math.log2(d[3])))[:6]
    print("  largest deviations (frame, measured Hz, reference Hz, ratio):")
    for frame, pitch, ref_hz, ratio in worst:
        print(f"    frame {frame:>4}: {pitch:8.1f} Hz vs {ref_hz:8.1f} Hz  x{ratio:.2f}")
    return 0 if in_tune > 0.7 * n else 1


if __name__ == "__main__":
    sys.exit(main())
