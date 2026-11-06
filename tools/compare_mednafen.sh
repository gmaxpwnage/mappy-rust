#!/usr/bin/env bash
# Compare this project's rendering with a reference emulator, pixel for pixel.
#
# Records Mednafen's output with its QuickTime recorder, extracts frames with
# ffmpeg, renders the same frames with our engine and compares them.
#
#   MEDNAFEN=/path/to/mednafen FFMPEG=/path/to/ffmpeg tools/compare_mednafen.sh
#
# Notes:
#  * Mednafen's recorder drops the 8 top and bottom scanlines (256x224); this
#    script crops ours to match.
#  * The game must auto-start so both emulators show the same screen; the
#    script patches the title-screen check ($C89C: LDA $25 -> LDA #$01) into a
#    scratch copy of the ROM, exactly like the audio comparisons.
set -euo pipefail

MEDNAFEN=${MEDNAFEN:-mednafen}
FFMPEG=${FFMPEG:-ffmpeg}
ROM=${ROM:-rom/mappy.nes}
OUT=${OUT:-/tmp/mappy-render-compare}
FRAMES=${FRAMES:-"60 63 65 299 302"}
SECONDS_TO_RECORD=${SECONDS_TO_RECORD:-8}

command -v "$MEDNAFEN" >/dev/null || { echo "set MEDNAFEN=/path/to/mednafen" >&2; exit 1; }
command -v "$FFMPEG" >/dev/null || { echo "set FFMPEG=/path/to/ffmpeg" >&2; exit 1; }

mkdir -p "$OUT/ref" "$OUT/ours"
rm -f "$OUT"/ref/*.png "$OUT"/ours/*.png

# 1. Patch the ROM so the game starts without input.
python3 - "$ROM" "$OUT/autostart.nes" <<'PY'
import sys
data = bytearray(open(sys.argv[1], 'rb').read())
off = 16 + (0xC89C - 0xC000)
assert data[off:off+2] == bytes([0xA5, 0x25])
data[off:off+2] = bytes([0xA9, 0x01])
open(sys.argv[2], 'wb').write(data)
PY

# 2. Record the reference.
SDL_VIDEODRIVER=dummy timeout $((SECONDS_TO_RECORD + 4)) \
  "$MEDNAFEN" -sound 0 -qtrecord "$OUT/ref.mov" -video.driver softfb \
  "$OUT/autostart.nes" >/dev/null 2>&1 || true

# 3. Extract the frames we want from the recording.
SELECT=$(python3 - "$FRAMES" <<'PY'
import sys
frames = [int(f) for f in sys.argv[1].split()]
print("+".join(f"eq(n\\,{f})" for f in frames))
PY
)
"$FFMPEG" -hide_banner -loglevel error -i "$OUT/ref.mov" \
  -vf "select='$SELECT'" -fps_mode passthrough "$OUT/ref/r%03d.png"

# 4. Render the same frames with our engine (one process per frame).
# Our engine is rendered at f-1, f and f+1: Mednafen's recorder runs at a
# slightly different rate (60.16 fps), so its frame numbers drift against the
# game's frames by one either way. The comparison picks the best of the three.
idx=1
for f in $FRAMES; do
  target=$(printf "%s/ref/r%03d.png" "$OUT" "$idx")
  [ -f "$target" ] || { idx=$((idx+1)); continue; }
  for off in -1 0 1; do
    g=$((f + off))
    [ "$g" -lt 0 ] && continue
    cargo run -q --release -p mappy-player -- headless --rom "$OUT/autostart.nes" \
      --frames $((g + 1)) --every $((g + 1)) --outdir "$OUT/ours" --dump-indices >/dev/null
    cp "$OUT/ours/frame_$(printf %04d $g).png" \
       "$OUT/ours/mine_$(printf %03d $idx)_$(printf %+d $off).png" 2>/dev/null || true
  done
  idx=$((idx+1))
done

# 5. Compare.
python3 "$(dirname "$0")/compare_mednafen.py" "$OUT"
