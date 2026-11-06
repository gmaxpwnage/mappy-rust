#!/usr/bin/env python3
"""Compare our rendered frames with Mednafen's, pixel by pixel.

Used by tools/compare_mednafen.sh, which fills a directory with:

    <dir>/ref/rNNN.png       frames recorded from the reference emulator
    <dir>/ours/mine_NNN.png  the same frames rendered by this project

Mednafen records at 2x scale and drops the top and bottom 8 scanlines, so its
frames are 512x448 and correspond to 256x224 of the NES picture. Our frames are
256x240; they are downscaled/cropped the same way before comparing. Prints the
differing pixel count per pair and exits non-zero if any pair differs.
"""

import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare_frames import read_png  # noqa: E402


def load(path, crop_top):
    """Return (width, rows) with rows of 3-byte RGB, NES-resolution."""
    width, height, channels, px = read_png(path)
    rows = []
    step = 2 if height == 448 else 1  # 2x scaled reference
    for y in range(0, height, step):
        base = y * width * channels
        row = bytearray()
        for x in range(0, width, step):
            o = base + x * channels
            row.extend(px[o:o + 3])
        rows.append(bytes(row))
    width //= step
    if crop_top:
        rows = rows[crop_top:crop_top + 224]
    return width, rows


def compare(ref_path, mine_path):
    rw, ref = load(ref_path, 0)
    mw, mine = load(mine_path, 8)
    height = min(len(ref), len(mine))
    width = min(rw, mw)
    diff = 0
    for y in range(height):
        a, b = ref[y], mine[y]
        for x in range(width):
            if a[x * 3:x * 3 + 3] != b[x * 3:x * 3 + 3]:
                diff += 1
    return diff, width * height


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '/tmp/mappy-render-compare'
    refs = sorted(glob.glob(os.path.join(root, 'ref', '*.png')))
    if not refs:
        print("no reference frames (did the recording succeed?)")
        return 2
    failures = 0
    for i, r in enumerate(refs, start=1):
        candidates = sorted(glob.glob(os.path.join(root, 'ours', f'mine_{i:03d}_*.png')))
        if not candidates:
            print(f"{os.path.basename(r)}: no rendered counterpart")
            failures += 1
            continue
        results = [(compare(r, c)[0], os.path.basename(c)) for c in candidates]
        results.sort()
        diff, best = results[0]
        status = "identical" if diff == 0 else f"{diff} differing pixels"
        print(f"{os.path.basename(r)} vs {best}: {status}")
        others = ", ".join(f"{n}: {d}" for d, n in results[1:])
        if others:
            print(f"    (other candidates: {others})")
        if diff:
            failures += 1
    print(f"\n{len(refs) - failures}/{len(refs)} reference frames reproduced pixel-for-pixel")
    return 0 if failures == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
