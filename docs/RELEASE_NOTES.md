# Mappy (Japan) (En) — statically recompiled to Rust

The 1984 Namco NES cartridge translated ahead of time into Rust: 16 384
generated functions running on a Rust model of the NES, in one self-contained
binary with no ROM file and no instruction decoded at run time.

## Changes in 0.1.3

* The tool crate and binary are renamed from `decompiler` to `recompiler`, and
  `docs/DECOMPILATION.md` is now `docs/PROGRAM_STRUCTURE.md`. Archives contain
  `recompiler`, so scripts that call `decompiler` need updating. The old name
  described the output badly: the generated code keeps the 6502's registers,
  stack and cycle counts and dispatches through a PC-indexed table.
* The README, NOTICE, crate descriptions and the browser page now describe what
  the build does: a static recompilation of the cartridge over an emulated NES,
  not decompiled source.
* `mappy headless --engine` accepts `translated` or `interpreter`; the old
  `decompiled` value still selects the translated engine.
* Corrected counts: the 16 384 generated functions cover 4 869 instructions, and
  6 506 PRG offsets are data.

## Downloads

| platform | archive |
| --- | --- |
| Linux x86_64 | `mappy-*-linux-x86_64.tar.gz` |
| Linux aarch64 | `mappy-*-linux-aarch64.tar.gz` |
| macOS (Apple silicon) | `mappy-*-macos-arm64.zip` |
| macOS (Intel) | `mappy-*-macos-x86_64.tar.gz` |
| Windows x86_64 | `mappy-*-windows-x86_64.zip` |
| LG webOS TV | `com.gmaxpwnage.mappy_*_arm.ipk` |

Each archive contains:

* `mappy` — the game (window, keyboard, sound). The cartridge data is embedded,
  so no ROM file is needed.
* `recompiler` — turns `Mappy (Japan) (En).nes` into Rust source and an
  annotated disassembly (`recompiler rom/mappy.nes --asm out.asm --rust out.rs`).
* README, NOTICE and the two licence files.

Every archive unpacks into a single `mappy-<version>-<platform>/` directory.
The webOS package is the native ARM IPK (no archives); `manifest.json` and
`icon320.png` are the Homebrew Channel metadata that go with it.
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
seems ignored, press it again; that is the game's behaviour, confirmed against
a reference emulator.

Useful flags: `--scale N` (window size), `--no-audio`, `--fps N`,
`--record out.wav` (captures exactly what is played), `--stats` (prints the
measured frame rate once a second).

## LG webOS TV

The TV build is a native ARM application, not the WebAssembly page: the
recompiled engine is compiled as a `no_std` static library and driven by a small
SDL2 frontend, then packaged as a standard IPK.

Install it from the Homebrew Channel: Settings → Repositories → Add repository,
and enter

    https://gmaxpwnage.github.io/mappy-rust/webos/apps.json

Mappy then appears in the channel and installs
`com.gmaxpwnage.mappy_<version>_arm.ipk`. The IPK can also be installed with
webOS Dev Manager or `ares-install`. webOS 4.0 or newer is required.

Magic Remote mapping:

| Remote | Game |
| --- | --- |
| Left / Right | move |
| OK (centre) | A, jump |
| Up | Start |
| Down | unbound |
| B | unbound (the game does not use it) |
| Back | exits the app (left to webOS) |

Press **Up** on the title screen to start. The game is paced at 60.0988 fps; on
the tested webOS 6.5.3 TV the engine takes ~11 ms and presentation ~5 ms per
frame, so it holds 60 fps.

## Platform notes

* **Linux**: the engine is locked to the console's 60.0988 fps and paced by the
  wall clock. The binary needs ALSA (`libasound.so.2`, present on any desktop
  install) and either X11 or Wayland via the usual system libraries.
* **macOS**: the binaries are not code-signed, so Gatekeeper will complain on
  first launch: right-click → *Open*, or
  `xattr -d com.apple.quarantine mappy`.
* **Windows**: unsigned, so SmartScreen may warn once ("More info" → "Run
  anyway").
* **NixOS**: a generic glibc binary will not start; that is the distro's design,
  not a bug in the build. Either run it through an FHS environment
  (`steam-run ./mappy`) or build it natively, which takes two minutes:
  `nix run github:gmaxpwnage/mappy-rust`.

## What has been verified

* **The translation is exact**: the generated Rust and a reference 6502
  interpreter run in lockstep for hundreds of frames; registers and cycle counts
  are compared after every instruction, and RAM, PPU state and the framebuffer at
  the end of every frame.
* **The hardware model matches the console**: the 6502 core passes Klaus
  Dormann's full conformance suite; rendering is pixel-identical to a reference
  emulator (title screen, "READY" screen and gameplay); audio was compared
  against the reference's APU model, where per-frame channel frequencies and
  duties match exactly and note lengths and rests align to within one frame.
* **It runs at about 850 frames per second** on one core, including full PPU and
  APU work, while the game itself is paced to 60. The interpreter beside it
  reaches about 730, because the decoder is a small part of a frame.
* **The ARM build is the same game**: the native engine in the webOS IPK
  produces the identical 600-frame video/audio hash on ARM as on x86_64
  (checked under qemu in CI), and holds 60.0 fps on a webOS 6.5.3 TV.

Full details, the annotated disassembly and the reverse-engineering notes are in
the repository: <https://github.com/gmaxpwnage/mappy-rust>

## Copyright

Mappy is © 1983, 1984 Namco Ltd., all rights reserved. These builds are for
personal, non-commercial use with a cartridge you are entitled to use; the
cartridge data they contain is not covered by the MIT/Apache-2.0 licence that
applies to the original engine, recompiler and frontend code. See `NOTICE`.
