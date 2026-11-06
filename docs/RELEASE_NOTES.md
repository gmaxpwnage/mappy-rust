# Mappy (Japan) (En) — decompiled to Rust

The whole 1984 Namco NES cartridge translated into Rust: 16 384 generated
functions plus a NES hardware model, in one self-contained binary. No emulator
loop, no interpreter — the game's own code is compiled Rust.

## Downloads

| platform | archive |
| --- | --- |
| Linux x86_64 | `mappy-*-linux-x86_64.tar.gz` |
| Linux aarch64 | `mappy-*-linux-aarch64.tar.gz` |
| macOS (Apple silicon) | `mappy-*-macos-arm64.zip` |
| macOS (Intel) | `mappy-*-macos-x86_64.tar.gz` |
| Windows x86_64 | `mappy-*-windows-x86_64.zip` |

Each archive contains:

* `mappy` — the game (window, keyboard, sound). The cartridge data is embedded,
  so no ROM file is needed.
* `decompiler` — turns `Mappy (Japan) (En).nes` into Rust source and an
  annotated disassembly (`decompiler rom/mappy.nes --asm out.asm --rust out.rs`).
* README, NOTICE and the two licence files.

Verify with `sha256sum -c SHA256SUMS.txt`.

## Running it

```sh
tar xzf mappy-*-linux-x86_64.tar.gz && cd mappy-*-linux-x86_64
./mappy                 # or: ./mappy play --stats
```

| NES pad | keys |
| --- | --- |
| D-pad | arrow keys or `W` `A` `S` `D` |
| A | `Z`, `K` or `Space` |
| B | `X` or `J` |
| Start | `Enter` (start the game / pause) |
| Select | `Left/Right Shift` or `Tab` |
| quit | `Esc` or close the window |

Press **Enter** on the title screen. The original only samples a fresh button
press in the exact frame its title loop checks the pad, so if the first press
seems ignored, press it again — that is the game's behaviour, confirmed against
a reference emulator.

Useful flags: `--scale N` (window size), `--no-audio`, `--fps N`,
`--record out.wav` (captures exactly what is played), `--stats` (prints the
measured frame rate once a second).

## Platform notes

* **Linux**: the engine is locked to the console's 60.0988 fps and paced by the
  wall clock. The binary needs ALSA (`libasound.so.2`, present on any desktop
  install) and either X11 or Wayland via the usual system libraries.
* **macOS**: the binaries are not code-signed, so Gatekeeper will complain on
  first launch — right-click → *Open*, or
  `xattr -d com.apple.quarantine mappy`.
* **Windows**: unsigned, so SmartScreen may warn once ("More info" → "Run
  anyway").

## What has been verified

* **The translation is exact**: the generated Rust and a reference 6502
  interpreter run in lockstep for hundreds of frames; registers, cycle counts,
  RAM, PPU state and framebuffer are compared after *every instruction*.
* **The emulation matches hardware**: the 6502 core passes Klaus Dormann's full
  conformance suite; rendering is pixel-identical to a reference emulator
  (title screen, "READY" screen and gameplay); audio was compared against the
  reference's APU model — per-frame channel frequencies and duties match
  exactly, note lengths and rests align to within one frame.
* **It runs at ~850 fps** (14× real time) on one core, including full PPU and
  APU work, while the game itself is paced to 60.

Full details, the annotated disassembly and the reverse-engineering notes are in
the repository: <https://github.com/gmaxpwnage/mappy-rust>

## Copyright

Mappy is © 1983, 1984 Namco Ltd., all rights reserved. These builds are for
personal, non-commercial use with a cartridge you are entitled to use; the
cartridge data they contain is not covered by the MIT/Apache-2.0 licence that
applies to the original engine, decompiler and frontend code. See `NOTICE`.
