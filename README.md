# Mappy (Japan) (En), recompiled from 6502 to Rust

[![CI](https://github.com/gmaxpwnage/mappy-rust/actions/workflows/ci.yml/badge.svg)](https://github.com/gmaxpwnage/mappy-rust/actions/workflows/ci.yml)

Mappy is a 1984 Namco NES cartridge: 16 KiB of 6502 code and data plus 8 KiB of
pattern tables. This repository statically recompiles it to Rust. The PRG image
is translated once, function by function, into a native binary that runs on a
Rust model of the NES hardware. The cartridge is embedded, so the game needs no
ROM file, and no instruction is decoded at run time.

The port runs on Linux, macOS, Windows, in a browser and on LG webOS TVs.

[Play in the browser](https://gmaxpwnage.github.io/mappy-rust/)
· [Downloads](https://github.com/gmaxpwnage/mappy-rust/releases)
· [webOS install](#lg-webos-tv)

## What is in the repository

| path | role |
| --- | --- |
| `crates/recompiler` | reads the ROM, writes the annotated listing and the Rust translation |
| `crates/mappy-rom` | the translated game, the embedded cartridge, the frame loop |
| `crates/mos6502` | 6502 core: interpreter, disassembler, opcode tables |
| `crates/nes` | PPU, APU, NROM cartridge, bus, controllers |
| `crates/mappy-player` | desktop frontend: winit window, cpal audio, headless and analysis commands |
| `crates/mappy-web` | WebAssembly build, nine exported C functions |
| `crates/mappy-native` | `no_std` static library behind the webOS TV build |
| `webos/`, `web/` | SDL2 frontend for the TV, browser page for the web |

## How the translation works

`recompiler` decodes the PRG image and writes one Rust function for every byte
offset in it. A function performs one 6502 instruction against the machine and
sets the program counter to where execution continues:

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
    let ret = next_pc(m, 0x007F) - 1;
    m.push((ret >> 8) as u8);
    m.push(ret as u8);
    m.cpu.pc = 0xC0D0; // pause_sprites
}
```

The opcode fetch becomes a table lookup: `DISPATCH[pc & 0x3FFF](m)` picks the
function for the current program counter, so one indirect call runs one
instruction. Calls stay on the 6502 stack, cycles are still added per
instruction, and the program reads its data tables from the addresses the
original used.

All 151 documented opcodes and the undocumented NMOS opcodes are emitted,
because the translator cannot prove which bytes never run. That is why
`generated.rs` holds 16,384 functions for 4,869 instructions: 6,506 PRG offsets
are data (level layouts, palettes, text, the sound driver's tables), and the
translator emits functions for those too.

## What the output is

The generated code is a translation, not a decompilation. Registers, flags, the
stack and cycle counts are still the 6502's, and control flow still goes through
`DISPATCH`. The machine around the code is an emulator: RAM, cartridge mapping,
a dot-accurate PPU and a full APU. `generated.rs` will not tell you how Mappy
works, and editing it is not how you change the game.

The decompilation in the useful sense is the analysis:

- `disassembly/mappy.asm`, 6,400 lines of annotated listing
- `symbols.txt`, 21 named routines from the reset handler to the Namco sound engine
- `docs/PROGRAM_STRUCTURE.md`, which walks the original program routine by routine:
  the state dispatcher at `$C128`, the VRAM update queue at `$04C0`, the pause
  sprites, the cold-boot check

The translation removes the fetch and decode step and keeps everything else. On
one core the translated engine runs about 850 frames per second, against 730 for
the interpreter in `crates/mos6502` that ships beside it as the test oracle. That
16% is all the decode step is worth, so the emulated PPU and APU remain the
bottleneck. What the translated build buys is a self-contained binary with no ROM
file and no decoder, and one engine behind the desktop, TV and browser builds.

## Play

### In the browser

<https://gmaxpwnage.github.io/mappy-rust/> runs the same engine as WebAssembly.
`crates/mappy-web` exports nine C functions; `web/mappy.js` is the whole
frontend, with canvas, keyboard and touch input, and Web Audio.

### LG webOS TV

The TV build is a native ARM binary, not the web page: `mappy-native` compiled as
a `no_std` static library, with `webos/main.c` around it for SDL2, PulseAudio and
the 60.0988 Hz clock.

In the Homebrew Channel go to Settings → Repositories → Add repository, then
enter:

    https://gmaxpwnage.github.io/mappy-rust/webos/apps.json

The channel installs `com.gmaxpwnage.mappy_<version>_arm.ipk`. The same package
works with webOS Dev Manager or `ares-install`.

| remote | game |
| --- | --- |
| Left / Right | move |
| OK | A, jump |
| Up | Start |
| Back | exit the app |

The game opens on its title screen; press Up to start. webOS 4.0 or newer is
required, because the app uses the SDL2 the TV provides.

To build the IPK:

```sh
rustup target add armv7-unknown-linux-gnueabi
# NDK: https://github.com/openlgtv/buildroot-nc4 (2026.08-webos)
python3 tools/build_webos.py --sdk ~/webos-sdk --out dist/webos --selftest
```

`--selftest` builds a headless ARM binary and, with `QEMU_ARM=qemu-arm`, runs 600
frames under qemu and compares the video and audio hashes with the x86_64 build.
On NixOS the NDK's host tools need an FHS environment, so run the command under
`steam-run`.

Tested on webOS 6.5.3 (ARMv7, ~1 GHz): the engine takes about 11 ms and
presentation about 5 ms per frame, which holds 60.0 fps.

### Downloads

The [releases page](https://github.com/gmaxpwnage/mappy-rust/releases) has Linux
(x86_64, aarch64), macOS (Apple silicon, Intel), Windows x86_64 and the webOS
IPK. Each archive holds `mappy`, the `recompiler` binary and the licence files;
`SHA256SUMS.txt` covers every archive.

## Build and run

```sh
nix develop     # reproducible toolchain, or: source toolchain.env
cargo run --release -p mappy-player -- play
```

No ROM path is needed. The cartridge data is compiled into `mappy-rom` from
`crates/mappy-rom/data/{prg,chr}.bin`. The engine crates have no platform code,
so `cargo run --release -p mappy-player --no-default-features -- headless`
builds without a window or audio.

| key | NES pad |
| --- | --- |
| arrows / `WASD` | D-pad |
| `Z`, `K` or `Space` | A |
| `X` or `J` | B |
| `Enter` | Start |
| `Shift` or `Tab` | Select |
| `Esc` | quit |

The title loop only samples a fresh press on the frame it checks the pad, so a
press can be missed. Press again if nothing happens; FCEUX behaves the same way.

```
mappy play     [--scale N] [--no-audio] [--input SCRIPT] [--fps N] [--stats]
mappy headless [--frames N] [--every N] [--outdir DIR] [--engine translated|interpreter]
mappy trace    [--frames N] [--pc-range LO-HI] [--watch-ram ADDR]
mappy diff     [--frames N] [--input SCRIPT]
mappy ram|nt|probe|bench ...
```

`--input` drives the game with a script of controller input, which is how the
tests play it:

```
--input "START@40-43,RIGHT@90-260,A@270-285,LEFT@500-640"
```

The player advances whole frames against the wall clock at 60.0988 Hz, so game
speed does not follow host throughput. Up to three frames are caught up after a
short stall; a longer stall re-bases the clock. `--stats` prints the measured
rate, audio queue depth and catch-up count; `mappy bench` measures raw engine
speed.

## Verification

Six checks, run in CI or by hand.

1. 6502 core. `mos6502` passes Klaus Dormann's functional test suite (documented
   opcodes, every addressing mode, flags, decimal mode, the `JMP ($xxFF)` page
   bug) over 1.6M instructions. `tools/fetch_tests.sh` fetches the suite, which
   is GPL and not vendored.

2. Translation against the interpreter. `cargo test --release -p mappy-rom` runs
   both engines in lockstep from the same power-on state for 260 frames of
   scripted play, comparing registers and cycle counts after every instruction
   and RAM, scroll registers, nametables and the framebuffer at the end of every
   frame. `mappy diff` runs the same comparison for longer.

3. Video against Mednafen. `tools/compare_mednafen.sh` records Mednafen's output
   of the same ROM, extracts frames with ffmpeg and diffs them against ours.
   Every frame compared so far is identical, across the title screen, the READY
   screen and gameplay.

4. Audio against FCEUX and Mednafen. `tools/audio_check.py` compares per-frame
   channel state with FCEUX and recorded output with Mednafen. Per-frame
   frequencies and duties match FCEUX's model over 200 frames; against
   Mednafen's recording, rests land within one frame and channel levels agree
   within a constant gain offset. The comparison caught six synthesis bugs,
   including a frame sequencer running 2.5x slow and a pulse timer clocked at the
   CPU rate instead of the APU rate.

5. Audio timing. `crates/nes/tests/apu_rate.rs` checks that the APU emits one
   second of samples per second of CPU time at 44.1, 48 and 96 kHz, and about 734
   samples per 60 Hz frame.

6. Game start. `--input "START@19-21"` has to reach the PLAYER 1 READY screen and
   a live score, which the test checks through the input-enable byte at `$040F`.

## Known limits

- The PPU is dot-accurate for the background fetch pipeline, sprites, sprite-0
  hit, the odd-frame dot skip and `$2005`/`$2006`/`$2007` behaviour. It does not
  model bus conflicts on rendering-time VRAM access, sprite overflow evaluation
  order, or the power-on palette.
- APU mixing follows the documented non-linear curve but is not a die-accurate
  DAC model, and DMC DMA cycle stealing is not modelled.
- `$4017` IRQ timing, PAL timing and expansion audio are out of scope.

Mappy does not depend on any behaviour beyond what is implemented; the Mednafen
comparison is the evidence.

## Other paths

```
disassembly/mappy.asm      annotated listing of the original program
symbols.txt                names for the 21 routines identified so far
docs/PROGRAM_STRUCTURE.md  routine-by-routine notes on the original program
docs/RELEASE_NOTES.md      release notes
demo/mappy-music.wav       the soundtrack as rendered by this project
screenshots/               title, READY and gameplay frames
tools/                     opcode generator, emulator comparisons, webOS IPK builder
```

## Regenerating the translation

```sh
source toolchain.env    # or nix develop

# Optional: record which addresses execute during a play session, to recover
# code reached only through the game's computed jumps.
cargo run --release -p mappy-player -- trace --frames 4000 \
    --input "START@19-21,RIGHT@60-400,LEFT@410-700,A@740-760" --out /tmp/cov.txt

cargo run --release -p recompiler -- rom/mappy.nes \
    --asm disassembly/mappy.asm \
    --rust crates/mappy-rom/src/generated.rs \
    --data-dir crates/mappy-rom/data \
    --symbols symbols.txt \
    --coverage /tmp/cov.txt
```

Static analysis alone finds 1,575 of the 9,878 code bytes, because Mappy reaches
much of its code through `JMP ($001E)` and `JMP ($00F6)`. The coverage file
improves the listing only; the translation covers all 16,384 offsets either way.

## Licensing

The 6502 core, the hardware model, the translator, the frontends and the tools
are original work under MIT OR Apache-2.0 (`LICENSE-MIT`, `LICENSE-APACHE`).

Mappy is © 1983, 1984 Namco Ltd., all rights reserved. Everything derived from
the cartridge is excluded from that grant: `crates/mappy-rom/data/{prg,chr}.bin`,
`crates/mappy-rom/src/generated.rs`, `disassembly/mappy.asm`,
`demo/mappy-music.wav` and `screenshots/`. It is included so the project builds
and can be studied. Treat it as personal use material, like any other
ROM-hacking project, and see `NOTICE` for the split.

Klaus Dormann's conformance suite is GPL. `tools/fetch_tests.sh` fetches it; no
vendored file depends on it.
