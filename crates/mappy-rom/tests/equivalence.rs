//! The proof obligation of a translation: the generated Rust must behave
//! exactly like the original 6502 program.
//!
//! Two engines run the same ROM from the same power-on state — the reference
//! 6502 interpreter in `mos6502` and the Rust code generated from the ROM by
//! `recompiler` — and are compared instruction by instruction. Any difference
//! in registers, cycle count, RAM, PPU state or framebuffer fails the test.

use nes::{button, Cart, Machine};

/// Scripted button presses, mirroring the frontend's input script format.
fn pad(frame: u32) -> u8 {
    let mut p = 0;
    if (20..23).contains(&frame) {
        p |= button::START; // leave the title screen
    }
    if (40..120).contains(&frame) {
        p |= button::RIGHT;
    }
    if (130..140).contains(&frame) {
        p |= button::A;
    }
    if (150..200).contains(&frame) {
        p |= button::LEFT;
    }
    if frame == 205 {
        p |= button::START; // pause
    }
    if frame == 215 {
        p |= button::START; // unpause
    }
    p
}

#[test]
fn translated_matches_interpreter() {
    let cart = Cart::from_image(mappy_rom::PRG.to_vec(), mappy_rom::CHR.to_vec());
    let mut reference = Machine::new(cart);
    let mut translated = mappy_rom::Mappy::new();

    const FRAMES: u32 = 260;
    for frame in 0..FRAMES {
        let buttons = pad(frame);
        reference.pad1 = buttons;
        translated.set_pad1(buttons);

        let target = reference.ppu.frame + 1;
        let mut guard = 0u64;
        while reference.ppu.frame < target {
            reference.step_interpreter();
            translated.step();
            assert_eq!(
                (
                    reference.cpu.pc,
                    reference.cpu.a,
                    reference.cpu.x,
                    reference.cpu.y,
                    reference.cpu.sp,
                    reference.cpu.p,
                    reference.cpu.cycles
                ),
                (
                    translated.machine.cpu.pc,
                    translated.machine.cpu.a,
                    translated.machine.cpu.x,
                    translated.machine.cpu.y,
                    translated.machine.cpu.sp,
                    translated.machine.cpu.p,
                    translated.machine.cpu.cycles
                ),
                "CPU state diverged at frame {frame}"
            );
            guard += 1;
            assert!(guard < 10_000_000, "frame {frame} never completed");
        }

        assert_eq!(reference.ram, translated.machine.ram, "RAM differs at frame {frame}");
        assert_eq!(
            reference.ppu.v, translated.machine.ppu.v,
            "PPU scroll v differs at frame {frame}"
        );
        assert_eq!(
            reference.ppu.nametables, translated.machine.ppu.nametables,
            "nametables differ at frame {frame}"
        );
        assert_eq!(
            reference.ppu.pixels, translated.machine.ppu.pixels,
            "framebuffer differs at frame {frame}"
        );
    }

    // The game must actually be in play by now, not stuck on the title screen.
    assert_eq!(
        translated.machine.ram[0x040F], 2,
        "expected the game to have started (input-enable flag at $040F)"
    );
    assert!(translated.machine.cpu.cycles > 5_000_000);
}
