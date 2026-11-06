#!/usr/bin/env python3
"""Compare emulator frames against a reference (FCEUX) pixel by pixel.

Usage:
    compare_frames.py <mine.png> <reference.png> [--crop-top N] [--crop-bottom N]

Both images must be 8-bit truecolour/RGBA PNGs. The reference is assumed to be
224 lines tall (FCEUX hides 8 lines top and bottom); `--crop-top 8` is the
default. Prints the number of differing pixels and, when they differ, the
bounding box of the differences plus a per-row histogram to help localise bugs.
"""

import struct
import sys
import zlib


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos = 8
    idat = b""
    width = height = bit_depth = color_type = None
    palette = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", body[:10])
        elif kind == b"PLTE":
            palette = body
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
        pos += 12 + length
    assert bit_depth == 8, f"unsupported bit depth {bit_depth}"
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    raw = zlib.decompress(idat)
    stride = width * channels
    out = bytearray(width * height * channels)
    prev = bytearray(stride)
    p = 0
    for y in range(height):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:  # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif f == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:  # Average
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:  # Paeth
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    if color_type == 3:
        expanded = bytearray(width * height * 3)
        for i, idx in enumerate(out):
            expanded[i * 3:i * 3 + 3] = palette[idx * 3:idx * 3 + 3]
        out = expanded
        channels = 3
    return width, height, channels, out


def write_png(path, width, height, rgb):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(rgb[y * width * 3:(y + 1) * width * 3])
    def chunk(kind, body):
        return (struct.pack(">I", len(body)) + kind + body +
                struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b""))
    open(path, "wb").write(data)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    mine_path, ref_path = sys.argv[1], sys.argv[2]
    crop_top = 8
    args = sys.argv[3:]
    i = 0
    while i < len(args):
        if args[i] == "--crop-top":
            crop_top = int(args[i + 1])
            i += 2
        else:
            i += 1
    mw, mh, mc, mine = read_png(mine_path)
    rw, rh, rc, ref = read_png(ref_path)
    if mw != rw:
        print(f"width mismatch: {mw} vs {rw}")
        return 2
    rows = min(mh - crop_top, rh)
    diff = 0
    box = [1 << 30, 1 << 30, -1, -1]
    rows_diff = {}
    for y in range(rows):
        for x in range(mw):
            mo = ((y + crop_top) * mw + x) * mc
            ro = (y * rw + x) * rc
            a = mine[mo:mo + 3]
            b = ref[ro:ro + 3]
            if a != b:
                diff += 1
                rows_diff[y] = rows_diff.get(y, 0) + 1
                box[0] = min(box[0], x)
                box[1] = min(box[1], y)
                box[2] = max(box[2], x)
                box[3] = max(box[3], y)
    total = rows * mw
    print(f"{mine_path} vs {ref_path}: {diff} differing pixels of {total} "
          f"({100.0 * diff / total:.2f}%)")
    if diff:
        print(f"  bounding box: x {box[0]}..{box[2]}, y {box[1]}..{box[3]}")
        if "--diff-out" in sys.argv:
            out_path = sys.argv[sys.argv.index("--diff-out") + 1]
            overlay = bytearray(mw * rows * 3)
            for y in range(rows):
                for x in range(mw):
                    mo = ((y + crop_top) * mw + x) * mc
                    ro = (y * rw + x) * rc
                    a = mine[mo:mo + 3]
                    b = ref[ro:ro + 3]
                    o = (y * mw + x) * 3
                    if a != b:
                        overlay[o:o + 3] = bytes([255, 0, 255])
                    else:
                        grey = (a[0] + a[1] + a[2]) // 3
                        overlay[o:o + 3] = bytes([grey, grey, grey])
            write_png(out_path, mw, rows, overlay)
            print(f"  diff image: {out_path}")
        worst = sorted(rows_diff.items(), key=lambda kv: -kv[1])[:8]
        print("  worst rows:", ", ".join(f"y{y}:{c}" for y, c in worst))
        return 1
    print("  frames are pixel-identical")
    return 0


if __name__ == "__main__":
    sys.exit(main())
