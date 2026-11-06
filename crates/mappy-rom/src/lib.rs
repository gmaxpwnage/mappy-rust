//! # mappy-rom
//!
//! The 6502 program of *Mappy (Japan) (En)* translated to Rust, plus the
//! `Machine` glue that runs it.
//!
//! * [`generated`] contains one function per PRG byte offset — the ROM's
//!   instructions as Rust code — and the `DISPATCH` table indexed by PC.
//! * [`Mappy`] bundles the cartridge with the console hardware and provides
//!   the frame-stepping API a frontend needs.
//!
//! The decompiled program drives the NES hardware model in the `nes` crate;
//! it can therefore run on any platform that crate supports.

use nes::{Cart, Machine};

pub mod generated;

/// The ROM image itself, embedded so the game is a self-contained binary.
/// CHR (pattern) data stays as data; the CPU code above is compiled Rust.
pub static PRG: &[u8] = include_bytes!("../data/prg.bin");
pub static CHR: &[u8] = include_bytes!("../data/chr.bin");

/// A running copy of the game.
pub struct Mappy {
    pub machine: Machine,
    /// Frames rendered since power-on.
    pub frame: u64,
}

impl Mappy {
    pub fn new() -> Mappy {
        let cart = Cart::from_image(PRG.to_vec(), CHR.to_vec());
        Mappy { machine: Machine::new(cart), frame: 0 }
    }

    /// Advance the CPU by one instruction using the translated Rust code, and
    /// the PPU/APU by the cycles that instruction took.
    #[inline]
    pub fn step(&mut self) {
        let start = self.machine.cpu.cycles;
        step_engine(&mut self.machine);
        let used = (self.machine.cpu.cycles.wrapping_sub(start)) as u32;
        self.machine.tick(used);
    }

    /// Run until the PPU completes a frame.
    pub fn run_frame(&mut self) {
        let target = self.machine.ppu.frame + 1;
        let mut guard = 0u64;
        while self.machine.ppu.frame < target {
            self.step();
            guard += 1;
            if guard > 40_000_000 || self.machine.cpu.jammed {
                break;
            }
        }
        self.frame += 1;
    }

    /// Controller state for player 1 (bit flags in [`nes::button`]).
    pub fn set_pad1(&mut self, bits: u8) {
        self.machine.pad1 = bits;
    }

    pub fn set_pad2(&mut self, bits: u8) {
        self.machine.pad2 = bits;
    }

    /// Audio samples produced since the last call (`-1.0..=1.0`).
    pub fn take_audio(&mut self) -> Vec<f32> {
        self.machine.apu.drain_samples()
    }

    /// The rendered frame, one NES palette index per pixel.
    pub fn pixels(&self) -> &[u8] {
        &self.machine.ppu.pixels
    }

    /// The rendered frame as `0xRRGGBB` values.
    pub fn rgb(&self) -> Vec<u32> {
        self.machine.framebuffer_rgb()
    }
}

/// One instruction of the decompiled program: interrupts, then the
/// translated instruction selected by the program counter.
#[inline]
pub fn step_engine(m: &mut Machine) {
    if m.cpu.nmi_pending || (m.cpu.irq_line && !m.cpu.flag(mos6502::FLAG_I)) {
        let mut cpu = m.cpu;
        cpu.take_interrupts(m);
        m.cpu = cpu;
        return;
    }
    if m.cpu.pc < 0x8000 {
        m.step_cpu_only();
        return;
    }
    generated::dispatch(m);
}
