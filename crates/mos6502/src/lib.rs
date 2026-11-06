//! A cycle-counted NMOS 6502 CPU: the reference interpreter.
//!
//! This crate serves two purposes in the `mappy` decompilation project:
//!
//! 1. It is the **specification** of 6502 semantics (see the `adc_val`,
//!    `sbc_val`, ... helpers, which the generated Rust uses as well), and
//! 2. it is the **oracle** used by the differential tests that prove the
//!    transpiled Rust code in `mappy-rom` behaves exactly like the ROM.
//!
//! The game itself does *not* run through this interpreter; it runs through
//! machine code that `decompiler` translated to Rust source.

#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

pub mod disasm;
pub mod opcodes;

pub use opcodes::{Kind, Mode, Op, OPCODES};

/// Status register bits.
pub const FLAG_C: u8 = 0x01;
pub const FLAG_Z: u8 = 0x02;
pub const FLAG_I: u8 = 0x04;
pub const FLAG_D: u8 = 0x08;
pub const FLAG_B: u8 = 0x10;
pub const FLAG_U: u8 = 0x20;
pub const FLAG_V: u8 = 0x40;
pub const FLAG_N: u8 = 0x80;

/// The memory bus as seen by the CPU.
pub trait Bus {
    fn read(&mut self, addr: u16) -> u8;
    fn write(&mut self, addr: u16, val: u8);
}

// ---------------------------------------------------------------------------
// Semantics helpers.
//
// The generated Rust in `mappy-rom` calls these too, so a fix here fixes both
// the interpreter and the decompiled program at once.
// ---------------------------------------------------------------------------

/// `ADC`: returns (result, carry out, overflow).
#[inline(always)]
pub fn adc_val(a: u8, b: u8, carry_in: bool) -> (u8, bool, bool) {
    let sum = a as u16 + b as u16 + carry_in as u16;
    let r = sum as u8;
    let carry = sum > 0xFF;
    let overflow = (a ^ r) & (b ^ r) & 0x80 != 0;
    (r, carry, overflow)
}

/// `SBC`: returns (result, carry out, overflow).
#[inline(always)]
pub fn sbc_val(a: u8, b: u8, carry_in: bool) -> (u8, bool, bool) {
    // Equivalent to ADC with the operand inverted; this is what the NMOS die does.
    adc_val(a, b ^ 0xFF, carry_in)
}

/// Decimal-mode `ADC` (BCD adjust). Returns (Bcd result, carry out).
///
/// The N/Z/V flags of the NMOS 6502 come from the *binary* sum, so callers
/// keep those from [`adc_val`]; only the accumulator and carry differ.
#[inline(always)]
pub fn adc_decimal(a: u8, b: u8, carry_in: bool) -> (u8, bool) {
    let c = carry_in as u8;
    let mut lo = (a & 0x0F) + (b & 0x0F) + c;
    if lo > 9 {
        lo = lo.wrapping_add(6);
    }
    let mut hi = (a >> 4) + (b >> 4) + ((lo > 0x0F) as u8);
    if hi > 9 {
        hi = hi.wrapping_add(6);
    }
    let carry = hi > 0x0F;
    ((hi << 4) | (lo & 0x0F), carry)
}

/// Decimal-mode `SBC` (BCD adjust). Returns (Bcd result, carry out = !borrow).
#[inline(always)]
pub fn sbc_decimal(a: u8, b: u8, carry_in: bool) -> (u8, bool) {
    let borrow = if carry_in { 0 } else { 1 };
    let mut lo = (a & 0x0F) as i16 - (b & 0x0F) as i16 - borrow;
    let mut hi = (a >> 4) as i16 - (b >> 4) as i16;
    if lo < 0 {
        lo -= 6;
        hi -= 1;
    }
    if hi < 0 {
        hi -= 6;
    }
    let carry = hi >= 0;
    let res = (((hi as u8) << 4) | ((lo as u8) & 0x0F)) as u8;
    (res, carry)
}

/// `ASL`: returns (result, carry out).
#[inline(always)]
pub fn asl_val(v: u8) -> (u8, bool) {
    (v << 1, v & 0x80 != 0)
}

/// `LSR`: returns (result, carry out).
#[inline(always)]
pub fn lsr_val(v: u8) -> (u8, bool) {
    (v >> 1, v & 0x01 != 0)
}

/// `ROL`: returns (result, carry out).
#[inline(always)]
pub fn rol_val(v: u8, carry_in: bool) -> (u8, bool) {
    ((v << 1) | carry_in as u8, v & 0x80 != 0)
}

/// `ROR`: returns (result, carry out).
#[inline(always)]
pub fn ror_val(v: u8, carry_in: bool) -> (u8, bool) {
    ((v >> 1) | ((carry_in as u8) << 7), v & 0x01 != 0)
}

/// Compare helper used by `CMP`/`CPX`/`CPY`: returns (result, carry out).
#[inline(always)]
pub fn cmp_val(a: u8, b: u8) -> (u8, bool) {
    let r = a.wrapping_sub(b);
    (r, a >= b)
}

/// Address of a 16-bit little-endian pointer at `addr`, honouring the NMOS
/// page-crossing bug on the high byte. Used by `JMP ($xxxx)`.
#[inline(always)]
pub fn read_ptr_buggy<B: Bus>(bus: &mut B, addr: u16) -> u16 {
    let lo = bus.read(addr) as u16;
    let hi_addr = (addr & 0xFF00) | ((addr.wrapping_add(1)) & 0x00FF);
    let hi = bus.read(hi_addr) as u16;
    (hi << 8) | lo
}

/// The CPU state. All of the 6502's architecturally visible state lives here.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Cpu {
    pub a: u8,
    pub x: u8,
    pub y: u8,
    pub sp: u8,
    pub pc: u16,
    pub p: u8,
    /// Total cycles retired since reset.
    pub cycles: u64,
    /// Instructions retired since reset.
    pub instructions: u64,
    /// Edge-triggered NMI latch (set by the PPU at vblank).
    pub nmi_pending: bool,
    /// Level-triggered IRQ line (APU / mapper).
    pub irq_line: bool,
    /// Set if execution landed on an unimplemented (JAM/KIL) opcode.
    pub jammed: bool,
    /// Whether decimal (BCD) mode is implemented. The NES's 2A03 has decimal
    /// mode fused off, so the NES bus clears this; a plain 6502 sets it.
    pub bcd: bool,
}

impl Default for Cpu {
    fn default() -> Self {
        Cpu {
            a: 0,
            x: 0,
            y: 0,
            sp: 0xFD,
            pc: 0,
            p: FLAG_U | FLAG_I,
            cycles: 0,
            instructions: 0,
            nmi_pending: false,
            irq_line: false,
            jammed: false,
            bcd: false,
        }
    }
}

impl Cpu {
    #[inline(always)]
    pub fn flag(&self, f: u8) -> bool {
        self.p & f != 0
    }

    #[inline(always)]
    pub fn set_flag(&mut self, f: u8, on: bool) {
        if on {
            self.p |= f;
        } else {
            self.p &= !f;
        }
    }

    /// Set N and Z from `v` (the extremely common load/compare tail).
    #[inline(always)]
    pub fn set_nz(&mut self, v: u8) {
        self.p = (self.p & !(FLAG_N | FLAG_Z)) | (v & FLAG_N) | if v == 0 { FLAG_Z } else { 0 };
    }

    #[inline(always)]
    pub fn add_cycles(&mut self, n: u32) {
        self.cycles = self.cycles.wrapping_add(n as u64);
    }

    pub fn reset<B: Bus>(&mut self, bus: &mut B) {
        self.a = 0;
        self.x = 0;
        self.y = 0;
        self.sp = 0xFD;
        self.p = FLAG_U | FLAG_I;
        self.pc = read_u16(bus, 0xFFFC);
        self.jammed = false;
        self.cycles = self.cycles.wrapping_add(7);
    }

    /// Push one byte on the stack.
    #[inline(always)]
    pub fn push<B: Bus>(&mut self, bus: &mut B, v: u8) {
        bus.write(0x0100 | self.sp as u16, v);
        self.sp = self.sp.wrapping_sub(1);
    }

    /// Pull one byte from the stack.
    #[inline(always)]
    pub fn pop<B: Bus>(&mut self, bus: &mut B) -> u8 {
        self.sp = self.sp.wrapping_add(1);
        bus.read(0x0100 | self.sp as u16)
    }

    /// Service a pending NMI or IRQ. Returns true when an interrupt was taken.
    ///
    /// This runs between instructions, which is when the real 6502 samples
    /// the interrupt lines.
    pub fn take_interrupts<B: Bus>(&mut self, bus: &mut B) -> bool {
        if self.nmi_pending {
            self.nmi_pending = false;
            self.interrupt(bus, 0xFFFA);
            true
        } else if self.irq_line && !self.flag(FLAG_I) {
            self.interrupt(bus, 0xFFFE);
            true
        } else {
            false
        }
    }

    pub fn interrupt<B: Bus>(&mut self, bus: &mut B, vector: u16) {
        let pc = self.pc;
        self.push(bus, (pc >> 8) as u8);
        self.push(bus, pc as u8);
        // The pushed status has B clear, U set, and I set (interrupts disabled).
        self.push(bus, (self.p & !FLAG_B) | FLAG_U);
        self.set_flag(FLAG_I, true);
        self.pc = read_u16(bus, vector);
        self.add_cycles(7);
    }

    /// Execute one instruction. Returns the number of cycles it took.
    pub fn step<B: Bus>(&mut self, bus: &mut B) -> u32 {
        if self.jammed {
            return 1;
        }
        let opcode = bus.read(self.pc);
        self.pc = self.pc.wrapping_add(1);
        let op = &OPCODES[opcode as usize];
        let cyc = self.execute(bus, op);
        self.instructions = self.instructions.wrapping_add(1);
        self.add_cycles(cyc);
        cyc
    }

    fn fetch<B: Bus>(&mut self, bus: &mut B) -> u8 {
        let v = bus.read(self.pc);
        self.pc = self.pc.wrapping_add(1);
        v
    }

    fn fetch16<B: Bus>(&mut self, bus: &mut B) -> u16 {
        let lo = self.fetch(bus) as u16;
        let hi = self.fetch(bus) as u16;
        (hi << 8) | lo
    }

    /// Resolve an addressing mode to (effective address, page crossed).
    /// `Imm`, `Acc`, `Impl` and `Rel` do not go through this function.
    fn effective_addr<B: Bus>(&mut self, bus: &mut B, mode: Mode) -> (u16, bool) {
        match mode {
            Mode::Zp => (self.fetch(bus) as u16, false),
            Mode::Zpx => (self.fetch(bus).wrapping_add(self.x) as u16, false),
            Mode::Zpy => (self.fetch(bus).wrapping_add(self.y) as u16, false),
            Mode::Abs => (self.fetch16(bus), false),
            Mode::AbsX => {
                let base = self.fetch16(bus);
                let addr = base.wrapping_add(self.x as u16);
                (addr, page_crossed(base, addr))
            }
            Mode::AbsY => {
                let base = self.fetch16(bus);
                let addr = base.wrapping_add(self.y as u16);
                (addr, page_crossed(base, addr))
            }
            Mode::IndX => {
                let zp = self.fetch(bus).wrapping_add(self.x);
                let lo = bus.read(zp as u16) as u16;
                let hi = bus.read(zp.wrapping_add(1) as u16) as u16;
                ((hi << 8) | lo, false)
            }
            Mode::IndY => {
                let zp = self.fetch(bus);
                let lo = bus.read(zp as u16) as u16;
                let hi = bus.read(zp.wrapping_add(1) as u16) as u16;
                let base = (hi << 8) | lo;
                let addr = base.wrapping_add(self.y as u16);
                (addr, page_crossed(base, addr))
            }
            _ => unreachable!("effective_addr used with non-memory mode"),
        }
    }

    fn execute<B: Bus>(&mut self, bus: &mut B, op: &Op) -> u32 {
        use Kind::*;
        let mut cycles = op.cycles as u32;
        match op.kind {
            // ---- complete instructions with no memory operand ----------
            Brk => {
                self.pc = self.pc.wrapping_add(1); // padding byte
                let pc = self.pc;
                self.push(bus, (pc >> 8) as u8);
                self.push(bus, pc as u8);
                self.push(bus, self.p | FLAG_B | FLAG_U);
                self.set_flag(FLAG_I, true);
                self.pc = read_u16(bus, 0xFFFE);
            }
            Jmp => match op.mode {
                Mode::Abs => self.pc = self.fetch16(bus),
                Mode::Ind => {
                    let ptr = self.fetch16(bus);
                    self.pc = read_ptr_buggy(bus, ptr);
                }
                _ => unreachable!(),
            },
            Jsr => {
                let target = self.fetch16(bus);
                let ret = self.pc.wrapping_sub(1);
                self.push(bus, (ret >> 8) as u8);
                self.push(bus, ret as u8);
                self.pc = target;
            }
            Rts => {
                let lo = self.pop(bus) as u16;
                let hi = self.pop(bus) as u16;
                self.pc = ((hi << 8) | lo).wrapping_add(1);
            }
            Rti => {
                self.p = (self.pop(bus) & !FLAG_B) | FLAG_U;
                let lo = self.pop(bus) as u16;
                let hi = self.pop(bus) as u16;
                self.pc = (hi << 8) | lo;
            }
            Pha => {
                let v = self.a;
                self.push(bus, v);
            }
            Php => {
                let v = self.p | FLAG_B | FLAG_U;
                self.push(bus, v);
            }
            Pla => {
                self.a = self.pop(bus);
                let v = self.a;
                self.set_nz(v);
            }
            Plp => self.p = (self.pop(bus) & !FLAG_B) | FLAG_U,
            Clc => self.set_flag(FLAG_C, false),
            Sec => self.set_flag(FLAG_C, true),
            Cli => self.set_flag(FLAG_I, false),
            Sei => self.set_flag(FLAG_I, true),
            Clv => self.set_flag(FLAG_V, false),
            Cld => self.set_flag(FLAG_D, false),
            Sed => self.set_flag(FLAG_D, true),
            Dex => {
                self.x = self.x.wrapping_sub(1);
                let v = self.x;
                self.set_nz(v);
            }
            Dey => {
                self.y = self.y.wrapping_sub(1);
                let v = self.y;
                self.set_nz(v);
            }
            Inx => {
                self.x = self.x.wrapping_add(1);
                let v = self.x;
                self.set_nz(v);
            }
            Iny => {
                self.y = self.y.wrapping_add(1);
                let v = self.y;
                self.set_nz(v);
            }
            Tax => {
                self.x = self.a;
                let v = self.x;
                self.set_nz(v);
            }
            Tay => {
                self.y = self.a;
                let v = self.y;
                self.set_nz(v);
            }
            Txa => {
                self.a = self.x;
                let v = self.a;
                self.set_nz(v);
            }
            Tya => {
                self.a = self.y;
                let v = self.a;
                self.set_nz(v);
            }
            Tsx => {
                self.x = self.sp;
                let v = self.x;
                self.set_nz(v);
            }
            Txs => self.sp = self.x,
            // ------------------------------------------------------------
            // Branches.
            // ------------------------------------------------------------
            kind if kind.is_branch() => {
                let off = self.fetch(bus) as i8;
                let taken = match kind {
                    Bcc => !self.flag(FLAG_C),
                    Bcs => self.flag(FLAG_C),
                    Beq => self.flag(FLAG_Z),
                    Bne => !self.flag(FLAG_Z),
                    Bmi => self.flag(FLAG_N),
                    Bpl => !self.flag(FLAG_N),
                    Bvc => !self.flag(FLAG_V),
                    Bvs => self.flag(FLAG_V),
                    _ => unreachable!(),
                };
                if taken {
                    cycles += 1;
                    let base = self.pc;
                    let target = base.wrapping_add(off as u16);
                    if page_crossed(base, target) {
                        cycles += 1;
                    }
                    self.pc = target;
                }
            }
            // ------------------------------------------------------------
            // Immediate-mode instructions.
            // ------------------------------------------------------------
            kind => match op.mode {
                Mode::Imm => {
                    let v = self.fetch(bus);
                    self.apply_imm(bus, kind, v, &mut cycles);
                }
                Mode::Acc => {
                    self.apply_acc(bus, kind, &mut cycles);
                }
                Mode::Impl => {
                    // Implied NOP (and the JAM opcodes).
                    if kind == Kil {
                        self.jammed = true;
                    }
                }
                _ => {
                    let (addr, crossed) = self.effective_addr(bus, op.mode);
                    if op.page_penalty && crossed {
                        cycles += 1;
                    }
                    self.apply_mem(bus, kind, addr, &mut cycles);
                }
            },
        }
        cycles
    }

    fn apply_imm<B: Bus>(&mut self, bus: &mut B, kind: Kind, v: u8, _cycles: &mut u32) {
        use Kind::*;
        let _ = bus;
        match kind {
            Ora => {
                self.a |= v;
                let a = self.a;
                self.set_nz(a);
            }
            And => {
                self.a &= v;
                let a = self.a;
                self.set_nz(a);
            }
            Eor => {
                self.a ^= v;
                let a = self.a;
                self.set_nz(a);
            }
            Adc => {
                let c = self.flag(FLAG_C);
                let (bin, bin_carry, ovf) = adc_val(self.a, v, c);
                if self.bcd && self.flag(FLAG_D) {
                    let (r, carry) = adc_decimal(self.a, v, c);
                    self.a = r;
                    self.set_flag(FLAG_C, carry);
                    // NMOS quirk: N/Z/V reflect the binary, not the BCD, result.
                    self.set_flag(FLAG_V, ovf);
                    self.set_flag(FLAG_N, bin & FLAG_N != 0);
                    self.set_flag(FLAG_Z, bin == 0);
                } else {
                    self.a = bin;
                    self.set_flag(FLAG_C, bin_carry);
                    self.set_flag(FLAG_V, ovf);
                    self.set_nz(bin);
                }
            }
            Sbc => {
                let c = self.flag(FLAG_C);
                let (bin, bin_carry, ovf) = sbc_val(self.a, v, c);
                if self.bcd && self.flag(FLAG_D) {
                    let (r, carry) = sbc_decimal(self.a, v, c);
                    self.a = r;
                    self.set_flag(FLAG_C, carry);
                    self.set_flag(FLAG_V, ovf);
                    self.set_flag(FLAG_N, bin & FLAG_N != 0);
                    self.set_flag(FLAG_Z, bin == 0);
                } else {
                    self.a = bin;
                    self.set_flag(FLAG_C, bin_carry);
                    self.set_flag(FLAG_V, ovf);
                    self.set_nz(bin);
                }
            }
            Lda => {
                self.a = v;
                self.set_nz(v);
            }
            Ldx => {
                self.x = v;
                self.set_nz(v);
            }
            Ldy => {
                self.y = v;
                self.set_nz(v);
            }
            Cmp => {
                let (r, carry) = cmp_val(self.a, v);
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            Cpx => {
                let (r, carry) = cmp_val(self.x, v);
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            Cpy => {
                let (r, carry) = cmp_val(self.y, v);
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            // ---- undocumented, immediate ----
            Anc => {
                self.a &= v;
                let a = self.a;
                self.set_nz(a);
                self.set_flag(FLAG_C, a & FLAG_N != 0);
            }
            Alr => {
                self.a &= v;
                let (r, carry) = lsr_val(self.a);
                self.a = r;
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            Arr => {
                self.a &= v;
                let c = self.flag(FLAG_C);
                let (r, carry) = ror_val(self.a, c);
                self.a = r;
                self.set_flag(FLAG_C, carry);
                self.set_flag(FLAG_V, ((r >> 6) ^ (r >> 5)) & 1 != 0);
                self.set_nz(r);
            }
            Xaa => {
                // Unstable on real hardware; the commonly observed behaviour.
                let v = (self.a | 0xEE) & v;
                self.a = v;
                self.x = v;
                self.set_nz(v);
            }
            Axs => {
                let (r, carry) = cmp_val(self.a & self.x, v);
                self.set_flag(FLAG_C, carry);
                self.x = r;
                self.set_nz(r);
            }
            Lax => {
                self.a = v;
                self.x = v;
                self.set_nz(v);
            }
            Bit => {
                self.set_flag(FLAG_Z, (self.a & v) == 0);
                self.set_flag(FLAG_N, v & FLAG_N != 0);
                self.set_flag(FLAG_V, v & FLAG_V != 0);
            }
            Las => {
                let v = v & self.sp;
                self.a = v;
                self.x = v;
                self.sp = v;
                self.set_nz(v);
            }
            Nop => {}
            Kil => self.jammed = true,
            // Not reachable through an immediate/read operand: these are
            // executed directly by `execute` (implied, stack, branch, jump) or
            // by `apply_mem` / `apply_acc` (RMW, store, accumulator).
            Asl | AslA | Lsr | LsrA | Rol | RolA | Ror | RorA | Inc | Dec | Slo | Rla | Sre
            | Rra | Dcp | Isc | Sta | Stx | Sty | Sax | Ahx | Shy | Shx | Tas | Brk | Bcc
            | Bcs | Beq | Bmi | Bne | Bpl | Bvc | Bvs | Clc | Cld | Cli | Clv | Dex | Dey
            | Inx | Iny | Jmp | Jsr | Pha | Php | Pla | Plp | Rti | Rts | Sec | Sed | Sei
            | Tax | Tay | Tsx | Txa | Txs | Tya => {
                unreachable!("kind {:?} cannot appear here", kind)
            }
        }
    }

    fn apply_acc<B: Bus>(&mut self, _bus: &mut B, kind: Kind, _cycles: &mut u32) {
        use Kind::*;
        match kind {
            AslA => {
                let (r, carry) = asl_val(self.a);
                self.a = r;
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            LsrA => {
                let (r, carry) = lsr_val(self.a);
                self.a = r;
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            RolA => {
                let c = self.flag(FLAG_C);
                let (r, carry) = rol_val(self.a, c);
                self.a = r;
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            RorA => {
                let c = self.flag(FLAG_C);
                let (r, carry) = ror_val(self.a, c);
                self.a = r;
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
            }
            _ => unreachable!(),
        }
    }

    fn apply_mem<B: Bus>(&mut self, bus: &mut B, kind: Kind, addr: u16, _cycles: &mut u32) {
        use Kind::*;
        // Read-modify-write instructions first: they read, then write.
        match kind {
            Asl => {
                let (r, carry) = asl_val(bus.read(addr));
                bus.write(addr, r);
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
                return;
            }
            Lsr => {
                let (r, carry) = lsr_val(bus.read(addr));
                bus.write(addr, r);
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
                return;
            }
            Rol => {
                let c = self.flag(FLAG_C);
                let (r, carry) = rol_val(bus.read(addr), c);
                bus.write(addr, r);
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
                return;
            }
            Ror => {
                let c = self.flag(FLAG_C);
                let (r, carry) = ror_val(bus.read(addr), c);
                bus.write(addr, r);
                self.set_flag(FLAG_C, carry);
                self.set_nz(r);
                return;
            }
            Inc => {
                let r = bus.read(addr).wrapping_add(1);
                bus.write(addr, r);
                self.set_nz(r);
                return;
            }
            Dec => {
                let r = bus.read(addr).wrapping_sub(1);
                bus.write(addr, r);
                self.set_nz(r);
                return;
            }
            Slo => {
                let (r, carry) = asl_val(bus.read(addr));
                bus.write(addr, r);
                self.a |= r;
                let a = self.a;
                self.set_flag(FLAG_C, carry);
                self.set_nz(a);
                return;
            }
            Rla => {
                let c = self.flag(FLAG_C);
                let (r, carry) = rol_val(bus.read(addr), c);
                bus.write(addr, r);
                self.a &= r;
                let a = self.a;
                self.set_flag(FLAG_C, carry);
                self.set_nz(a);
                return;
            }
            Sre => {
                let (r, carry) = lsr_val(bus.read(addr));
                bus.write(addr, r);
                self.a ^= r;
                let a = self.a;
                self.set_flag(FLAG_C, carry);
                self.set_nz(a);
                return;
            }
            Rra => {
                let c = self.flag(FLAG_C);
                let (r, carry) = ror_val(bus.read(addr), c);
                bus.write(addr, r);
                let (res, c2, ovf) = adc_val(self.a, r, carry);
                self.a = res;
                self.set_flag(FLAG_C, c2);
                self.set_flag(FLAG_V, ovf);
                self.set_nz(res);
                return;
            }
            Dcp => {
                let r = bus.read(addr).wrapping_sub(1);
                bus.write(addr, r);
                let (res, carry) = cmp_val(self.a, r);
                self.set_flag(FLAG_C, carry);
                self.set_nz(res);
                return;
            }
            Isc => {
                let r = bus.read(addr).wrapping_add(1);
                bus.write(addr, r);
                let c = self.flag(FLAG_C);
                let (res, carry, ovf) = sbc_val(self.a, r, c);
                self.a = res;
                self.set_flag(FLAG_C, carry);
                self.set_flag(FLAG_V, ovf);
                self.set_nz(res);
                return;
            }
            _ => {}
        }
        match kind {
            Sta => bus.write(addr, self.a),
            Stx => bus.write(addr, self.x),
            Sty => bus.write(addr, self.y),
            Sax => {
                let v = self.a & self.x;
                bus.write(addr, v);
            }
            // The unstable "store AND with high byte" opcodes.
            Ahx => {
                let v = self.a & self.x & ((addr >> 8) as u8).wrapping_add(1);
                bus.write(addr, v);
            }
            Shy => {
                let v = self.y & ((addr >> 8) as u8).wrapping_add(1);
                bus.write(addr, v);
            }
            Shx => {
                let v = self.x & ((addr >> 8) as u8).wrapping_add(1);
                bus.write(addr, v);
            }
            Tas => {
                self.sp = self.a & self.x;
                let v = self.sp & ((addr >> 8) as u8).wrapping_add(1);
                bus.write(addr, v);
            }
            // Reads (and read-only NOPs, which still perform the bus read).
            _ => {
                let v = bus.read(addr);
                self.apply_imm(bus, kind, v, _cycles);
            }
        }
    }
}

#[inline(always)]
pub fn page_crossed(a: u16, b: u16) -> bool {
    (a & 0xFF00) != (b & 0xFF00)
}

/// Read a little-endian 16-bit value through the bus.
#[inline(always)]
pub fn read_u16<B: Bus>(bus: &mut B, addr: u16) -> u16 {
    let lo = bus.read(addr) as u16;
    let hi = bus.read(addr.wrapping_add(1)) as u16;
    (hi << 8) | lo
}
