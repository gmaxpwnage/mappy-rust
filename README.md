# Mappy (Japan) (En) — decompiled to Rust

[![CI](https://github.com/gaavin/mappy-rust/actions/workflows/ci.yml/badge.svg)](https://github.com/gaavin/mappy-rust/actions/workflows/ci.yml)

The 24 KiB NES cartridge **Mappy (Japan) (En)** (Namco, 1984) — 16 KiB of 6502
code and data plus 8 KiB of pattern tables — turned into a Rust workspace that
plays the game natively on Linux, macOS and Windows.

* **`crates/mappy-rom`** is the game: every 6502 instruction in the ROM,
  translated to a Rust function (16 384 of them), calling into a Rust model of
  the NES hardware. The cartridge data is embedded in the binary, so the result
  is a self-contained native executable — no ROM file, no emulator loop over
  opcodes.
* **`crates/nes`** and **`crates/mos6502`** are the machine it runs on: a
  dot-accurate PPU, a full APU, NROM cartridge mapping, and a cycle-counted
  6502 that doubles as the reference implementation the translation is tested
  against.
* **`crates/decompiler`** performs the translation: it analyses the ROM,
  annotates it, writes the annotated disassembly (`disassembly/mappy.asm`) and
  generates the Rust source.

```
                 rom/mappy.nes
                       │
              ┌────────▼─────────┐
              │    decompiler    │  static analysis + 6502→Rust translation
              └───┬──────────┬───┘
                  │          │
   disassembly/mappy.asm   crates/mappy-rom/src/generated.rs
      (annotated)              (16 384 Rust functions)
                                  │
                       ┌──────────▼──────────┐
                       │  mappy (frontend)   │  winit window, cpal audio
                       └─────────────────────┘  ⟵ runs the actual game
```

## Run it

```sh
cd ~/mappy

# Option A: Nix (reproducible toolchain + window/audio libraries)
nix develop
cargo run --release -p mappy-player -- play

# Option B: any Rust toolchain with a C linker (this machine's exact paths are
# in toolchain.env, which also sets ALSA/X11/Wayland library paths)
source toolchain.env
cargo run --release -p mappy-player -- play
```

`play` needs no ROM path: the cartridge data is compiled into
`mappy-rom` (`crates/mappy-rom/data/{prg,chr}.bin`, extracted from the image).

### Controls

| Key | NES pad |
| --- | --- |
| Arrow keys / `WASD` | D-pad |
| `Z` or `K` or `Space` | A |
| `X` or `J` | B |
| `Enter` | Start (start game / pause) |
| `Shift` or `Tab` | Select |
| `Esc` | quit |

On the title screen press **Enter**. Note that the original only samples a
*fresh* press in the exact frame its title loop checks the pad, so if the first
press seems ignored, press it again — that is the game's behaviour, confirmed
against FCEUX.

### Options

```
mappy play     [--scale N] [--no-audio] [--input SCRIPT] [--fps N] [--stats]
mappy headless [--frames N] [--every N] [--outdir DIR] [--engine decompiled|interpreter]
mappy trace    [--frames N] [--pc-range LO-HI] [--watch-ram ADDR]
mappy diff     [--frames N] [--input SCRIPT]
mappy ram|nt|probe|bench ...
```

`--input` takes a script of scripted controller input, which is how the
automated tests drive the game:

```
--input "START@40-43,RIGHT@90-260,A@270-285,LEFT@500-640"
```

## What "decompiled to Rust" means here

The ROM is not interpreted at runtime. `decompiler` decodes the PRG image
statically and emits, for **every** byte offset in the image, a Rust function
that performs that one instruction against the machine and sets the program
counter to wherever the instruction leads:

```rust
/// `$C031` — `SEI` — reset
#[inline(never)]
pub fn fn_reset(m: &mut Machine) {
    m.cpu.add_cycles(2);
    m.cpu.set_flag(FLAG_I, true);
    m.cpu.pc = next_pc(m, 0x0032);
}

/// `$C07C` — `JSR $C0D0` — pause_sprites
#[inline(never)]
pub fn f_007c(m: &mut Machine) {
    m.cpu.add_cycles(6);
    let ret = next_pc(m, 0x007f) - 1;
    m.push((ret >> 8) as u8);
    m.push(ret as u8);
    m.cpu.pc = 0xC0D0u16 /* pause_sprites */;
}
```

Control flow is Rust calls; the dispatch table `DISPATCH[pc & 0x3FFF]` is the
translation of the 6502's opcode fetch. All 151 documented instructions and the
undocumented NMOS opcodes are handled, because a decompiler must be able to
decode every byte of the image — including data that is never executed.

Two things are *not* translated, and both are data rather than code:

* the 8 KiB of CHR pattern tables (the game reads them through the PPU), and
* the ROM's data tables (level layouts, palettes, text, Namco sound data),
  which the translated code addresses exactly as the original did.

On top of the mechanical translation, the code has been read and annotated:
`symbols.txt` names the routines whose behaviour was confirmed (reset, NMI,
controller decoding, the VRAM update queue, the title screen, the pause
sprites, the APU engine, …), and `docs/DECOMPILATION.md` documents the
structure of the original program.

## Verification

Seven independent layers, all runnable with `cargo test --release` plus the
commands below.

1. **6502 correctness** — `mos6502` passes Klaus Dormann's full functional test
   suite (all documented opcodes, every addressing mode, flag behaviour,
   decimal mode, the `JMP ($xxFF)` page bug), 1.6 M instructions with no
   deviation:

   ```sh
   tools/fetch_tests.sh   # the suite is GPL, so it is fetched, not vendored
   cargo test --release -p mos6502
   ```

2. **Translation equivalence** — `crates/mappy-rom/tests/equivalence.rs` runs
   the reference interpreter and the generated Rust *in lockstep* from the
   same power-on state for 260 frames of scripted play, and compares registers,
   cycle counts, RAM, PPU scroll registers, nametables and the framebuffer
   after every single instruction. They must be identical, and are.

   ```sh
   cargo test --release -p mappy-rom
   mappy diff --frames 500 --input "START@19-21,RIGHT@100-300"   # same, longer
   ```

3. **Rendering vs a reference emulator** — `tools/compare_mednafen.sh` records
   Mednafen's video output of the same auto-starting ROM, extracts frames and
   compares them against ours pixel for pixel: **every compared frame is
   identical** (title screen, "READY" screen and moving gameplay). The same
   palette table was validated independently by checking that every colour in
   the reference's frames exists in ours.

4. **Audio correctness** — `crates/nes/tests/apu_waveform.rs` measures what the
   APU *sounds like*: pulse/triangle tone frequency against the documented
   formulas, duty ratio against the duty register, noise shift-register clock
   rate, envelope and length-counter clock rates, and sweep behaviour. A timer
   clocked at the wrong rate (an octave error) fails these even when every
   register write is correct.

5. **Audio against a reference emulator** — `tools/audio_check.py` compares
   this project's audio with FCEUX's per-frame APU state and with mednafen's
   recorded output (see the Audio section above).

6. **Audio timing** — `crates/nes/tests/apu_rate.rs` asserts the APU emits
   exactly one second of samples per second of CPU time at any requested rate
   (44.1 / 48 / 96 kHz) and ~734 samples per 60 Hz frame, so tempo and pitch
   follow the console clock rather than the host's frame rate.

7. **Game-level smoke test** — `--input "START@19-21"` must produce the
   `PLAYER 1 READY` screen and a live score, i.e. the game really starts,
   which the test asserts through the input-enable byte at `$040F`.

### Video

The PPU is dot-accurate: the background fetch pipeline (including the
321-337 prefetch window that fills the shifters for the next line), sprite
evaluation at dot 257, sprite-0 hit, the odd-frame dot skip, $2005/$2006/$2007
behaviour and the mid-frame VRAM writes Mappy relies on for its status bar.

Colours use the same 64-entry palette as the reference emulator (Mednafen's
built-in NES table), verified colour by colour against its rendered output, and
sprites are looked up in their own palettes at `$3F10-$3F1F` - a sprite's
palette is *not* the background palette with the same index. Sprite Y points at
the scanline above the sprite's first row.

Checking rendering against Mednafen's recorded output found and fixed three
faults: the whole palette was the wrong table (brighter "classic" values
instead of the reference's), sprites were indexed against the background
palettes (green "PLAYER 1 READY" instead of red), and sprites sat one scanline
too high. One further bug - a background prefetch window starting one dot late
- blanked the leftmost 8 pixels of every scanline.

`tools/compare_mednafen.sh` reproduces the comparison end to end: it records
Mednafen with its QuickTime recorder, extracts frames with ffmpeg, renders the
same frames here and diffs them. The result is **pixel-identical frames**:

```
$ MEDNAFEN=... FFMPEG=... tools/compare_mednafen.sh
r001.png vs mine_001_+0.png: identical
...
5/5 reference frames reproduced pixel-for-pixel
```

### Audio

The APU is modelled from the NESdev references: pulse timers in APU cycles
(`f = CPU/(16*(t+1))`), triangle in CPU cycles (`f = CPU/(32*(t+1))`), the
noise period table as a CPU-cycle count, the DMC rate table, the documented
duty sequences, the sweep unit with its ones'-complement adder on pulse 1, and
the four-step frame sequencer with its *cumulative* step boundaries
(7457/14913/22371/29829 cycles) driving envelopes, length counters and the
triangle's linear counter. Channels are mixed with the 2A03's non-linear
output curve, DC-blocked, and resampled with a fractional accumulator.

Audio controls (`--no-audio` disables output entirely):

* the frontend asks the device for its real sample rate and synthesises at
  exactly that rate, so nothing is resampled on the way out;
* `demo/mappy-music.wav` is a 25-second capture of the game's soundtrack as
  rendered by this project.

Checking it against reference emulators (`tools/audio_check.py`) found and
fixed six real synthesis bugs:

1. the frame sequencer used cumulative cycle counts as per-step delays, making
   everything 2.5x too slow;
2. pulse timers were clocked at the CPU rate instead of the APU rate, putting
   the melody an octave up;
3. the noise shift register was clocked at the wrong rate (its period table is
   in CPU cycles);
4. the 50% and 75% duty sequences were wrong;
5. the sweep unit applied its update before computing the target period, and
   had its ones'-complement adder on the wrong channel;
6. the frame sequencer was missing the **quarter-frame clock of step 2**, so
   envelopes and the triangle's linear counter ran at 180 Hz instead of 240 Hz
   and every note sustained ~25% too long - this is what made the bass and
   melody sound "wrong" in the first playable builds.

After the fixes, per-frame channel frequencies and duties match FCEUX's APU
model exactly (0 of 200 frames differ). Measured against mednafen's recorded
output of the same passage:

| metric | before | after |
| --- | --- | --- |
| musical rests vs reference | 0.35 s late, four rests missing | within 1 frame (16 ms) |
| triangle level vs reference | up to 5500x (notes never stopped) | 1.29x (uniform) |
| pulse1 level vs reference | 1.49x | 1.39x |
| spectral balance (all bands) | non-uniform | uniform |

The residual is a constant ~2.5 dB gain offset (a headroom choice) with
matching harmonic structure; the note envelopes now decay at the hardware rate
(verified by a test that pins the 0.688 s decay of a divider-10 envelope).

### Frame pacing

Mappy's game logic is vblank-driven: one frame of game time is one NMI, which
is exactly one 341×262-dot PPU frame. The player therefore advances the machine
by **whole frames, paced against the wall clock, at the console's own rate —
60.0988 Hz NTSC** — and never by "however fast the host can run the
translations". Emulation throughput and game speed are decoupled: the engine
manages ~850 frames/s, and the game still runs at 60.

* `--fps N` overrides the lock (e.g. `--fps 60`).
* `--stats` prints the measured rate once per second, the audio queue depth,
  and whether the loop had to catch up.
* Up to 3 frames are caught up after a short stall; a longer stall (window
  drag, suspend) re-bases the clock instead of fast-forwarding the game. This
  also means the game *cannot* run slow on a busy machine — it simply drops
  the missed frames.
* Audio is synthesised at the output device's real sample rate (queried from
  cpal), so nothing needs resampling and the pitch/tempo stay correct. Audio
  pushes never block the game loop: if the sink stalls, samples are dropped
  rather than freezing the game.

```sh
mappy play --stats          # verify the lock on your machine
mappy bench                 # raw engine throughput, unthrottled
```

Performance of the translations themselves: the decompiled engine runs at
about **850–900 frames per second** (~15× real time) on one core, including
full PPU rendering and APU synthesis. `headless`, `trace`, `diff` and `bench`
are deliberately unthrottled so analysis runs as fast as possible.

## Layout

```
crates/mos6502/      6502 core: opcode matrix, interpreter, disassembler, tests
crates/nes/          PPU, APU, cartridge, bus, controller; no platform deps
crates/decompiler/   ROM analysis, listing writer, Rust code generator
crates/mappy-rom/    generated Rust + embedded cartridge data + engine glue
crates/mappy-player/ frontend: winit window, cpal audio, headless/debug tools
demo/mappy-music.wav  the soundtrack as rendered by this project
screenshots/           title, READY and gameplay frames (identical to the reference)
disassembly/mappy.asm  annotated disassembly (6.4 k lines)
symbols.txt            names for the routines that have been identified
docs/DECOMPILATION.md  what the original program does, routine by routine
tools/                 opcode table generator, reference-emulator comparisons, test fetch
```

## Regenerating the decompilation

```sh
source toolchain.env   # or: nix develop

# Optional: record which addresses execute during a play session, which
# recovers code reachable only through the game's computed jumps.
cargo run --release -p mappy-player -- trace --frames 4000 \
    --input "START@19-21,RIGHT@60-400,LEFT@410-700,A@740-760" --out /tmp/cov.txt

cargo run --release -p decompiler -- rom/mappy.nes \
    --asm disassembly/mappy.asm \
    --rust crates/mappy-rom/src/generated.rs \
    --data-dir crates/mappy-rom/data \
    --symbols symbols.txt \
    --coverage /tmp/cov.txt
```

Without `--coverage` the analysis only follows the entry points the 6502 can
reach statically (16 vectors/branches/JSRs and their targets), which finds
1 575 of the 9 878 code bytes: Mappy reaches a lot of its code through
computed jumps. The translated Rust does not depend on that analysis — it
covers all 16 384 offsets either way — but the listing does, which is why the
trace step exists.

## Cross-platform notes

`mos6502`, `nes`, `mappy-rom` and `decompiler` contain no platform-specific
code: no threads, no I/O, no graphics APIs. Only `mappy-player` touches the
outside world, through `winit` (window + keyboard, X11/Wayland/macOS/Windows)
and `cpal` (audio, optional feature). A headless build is one command:

```sh
cargo run --release -p mappy-player --no-default-features -- headless
```

The generated code uses only stable Rust (`edition 2021`) and is portable by
construction.

## Known differences from a real console

* The PPU is dot-accurate for the background pipeline, sprites, sprite-0 hit,
  the odd-frame dot skip and $2005/$2006/$2007 behaviour, but it does not model
  the bus-conflict artifacts of rendering-time VRAM access, sprite overflow
  evaluation order, or the power-on palette state.
* APU mixing uses the documented non-linear curve but is not a die-accurate
  DAC model; DMC DMA cycle stealing is not modelled.
* `$4017` IRQ timing, PAL timing and expansion audio are out of scope.

None of these are exercised by Mappy beyond what is implemented; the
FCEUX comparison above is the evidence.

## Licensing

The 6502 core, the NES hardware model, the decompiler, the frontend and the
tooling are original work, dual-licensed MIT OR Apache-2.0 — see `LICENSE-MIT`
and `LICENSE-APACHE`.

**Mappy is © 1983, 1984 Namco Ltd.**, all rights reserved. Everything derived
from the cartridge — `crates/mappy-rom/data/{prg,chr}.bin`,
`crates/mappy-rom/src/generated.rs`, `disassembly/mappy.asm`,
`demo/mappy-music.wav` and the screenshots — is included so the project runs
and can be studied, and is **not** covered by that license. Treat it as personal
use material, like any other decompilation project: bring your own cartridge
image, keep it non-commercial, and see `NOTICE` for the exact split.

The 6502 conformance suite by Klaus Dormann is GPL; it is fetched by
`tools/fetch_tests.sh` and never vendored here.
