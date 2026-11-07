# What the original program does

Notes from reading the 6502 code of *Mappy (Japan) (En)*, as recovered by
`recompiler` (see `disassembly/mappy.asm`) and confirmed by tracing execution.
Addresses are CPU addresses in the `$C000-$FFFF` mirror, which is where the
ROM's own vectors point; the cartridge is NROM-128, so that mirror is the same
16 KiB as `$8000-$BFFF`.

## Cartridge

| | |
| --- | --- |
| Format | iNES ("NES 2.0"-flagged header), mapper 0 / NROM-128 |
| PRG | 16 384 bytes, mirrored at `$8000` and `$C000` |
| CHR | 8 192 bytes of pattern tables (2 × 4 KiB) |
| Mirroring | vertical (2 nametables, 512 px of horizontally scrolling playfield) |
| Vectors | NMI `$C2EF`, RESET `$C031`, IRQ/BRK `$C304` |

The PRG image starts with the copyright string
`"COPYRIGHT 1983 1984 NAMCO LTD.ALL RIGHTS RESERVE"` at `$C000-$C030`; the
reset entry point follows immediately at `$C031`.

## Code vs data

`recompiler` statically follows control flow from the three vectors. That finds
1 575 bytes of code. A traced play session (4 000 frames, `mappy trace`) shows
3 757 distinct program counters and, combined with the static sweep, accounts
for **9 878 of the 16 384 PRG bytes as code** (4 869 instructions). The
remaining 6 506 bytes are data tables: level layouts, tile maps, palettes, HUD
text, the Namco sound driver's tables, and a block of graphics-looking data
used for cut-scenes.

The gap is because Mappy reaches much of its code through computed jumps. Two
mechanisms are used:

* `JMP ($001E)` — a jump through a zero-page pointer (seen at `$C13B`);
* `JMP ($00F6)` — a second indirect jump, used by the sound engine.

Because the translated Rust covers *every* byte offset, this does not affect
the translated game; it only affects how much of the listing can be classified
statically.

## Boot sequence

```
C031  SEI / CLD                 ; no interrupts, binary mode
C033  LDX #$5F / TXS            ; stack at $015F
C036  $2000 = 0, $2001 = 0      ; PPU off
C03E  wait for $2002 bit 7      ; first vblank of the console
C043  clear $0000-$07FF         ; zero page + stack + RAM in descending page order
C055  JSR $C25C                 ; cold-boot check
C058  $3E/$3F = $5A/$A5         ; "warm boot" magic for the next reset
C060  LDY #$00 / JSR $C128      ; dispatch state table entry 0
```

`sub_C25C` compares `$3E/$3F` with `$5A/$A5`. On a cold boot the magic is gone
(it was just zeroed), so the code clears `$0020-$00FF`, sets `$45 = 2` and
`$77 = 1`; on a warm reset it restores player state that `sub_C2B3` saved.

`sub_C128` is the **state dispatcher**: it loads the target from the table at
`$C13E`, stashes the current stack pointer at `$0100` (so the state can return
to the dispatcher later), and does `JMP ($001E)`. Entry 0 of that table is
`$C84F`, the title screen. The pointer-patching helpers at `$C141`/`$C146`
(`stack_frame_swap`) are the other half of that mechanism.

## Main loop

`$C06D` is the frame loop. It is synchronous with vblank through the counter at
`$20`, which the NMI handler increments:

```
C06D  LDA $20 / BEQ $C06D       ; wait until the NMI bumped the frame flag
C071  $4014 = $07               ; OAM DMA from the shadow buffer at $0700
C076  JSR $C150                 ; flush VRAM update queues (rendering off)
C079  JSR $C1C9                 ; read and decode both controllers
C07C  JSR $C0D0                 ; blink the "PAUSE" sprites, or hide OAM
C083  ... A = $28/$29 >> ...    ; horizontal scroll = camera position
C092  $2005 = scroll X, $2005 = 0
C09A  $2000 = $88               ; NMI on, sprite patterns at $1000
C0A1  JSR $F4F1                 ; sound engine tick (also called from NMI)
C0A4  ...                       ; pause handling
C0BF  JSR $C7C9                 ; upload the animated attribute table
C0C4  JSR $C146                 ; stack-frame swap back to the state machine
C0C7  INC $21 / $20 = 0         ; next frame
C0CD  JMP $C06D
```

### The status bar "split"

There is no sprite-0 hit. The fixed top status bar is produced by *timing*:

1. `sub_C150` turns rendering off (`$2001 = 0`), replays the VRAM write queue at
   `$0500` (entries: address high, address low, count, data) and the "read"
   queue at `$04C0` (which copies VRAM bytes into the RAM buffer pointed to by
   `$1E/$1F`, used for attribute read-modify-write).
2. It then writes scroll `(0, 0)` twice and re-enables NMI, and finally burns
   cycles in two NOP loops whose lengths depend on how many queue entries were
   processed (`$2A`, `$2B`).
3. Only later in the frame, at `$C092`, does the main loop write the playfield's
   horizontal scroll.

The NOP loops are deliberate cycle padding: they place the moment the playfield
scroll is written at a fixed scanline, so the top scanlines render with scroll 0
(the status bar) and the rest with the camera scroll. This is why the status bar
is rock steady while the playfield scrolls, and it is why the game tolerates
VRAM updates that run into the first visible scanlines.

### VRAM update queue

`$0500` holds a byte queue built by ad-hoc routines; `$2A` is its write index.
Format: `hi, lo, count, bytes...`, replayed through `$2006`/`$2007`.
`$04C0` is a parallel queue used for reads: its entries give a VRAM address and
a RAM destination, and the fetched byte is stored at `(dest)+8`.

### Attribute animation

`$0180-$01BF` holds a 64-byte attribute-table image. `sub_C7C9` copies it to
both nametables (`$23C0` and `$27C0`) every frame via `sub_C7E2`, which is how
the "namcot" logo on the title screen and other palette effects animate.

## Controllers

```
C1C9  LDX #1 / $4016 = X / DEX / $4016 = X   ; strobe high then low
C1D2  JSR $C249 with X=0                     ; 8 bits of pad 1 into $10
C1D5  INX / JSR $C249                        ; 8 bits of pad 2 into $11
```

`sub_C249` reads `$4016,X` eight times and rotates each result into `$10,X`
through carry, producing the conventional layout (bit 0 = A … bit 7 = Right).

The code after that is unusual: it *mangles the two pad bytes through the
carry chain* into a rolling 8-bit shift register at `$25` (and `$22`/`$24`),
which is how the game tests for a **fresh** button press: `$25 & 3 == 1` means
"pressed this frame, not last frame". The title screen tests exactly that at
`$C89C`, which is why a press has to land in the frame the game samples it.
`$26`/`$27` decode Select/Start through the table at `$C258`.

`$42` gates the input logic: it is 0 on the title screen and set to 1 by
`$C8AB` when a game starts, after which Start toggles the pause flag at `$23`.

## State machine and game start

`sub_C84F` draws the title screen, waits for Start (`$C89C`), and falls through
to `$C8AB` (`$42 = 1`, player/score/HUD initialisation) or times out after 240
iterations and jumps to `$FF65`, which is the attract-mode entry (it repeats
the same initialisation and lets the game play itself).

`$C931` writes `$040F = 2` — the per-player "input enabled" byte — for every
active player, at `$040F`, `$042F`, `$044F`, … stepping by `$10`. The input
routine at `$C21B` refuses to act unless that byte is non-zero, which is also
the condition the equivalence test uses to prove that the game really started.

## Sound

`sub_F4F1` is called both from the NMI handler (when `$20 != 0`) and from the
main loop at `$C0A1`. It is the driver entry point: register writes go to
`$4000-$4013` and the frame counter at `$4017` is programmed at `$F4BD`
(`$4015 = $C0`, `$4017 = $19`). The channel mixer at `$F80B` is called from 13
places. Sound data (note tables, envelopes, and what look like short DPCM
drum samples) lives in the last kilobyte of the image.

## RAM map (what has been identified)

| Address | Use |
| --- | --- |
| `$00/$01` | indirect pointer scratch (RAM clear, block fill) |
| `$10/$11` | raw pad bytes after `sub_C249` |
| `$12/$13` | attribute-upload source index and count |
| `$1E/$1F` | pointer for `JMP ($001E)` and for VRAM read destinations |
| `$20` | vblank flag: set by NMI, cleared at the end of the main loop |
| `$21` | main-loop frame counter (bit 4 drives the "PAUSE" blink) |
| `$22`, `$24`, `$25` | decoded controller history; `$25 & 3 == 1` = fresh press |
| `$23` | pause flag |
| `$26`/`$27` | decoded Select/Start value and its "changed" flag |
| `$28`/`$29` | camera position, shifted by three to form scroll X |
| `$2A`/`$2B` | VRAM write / read queue indices |
| `$3E`/`$3F` | `$5A/$A5` cold-boot magic |
| `$40`/`$41` | current player number (0 or 1) |
| `$42` | "game in progress" flag (gates input processing) |
| `$45`, `$48`, `$49`, `$70-$7F` | game/sound state |
| `$B0-$EF` | player state blocks (copied from `$70` page on start) |
| `$0180-$01BF` | attribute-table image |
| `$0400-$04BF` | per-player game state (e.g. `$040F` input enable) |
| `$04C0-$04FF` | VRAM *read* queue |
| `$0500-$05FF` | VRAM *write* queue |
| `$0600-$06FF` | level/game event state |
| `$0700-$07FF` | OAM shadow (DMA source) |

Page `$0200`/`$0300` are sprite-related buffers (`$0200` is copied to `$0300`
on level start), and `$0100` is the stack, whose bottom word is used by the
state dispatcher.

## Not fully reversed

The game logic itself — player physics, the enemies (cats, mice), the doors,
bonus items, level progression — has been translated faithfully but not yet
given names; those routines still carry `sub_XXXX` names in `symbols.txt`
territory. The sound engine's data format is likewise translated but not
documented. Both are mechanical next steps: the translated Rust is already
exact, so naming them is a matter of reading `disassembly/mappy.asm` with the
frame-by-frame tools (`mappy trace --pc-range`, `mappy ram --at`,
`mappy nt`, `mappy probe`) that ship with the project.
