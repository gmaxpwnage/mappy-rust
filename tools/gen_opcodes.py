#!/usr/bin/env python3
"""Generate crates/mos6502/src/opcodes.rs from the canonical 6502 opcode matrix.

The table includes the documented NMOS 6502 instructions plus the widely
implemented "illegal"/undocumented opcodes, because a recompiler must be able
to decode *every* byte in a ROM (data regions included).
"""

# (mnemonic, mode, kind, cycles, page_cross_penalty)
T = {
    0x00: ("BRK", "Impl", "Brk", 7, 0),
    0x01: ("ORA", "IndX", "Ora", 6, 0),
    0x02: ("KIL", "Impl", "Kil", 2, 0),
    0x03: ("SLO", "IndX", "Slo", 8, 0),
    0x04: ("NOP", "Zp", "Nop", 3, 0),
    0x05: ("ORA", "Zp", "Ora", 3, 0),
    0x06: ("ASL", "Zp", "Asl", 5, 0),
    0x07: ("SLO", "Zp", "Slo", 5, 0),
    0x08: ("PHP", "Impl", "Php", 3, 0),
    0x09: ("ORA", "Imm", "Ora", 2, 0),
    0x0A: ("ASL", "Acc", "AslA", 2, 0),
    0x0B: ("ANC", "Imm", "Anc", 2, 0),
    0x0C: ("NOP", "Abs", "Nop", 4, 0),
    0x0D: ("ORA", "Abs", "Ora", 4, 0),
    0x0E: ("ASL", "Abs", "Asl", 6, 0),
    0x0F: ("SLO", "Abs", "Slo", 6, 0),
    0x10: ("BPL", "Rel", "Bpl", 2, 0),
    0x11: ("ORA", "IndY", "Ora", 5, 1),
    0x12: ("KIL", "Impl", "Kil", 2, 0),
    0x13: ("SLO", "IndY", "Slo", 8, 0),
    0x14: ("NOP", "Zpx", "Nop", 4, 0),
    0x15: ("ORA", "Zpx", "Ora", 4, 0),
    0x16: ("ASL", "Zpx", "Asl", 6, 0),
    0x17: ("SLO", "Zpx", "Slo", 6, 0),
    0x18: ("CLC", "Impl", "Clc", 2, 0),
    0x19: ("ORA", "AbsY", "Ora", 4, 1),
    0x1A: ("NOP", "Impl", "Nop", 2, 0),
    0x1B: ("SLO", "AbsY", "Slo", 7, 0),
    0x1C: ("NOP", "AbsX", "Nop", 4, 1),
    0x1D: ("ORA", "AbsX", "Ora", 4, 1),
    0x1E: ("ASL", "AbsX", "Asl", 7, 0),
    0x1F: ("SLO", "AbsX", "Slo", 7, 0),
    0x20: ("JSR", "Abs", "Jsr", 6, 0),
    0x21: ("AND", "IndX", "And", 6, 0),
    0x22: ("KIL", "Impl", "Kil", 2, 0),
    0x23: ("RLA", "IndX", "Rla", 8, 0),
    0x24: ("BIT", "Zp", "Bit", 3, 0),
    0x25: ("AND", "Zp", "And", 3, 0),
    0x26: ("ROL", "Zp", "Rol", 5, 0),
    0x27: ("RLA", "Zp", "Rla", 5, 0),
    0x28: ("PLP", "Impl", "Plp", 4, 0),
    0x29: ("AND", "Imm", "And", 2, 0),
    0x2A: ("ROL", "Acc", "RolA", 2, 0),
    0x2B: ("ANC", "Imm", "Anc", 2, 0),
    0x2C: ("BIT", "Abs", "Bit", 4, 0),
    0x2D: ("AND", "Abs", "And", 4, 0),
    0x2E: ("ROL", "Abs", "Rol", 6, 0),
    0x2F: ("RLA", "Abs", "Rla", 6, 0),
    0x30: ("BMI", "Rel", "Bmi", 2, 0),
    0x31: ("AND", "IndY", "And", 5, 1),
    0x32: ("KIL", "Impl", "Kil", 2, 0),
    0x33: ("RLA", "IndY", "Rla", 8, 0),
    0x34: ("NOP", "Zpx", "Nop", 4, 0),
    0x35: ("AND", "Zpx", "And", 4, 0),
    0x36: ("ROL", "Zpx", "Rol", 6, 0),
    0x37: ("RLA", "Zpx", "Rla", 6, 0),
    0x38: ("SEC", "Impl", "Sec", 2, 0),
    0x39: ("AND", "AbsY", "And", 4, 1),
    0x3A: ("NOP", "Impl", "Nop", 2, 0),
    0x3B: ("RLA", "AbsY", "Rla", 7, 0),
    0x3C: ("NOP", "AbsX", "Nop", 4, 1),
    0x3D: ("AND", "AbsX", "And", 4, 1),
    0x3E: ("ROL", "AbsX", "Rol", 7, 0),
    0x3F: ("RLA", "AbsX", "Rla", 7, 0),
    0x40: ("RTI", "Impl", "Rti", 6, 0),
    0x41: ("EOR", "IndX", "Eor", 6, 0),
    0x42: ("KIL", "Impl", "Kil", 2, 0),
    0x43: ("SRE", "IndX", "Sre", 8, 0),
    0x44: ("NOP", "Zp", "Nop", 3, 0),
    0x45: ("EOR", "Zp", "Eor", 3, 0),
    0x46: ("LSR", "Zp", "Lsr", 5, 0),
    0x47: ("SRE", "Zp", "Sre", 5, 0),
    0x48: ("PHA", "Impl", "Pha", 3, 0),
    0x49: ("EOR", "Imm", "Eor", 2, 0),
    0x4A: ("LSR", "Acc", "LsrA", 2, 0),
    0x4B: ("ALR", "Imm", "Alr", 2, 0),
    0x4C: ("JMP", "Abs", "Jmp", 3, 0),
    0x4D: ("EOR", "Abs", "Eor", 4, 0),
    0x4E: ("LSR", "Abs", "Lsr", 6, 0),
    0x4F: ("SRE", "Abs", "Sre", 6, 0),
    0x50: ("BVC", "Rel", "Bvc", 2, 0),
    0x51: ("EOR", "IndY", "Eor", 5, 1),
    0x52: ("KIL", "Impl", "Kil", 2, 0),
    0x53: ("SRE", "IndY", "Sre", 8, 0),
    0x54: ("NOP", "Zpx", "Nop", 4, 0),
    0x55: ("EOR", "Zpx", "Eor", 4, 0),
    0x56: ("LSR", "Zpx", "Lsr", 6, 0),
    0x57: ("SRE", "Zpx", "Sre", 6, 0),
    0x58: ("CLI", "Impl", "Cli", 2, 0),
    0x59: ("EOR", "AbsY", "Eor", 4, 1),
    0x5A: ("NOP", "Impl", "Nop", 2, 0),
    0x5B: ("SRE", "AbsY", "Sre", 7, 0),
    0x5C: ("NOP", "AbsX", "Nop", 4, 1),
    0x5D: ("EOR", "AbsX", "Eor", 4, 1),
    0x5E: ("LSR", "AbsX", "Lsr", 7, 0),
    0x5F: ("SRE", "AbsX", "Sre", 7, 0),
    0x60: ("RTS", "Impl", "Rts", 6, 0),
    0x61: ("ADC", "IndX", "Adc", 6, 0),
    0x62: ("KIL", "Impl", "Kil", 2, 0),
    0x63: ("RRA", "IndX", "Rra", 8, 0),
    0x64: ("NOP", "Zp", "Nop", 3, 0),
    0x65: ("ADC", "Zp", "Adc", 3, 0),
    0x66: ("ROR", "Zp", "Ror", 5, 0),
    0x67: ("RRA", "Zp", "Rra", 5, 0),
    0x68: ("PLA", "Impl", "Pla", 4, 0),
    0x69: ("ADC", "Imm", "Adc", 2, 0),
    0x6A: ("ROR", "Acc", "RorA", 2, 0),
    0x6B: ("ARR", "Imm", "Arr", 2, 0),
    0x6C: ("JMP", "Ind", "Jmp", 5, 0),
    0x6D: ("ADC", "Abs", "Adc", 4, 0),
    0x6E: ("ROR", "Abs", "Ror", 6, 0),
    0x6F: ("RRA", "Abs", "Rra", 6, 0),
    0x70: ("BVS", "Rel", "Bvs", 2, 0),
    0x71: ("ADC", "IndY", "Adc", 5, 1),
    0x72: ("KIL", "Impl", "Kil", 2, 0),
    0x73: ("RRA", "IndY", "Rra", 8, 0),
    0x74: ("NOP", "Zpx", "Nop", 4, 0),
    0x75: ("ADC", "Zpx", "Adc", 4, 0),
    0x76: ("ROR", "Zpx", "Ror", 6, 0),
    0x77: ("RRA", "Zpx", "Rra", 6, 0),
    0x78: ("SEI", "Impl", "Sei", 2, 0),
    0x79: ("ADC", "AbsY", "Adc", 4, 1),
    0x7A: ("NOP", "Impl", "Nop", 2, 0),
    0x7B: ("RRA", "AbsY", "Rra", 7, 0),
    0x7C: ("NOP", "AbsX", "Nop", 4, 1),
    0x7D: ("ADC", "AbsX", "Adc", 4, 1),
    0x7E: ("ROR", "AbsX", "Ror", 7, 0),
    0x7F: ("RRA", "AbsX", "Rra", 7, 0),
    0x80: ("NOP", "Imm", "Nop", 2, 0),
    0x81: ("STA", "IndX", "Sta", 6, 0),
    0x82: ("NOP", "Imm", "Nop", 2, 0),
    0x83: ("SAX", "IndX", "Sax", 6, 0),
    0x84: ("STY", "Zp", "Sty", 3, 0),
    0x85: ("STA", "Zp", "Sta", 3, 0),
    0x86: ("STX", "Zp", "Stx", 3, 0),
    0x87: ("SAX", "Zp", "Sax", 3, 0),
    0x88: ("DEY", "Impl", "Dey", 2, 0),
    0x89: ("NOP", "Imm", "Nop", 2, 0),
    0x8A: ("TXA", "Impl", "Txa", 2, 0),
    0x8B: ("XAA", "Imm", "Xaa", 2, 0),
    0x8C: ("STY", "Abs", "Sty", 4, 0),
    0x8D: ("STA", "Abs", "Sta", 4, 0),
    0x8E: ("STX", "Abs", "Stx", 4, 0),
    0x8F: ("SAX", "Abs", "Sax", 4, 0),
    0x90: ("BCC", "Rel", "Bcc", 2, 0),
    0x91: ("STA", "IndY", "Sta", 6, 0),
    0x92: ("KIL", "Impl", "Kil", 2, 0),
    0x93: ("AHX", "IndY", "Ahx", 6, 0),
    0x94: ("STY", "Zpx", "Sty", 4, 0),
    0x95: ("STA", "Zpx", "Sta", 4, 0),
    0x96: ("STX", "Zpy", "Stx", 4, 0),
    0x97: ("SAX", "Zpy", "Sax", 4, 0),
    0x98: ("TYA", "Impl", "Tya", 2, 0),
    0x99: ("STA", "AbsY", "Sta", 5, 0),
    0x9A: ("TXS", "Impl", "Txs", 2, 0),
    0x9B: ("TAS", "AbsY", "Tas", 5, 0),
    0x9C: ("SHY", "AbsX", "Shy", 5, 0),
    0x9D: ("STA", "AbsX", "Sta", 5, 0),
    0x9E: ("SHX", "AbsY", "Shx", 5, 0),
    0x9F: ("AHX", "AbsY", "Ahx", 5, 0),
    0xA0: ("LDY", "Imm", "Ldy", 2, 0),
    0xA1: ("LDA", "IndX", "Lda", 6, 0),
    0xA2: ("LDX", "Imm", "Ldx", 2, 0),
    0xA3: ("LAX", "IndX", "Lax", 6, 0),
    0xA4: ("LDY", "Zp", "Ldy", 3, 0),
    0xA5: ("LDA", "Zp", "Lda", 3, 0),
    0xA6: ("LDX", "Zp", "Ldx", 3, 0),
    0xA7: ("LAX", "Zp", "Lax", 3, 0),
    0xA8: ("TAY", "Impl", "Tay", 2, 0),
    0xA9: ("LDA", "Imm", "Lda", 2, 0),
    0xAA: ("TAX", "Impl", "Tax", 2, 0),
    0xAB: ("LAX", "Imm", "Lax", 2, 0),
    0xAC: ("LDY", "Abs", "Ldy", 4, 0),
    0xAD: ("LDA", "Abs", "Lda", 4, 0),
    0xAE: ("LDX", "Abs", "Ldx", 4, 0),
    0xAF: ("LAX", "Abs", "Lax", 4, 0),
    0xB0: ("BCS", "Rel", "Bcs", 2, 0),
    0xB1: ("LDA", "IndY", "Lda", 5, 1),
    0xB2: ("KIL", "Impl", "Kil", 2, 0),
    0xB3: ("LAX", "IndY", "Lax", 5, 1),
    0xB4: ("LDY", "Zpx", "Ldy", 4, 0),
    0xB5: ("LDA", "Zpx", "Lda", 4, 0),
    0xB6: ("LDX", "Zpy", "Ldx", 4, 0),
    0xB7: ("LAX", "Zpy", "Lax", 4, 0),
    0xB8: ("CLV", "Impl", "Clv", 2, 0),
    0xB9: ("LDA", "AbsY", "Lda", 4, 1),
    0xBA: ("TSX", "Impl", "Tsx", 2, 0),
    0xBB: ("LAS", "AbsY", "Las", 4, 1),
    0xBC: ("LDY", "AbsX", "Ldy", 4, 1),
    0xBD: ("LDA", "AbsX", "Lda", 4, 1),
    0xBE: ("LDX", "AbsY", "Ldx", 4, 1),
    0xBF: ("LAX", "AbsY", "Lax", 4, 1),
    0xC0: ("CPY", "Imm", "Cpy", 2, 0),
    0xC1: ("CMP", "IndX", "Cmp", 6, 0),
    0xC2: ("NOP", "Imm", "Nop", 2, 0),
    0xC3: ("DCP", "IndX", "Dcp", 8, 0),
    0xC4: ("CPY", "Zp", "Cpy", 3, 0),
    0xC5: ("CMP", "Zp", "Cmp", 3, 0),
    0xC6: ("DEC", "Zp", "Dec", 5, 0),
    0xC7: ("DCP", "Zp", "Dcp", 5, 0),
    0xC8: ("INY", "Impl", "Iny", 2, 0),
    0xC9: ("CMP", "Imm", "Cmp", 2, 0),
    0xCA: ("DEX", "Impl", "Dex", 2, 0),
    0xCB: ("AXS", "Imm", "Axs", 2, 0),
    0xCC: ("CPY", "Abs", "Cpy", 4, 0),
    0xCD: ("CMP", "Abs", "Cmp", 4, 0),
    0xCE: ("DEC", "Abs", "Dec", 6, 0),
    0xCF: ("DCP", "Abs", "Dcp", 6, 0),
    0xD0: ("BNE", "Rel", "Bne", 2, 0),
    0xD1: ("CMP", "IndY", "Cmp", 5, 1),
    0xD2: ("KIL", "Impl", "Kil", 2, 0),
    0xD3: ("DCP", "IndY", "Dcp", 8, 0),
    0xD4: ("NOP", "Zpx", "Nop", 4, 0),
    0xD5: ("CMP", "Zpx", "Cmp", 4, 0),
    0xD6: ("DEC", "Zpx", "Dec", 6, 0),
    0xD7: ("DCP", "Zpx", "Dcp", 6, 0),
    0xD8: ("CLD", "Impl", "Cld", 2, 0),
    0xD9: ("CMP", "AbsY", "Cmp", 4, 1),
    0xDA: ("NOP", "Impl", "Nop", 2, 0),
    0xDB: ("DCP", "AbsY", "Dcp", 7, 0),
    0xDC: ("NOP", "AbsX", "Nop", 4, 1),
    0xDD: ("CMP", "AbsX", "Cmp", 4, 1),
    0xDE: ("DEC", "AbsX", "Dec", 7, 0),
    0xDF: ("DCP", "AbsX", "Dcp", 7, 0),
    0xE0: ("CPX", "Imm", "Cpx", 2, 0),
    0xE1: ("SBC", "IndX", "Sbc", 6, 0),
    0xE2: ("NOP", "Imm", "Nop", 2, 0),
    0xE3: ("ISC", "IndX", "Isc", 8, 0),
    0xE4: ("CPX", "Zp", "Cpx", 3, 0),
    0xE5: ("SBC", "Zp", "Sbc", 3, 0),
    0xE6: ("INC", "Zp", "Inc", 5, 0),
    0xE7: ("ISC", "Zp", "Isc", 5, 0),
    0xE8: ("INX", "Impl", "Inx", 2, 0),
    0xE9: ("SBC", "Imm", "Sbc", 2, 0),
    0xEA: ("NOP", "Impl", "Nop", 2, 0),
    0xEB: ("SBC", "Imm", "Sbc", 2, 0),
    0xEC: ("CPX", "Abs", "Cpx", 4, 0),
    0xED: ("SBC", "Abs", "Sbc", 4, 0),
    0xEE: ("INC", "Abs", "Inc", 6, 0),
    0xEF: ("ISC", "Abs", "Isc", 6, 0),
    0xF0: ("BEQ", "Rel", "Beq", 2, 0),
    0xF1: ("SBC", "IndY", "Sbc", 5, 1),
    0xF2: ("KIL", "Impl", "Kil", 2, 0),
    0xF3: ("ISC", "IndY", "Isc", 8, 0),
    0xF4: ("NOP", "Zpx", "Nop", 4, 0),
    0xF5: ("SBC", "Zpx", "Sbc", 4, 0),
    0xF6: ("INC", "Zpx", "Inc", 6, 0),
    0xF7: ("ISC", "Zpx", "Isc", 6, 0),
    0xF8: ("SED", "Impl", "Sed", 2, 0),
    0xF9: ("SBC", "AbsY", "Sbc", 4, 1),
    0xFA: ("NOP", "Impl", "Nop", 2, 0),
    0xFB: ("ISC", "AbsY", "Isc", 7, 0),
    0xFC: ("NOP", "AbsX", "Nop", 4, 1),
    0xFD: ("SBC", "AbsX", "Sbc", 4, 1),
    0xFE: ("INC", "AbsX", "Inc", 7, 0),
    0xFF: ("ISC", "AbsX", "Isc", 7, 0),
}

assert len(T) == 256, len(T)

HEADER = """// @generated by tools/gen_opcodes.py -- do not edit by hand.
//! The 6502 instruction set: all 151 documented opcodes plus the NMOS
//! undocumented ("illegal") opcodes, which a recompiler must decode too.

/// Addressing mode of an instruction.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Mode {
    /// Implied / stack operation (no operand byte).
    Impl,
    /// Accumulator.
    Acc,
    /// Immediate.
    Imm,
    /// Zero page.
    Zp,
    /// Zero page, X.
    Zpx,
    /// Zero page, Y.
    Zpy,
    /// Absolute.
    Abs,
    /// Absolute, X.
    AbsX,
    /// Absolute, Y.
    AbsY,
    /// Indirect (JMP only).
    Ind,
    /// Indexed indirect (zero page, X).
    IndX,
    /// Indirect indexed (zero page), Y.
    IndY,
    /// Relative (branches).
    Rel,
}

impl Mode {
    /// Total instruction length in bytes, including the opcode.
    pub const fn len(self) -> u16 {
        match self {
            Mode::Impl | Mode::Acc => 1,
            Mode::Imm | Mode::Zp | Mode::Zpx | Mode::Zpy | Mode::IndX | Mode::IndY | Mode::Rel => 2,
            Mode::Abs | Mode::AbsX | Mode::AbsY | Mode::Ind => 3,
        }
    }
}

/// Semantic operation performed by an instruction.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Kind {
    Adc, And, Asl, AslA, Bcc, Bcs, Beq, Bit, Bmi, Bne, Bpl, Brk, Bvc, Bvs, Clc, Cld,
    Cli, Clv, Cmp, Cpx, Cpy, Dec, Dex, Dey, Eor, Inc, Inx, Iny, Jmp, Jsr, Lda, Ldx,
    Ldy, Lsr, LsrA, Nop, Ora, Pha, Php, Pla, Plp, Rol, RolA, Ror, RorA, Rti, Rts, Sbc,
    Sec, Sed, Sei, Sta, Stx, Sty, Tax, Tay, Tsx, Txa, Txs, Tya,
    // Undocumented.
    Kil, Slo, Rla, Sre, Rra, Sax, Lax, Dcp, Isc, Anc, Alr, Arr, Xaa, Axs, Las, Ahx,
    Shy, Shx, Tas,
}

impl Kind {
    /// True for the branch instructions (relative addressing).
    pub const fn is_branch(self) -> bool {
        matches!(
            self,
            Kind::Bcc | Kind::Bcs | Kind::Beq | Kind::Bmi | Kind::Bne | Kind::Bpl | Kind::Bvc | Kind::Bvs
        )
    }
}

/// One entry of the opcode matrix.
#[derive(Clone, Copy, Debug)]
pub struct Op {
    pub name: &'static str,
    pub mode: Mode,
    pub kind: Kind,
    pub cycles: u8,
    /// Add one cycle when an indexed read crosses a page boundary.
    pub page_penalty: bool,
}

impl Op {
    pub const fn len(&self) -> u16 {
        self.mode.len()
    }
}

/// Opcode matrix, indexed by opcode byte.
pub static OPCODES: [Op; 256] = [
"""

lines = []
for code in range(256):
    name, mode, kind, cyc, pg = T[code]
    lines.append(
        f'    Op {{ name: "{name}", mode: Mode::{mode}, kind: Kind::{kind}, cycles: {cyc}, page_penalty: {"true" if pg else "false"} }}, // {code:02X}'
    )

out = HEADER + "\n".join(lines) + "\n];\n"
open("/home/max/mappy/crates/mos6502/src/opcodes.rs", "w").write(out)

# A disjoint sanity check on the mnemonics we produced.
legal = {0x69, 0x65, 0x75, 0x6D, 0x7D, 0x79, 0x61, 0x71}
assert all(T[c][2] == "Adc" for c in legal)
print("wrote opcodes.rs:", len(out), "bytes; legal opcodes:",
      sum(1 for c in range(256) if T[c][2] != "Kil" and T[c][0] != "NOP"))
