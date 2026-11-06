//! The machine: CPU + bus + PPU + APU + cartridge.
//!
//! `Machine` is the single mutable object that decompiled code operates on.
//! The generated Rust in `mappy-rom` calls [`Machine::read_byte`],
//! [`Machine::write_byte`] and touches `machine.cpu.*` directly, exactly like
//! the original 6502 code touched memory-mapped registers.

use alloc::vec::Vec;

use crate::apu::Apu;
use crate::cart::Cart;
use crate::ppu::Ppu;
use mos6502::{Bus, Cpu};

/// Controller state bits (NES button order).
pub mod button {
    pub const A: u8 = 1 << 0;
    pub const B: u8 = 1 << 1;
    pub const SELECT: u8 = 1 << 2;
    pub const START: u8 = 1 << 3;
    pub const UP: u8 = 1 << 4;
    pub const DOWN: u8 = 1 << 5;
    pub const LEFT: u8 = 1 << 6;
    pub const RIGHT: u8 = 1 << 7;
}

pub struct Machine {
    pub cpu: Cpu,
    pub ram: [u8; 0x800],
    pub ppu: Ppu,
    pub apu: Apu,
    pub cart: Cart,
    /// Live controller state, as button bitmasks.
    pub pad1: u8,
    pub pad2: u8,
    pad1_shift: u8,
    pad2_shift: u8,
    strobe: bool,
    stall_cycles: u32,
    prev_nmi: bool,
    /// Number of CPU cycles executed since reset (for timing/diagnostics).
    pub total_cycles: u64,
    /// Diagnostics: controller strobes and reads.
    pub pad_writes: u64,
    pub pad_reads: u64,
    pub last_pad_read: u8,
    /// Diagnostics: number of controller reads that returned a 1 bit.
    pub pad_ones: u64,
}

impl Machine {
    pub fn new(cart: Cart) -> Machine {
        let mut m = Machine {
            cpu: Cpu::default(),
            ram: [0; 0x800],
            ppu: Ppu::new(),
            apu: Apu::new(),
            cart,
            pad1: 0,
            pad2: 0,
            pad1_shift: 0,
            pad2_shift: 0,
            strobe: false,
            stall_cycles: 0,
            prev_nmi: false,
            total_cycles: 0,
            pad_writes: 0,
            pad_reads: 0,
            last_pad_read: 0,
            pad_ones: 0,
        };
        m.ppu.mirroring = m.cart.mirroring();
        m.reset();
        m
    }

    pub fn reset(&mut self) {
        self.cpu = Cpu::default();
        self.ram = [0; 0x800];
        // The 2A03 has no decimal mode.
        self.cpu.bcd = false;
        self.ppu = Ppu::new();
        self.ppu.mirroring = self.cart.mirroring();
        // The CPU is a small Copy struct, so give it a copy of the bus view.
        let mut cpu = self.cpu;
        cpu.reset(&mut *self);
        self.cpu = cpu;
        self.total_cycles = 0;
    }

    /// Memory read on behalf of the CPU (the decompiled program calls this).
    #[inline(always)]
    pub fn read_byte(&mut self, addr: u16) -> u8 {
        Bus::read(self, addr)
    }

    /// Memory write on behalf of the CPU (the decompiled program calls this).
    #[inline(always)]
    pub fn write_byte(&mut self, addr: u16, val: u8) {
        Bus::write(self, addr, val)
    }

    /// Read a 16-bit little-endian pointer at `addr`.
    #[inline(always)]
    pub fn read_word(&mut self, addr: u16) -> u16 {
        let lo = self.read_byte(addr) as u16;
        let hi = self.read_byte(addr.wrapping_add(1)) as u16;
        (hi << 8) | lo
    }

    /// Push/pull helpers used by the decompiled stack instructions.
    #[inline(always)]
    pub fn push(&mut self, v: u8) {
        self.write_byte(0x0100 | self.cpu.sp as u16, v);
        self.cpu.sp = self.cpu.sp.wrapping_sub(1);
    }

    #[inline(always)]
    pub fn pop(&mut self) -> u8 {
        self.cpu.sp = self.cpu.sp.wrapping_add(1);
        self.read_byte(0x0100 | self.cpu.sp as u16)
    }

    fn read_pad(&mut self, n: u8) -> u8 {
        self.pad_reads += 1;
        let v = self.read_pad_inner(n);
        self.pad_ones += (v & 1) as u64;
        self.last_pad_read = v;
        v
    }

    fn read_pad_inner(&mut self, n: u8) -> u8 {
        if self.strobe {
            // While strobed the pad keeps reporting the first button (A).
            return if n == 1 { self.pad1 & 0x01 } else { self.pad2 & 0x01 };
        }
        let shift = if n == 1 { &mut self.pad1_shift } else { &mut self.pad2_shift };
        let bit = *shift & 0x01;
        *shift = (*shift >> 1) | 0x80;
        bit
    }

    /// Advance all hardware by `cycles` CPU cycles.
    pub fn tick(&mut self, cycles: u32) {
        let cycles = cycles + self.stall_cycles;
        self.stall_cycles = 0;
        self.total_cycles = self.total_cycles.wrapping_add(cycles as u64);
        self.apu.run(&self.cart, cycles);
        self.ppu.run(&self.cart, cycles);
        if self.ppu.nmi_out && !self.prev_nmi {
            self.cpu.nmi_pending = true;
        }
        self.prev_nmi = self.ppu.nmi_out;
        self.cpu.irq_line = self.apu.irq();
    }

    /// Execute one instruction with the reference interpreter *without*
    /// advancing the PPU/APU. Used as a fallback by the decompiled program,
    /// which dispatches through generated Rust instead.
    pub fn step_cpu_only(&mut self) -> u32 {
        let start = self.cpu.cycles;
        let mut cpu = self.cpu;
        // Taking an interrupt *is* the step, exactly as the decompiled engine
        // does it: the handler's first instruction runs on the next step.
        if !cpu.take_interrupts(self) {
            cpu.step(self);
        }
        self.cpu = cpu;
        (self.cpu.cycles.wrapping_sub(start)) as u32
    }

    /// Run one instruction through the reference 6502 interpreter, keeping
    /// the PPU/APU in step. Returns the number of cycles retired.
    pub fn step_interpreter(&mut self) -> u32 {
        let used = self.step_cpu_only();
        self.tick(used);
        used
    }

    /// Run a whole frame through the interpreter (used by tests).
    pub fn run_frame_interpreter(&mut self) -> u64 {
        let target = self.ppu.frame + 1;
        let mut guard = 0u64;
        while self.ppu.frame < target {
            self.step_interpreter();
            guard += 1;
            if guard > 20_000_000 {
                break;
            }
        }
        guard
    }

    /// Render the current frame as 32-bit RGB pixels, row-major, 256x240.
    pub fn framebuffer_rgb(&self) -> Vec<u32> {
        self.ppu
            .pixels
            .iter()
            .map(|&i| {
                let c = crate::ppu::NES_PALETTE[(i & 0x3F) as usize];
                ((c[0] as u32) << 16) | ((c[1] as u32) << 8) | (c[2] as u32)
            })
            .collect()
    }
}

impl Bus for Machine {
    fn read(&mut self, addr: u16) -> u8 {
        match addr {
            0x0000..=0x1FFF => self.ram[(addr & 0x07FF) as usize],
            0x2000..=0x3FFF => match addr & 0x0007 {
                2 => self.ppu.read_status(),
                4 => self.ppu.read_oam(),
                7 => self.ppu.read_data(&self.cart),
                // Write-only registers return the I/O latch.
                _ => self.ppu.open_bus(),
            },
            0x4000..=0x4014 => 0,
            0x4015 => self.apu.read_status(),
            0x4016 => self.read_pad(1),
            0x4017 => self.read_pad(2),
            0x4018..=0x401F => 0,
            0x4020..=0xFFFF => self.cart.read_prg(addr),
        }
    }

    fn write(&mut self, addr: u16, val: u8) {
        match addr {
            0x0000..=0x1FFF => self.ram[(addr & 0x07FF) as usize] = val,
            0x2000..=0x3FFF => match addr & 0x0007 {
                0 => self.ppu.write_ctrl(val),
                1 => self.ppu.write_mask(val),
                2 => {}
                3 => self.ppu.write_oam_addr(val),
                4 => self.ppu.write_oam_data(val),
                5 => self.ppu.write_scroll(val),
                6 => self.ppu.write_addr(val),
                7 => self.ppu.write_data(&mut self.cart, val),
                _ => {}
            },
            0x4014 => {
                let page = (val as u16) << 8;
                for i in 0..256u16 {
                    let b = self.read_byte(page + i);
                    self.ppu.write_oam_data(b);
                }
                // OAM DMA costs 513 or 514 cycles; we model 514.
                self.stall_cycles += 514;
            }
            0x4016 => {
                self.pad_writes += 1;
                if val & 0x01 != 0 {
                    self.strobe = true;
                    self.pad1_shift = self.pad1;
                    self.pad2_shift = self.pad2;
                } else if self.strobe {
                    self.strobe = false;
                }
            }
            0x4000..=0x4013 | 0x4015..=0x4017 => self.apu.write_register(addr, val),
            0x4018..=0x401F => {}
            0x4020..=0xFFFF => self.cart.write_prg(addr, val),
        }
    }
}
