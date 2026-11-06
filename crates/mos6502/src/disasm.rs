//! A 6502 disassembler, used by the decompiler and its listings.

use crate::opcodes::{Mode, Op, OPCODES};

/// A decoded instruction.
#[derive(Clone, Copy, Debug)]
pub struct Instr {
    /// Address the instruction starts at.
    pub addr: u16,
    /// Instruction length in bytes (1..=3).
    pub len: u16,
    /// The opcode byte.
    pub opcode: u8,
    /// The opcode matrix entry.
    pub op: Op,
    /// The raw operand bytes, little-endian.
    pub operand: u16,
}

impl Instr {
    pub fn mnemonic(&self) -> &'static str {
        self.op.name
    }

    /// Immediate operand value (only meaningful for `Mode::Imm`).
    pub fn imm(&self) -> u8 {
        self.operand as u8
    }

    /// Branch displacement (only meaningful for `Mode::Rel`).
    pub fn rel(&self) -> i8 {
        self.operand as u8 as i8
    }

    /// The target of a branch, JMP or JSR.
    pub fn target(&self) -> Option<u16> {
        match self.op.mode {
            Mode::Rel => Some(self.addr.wrapping_add(2).wrapping_add(self.rel() as u16)),
            Mode::Abs | Mode::Ind if self.op.kind == crate::Kind::Jmp => Some(self.operand),
            Mode::Abs if self.op.kind == crate::Kind::Jsr => Some(self.operand),
            _ => None,
        }
    }

    /// Address referenced by a memory operand, if any (used for xrefs).
    pub fn mem_ref(&self) -> Option<u16> {
        match self.op.mode {
            Mode::Abs | Mode::AbsX | Mode::AbsY | Mode::Ind | Mode::IndX | Mode::IndY | Mode::Zp
            | Mode::Zpx | Mode::Zpy => Some(self.operand),
            _ => None,
        }
    }

    /// Render the instruction, substituting a label for the target when the
    /// supplied resolver returns one.
    pub fn text(&self, label: &dyn Fn(u16) -> Option<String>) -> String {
        let mn = self.mnemonic();
        let operand = self.operand;
        let lo = (operand & 0xFF) as u8;
        let addr = self.addr.wrapping_add(2).wrapping_add(self.rel() as u16);
        let sym = |a: u16| -> String {
            match label(a) {
                Some(l) => l,
                None => format!("${a:04X}"),
            }
        };
        match self.op.mode {
            Mode::Impl => mn.to_string(),
            Mode::Acc => format!("{mn} A"),
            Mode::Imm => format!("{mn} #${lo:02X}"),
            Mode::Zp => format!("{mn} ${:02X}", lo),
            Mode::Zpx => format!("{mn} ${:02X},X", lo),
            Mode::Zpy => format!("{mn} ${:02X},Y", lo),
            Mode::Abs => format!("{mn} {}", sym(operand)),
            Mode::AbsX => format!("{mn} {},X", sym(operand)),
            Mode::AbsY => format!("{mn} {},Y", sym(operand)),
            Mode::Ind => format!("{mn} (${operand:04X})"),
            Mode::IndX => format!("{mn} (${lo:02X},X)"),
            Mode::IndY => format!("{mn} (${lo:02X}),Y"),
            Mode::Rel => format!("{mn} {}", sym(addr)),
        }
    }

    /// Render the raw operand bytes as hex for listing comments.
    pub fn bytes_hex(&self) -> String {
        let mut s = String::new();
        for i in 0..self.len {
            s.push_str(&format!("{:02X} ", self.fetch_byte(i)));
        }
        s.pop();
        s
    }

    fn fetch_byte(&self, i: u16) -> u8 {
        if i == 0 {
            self.opcode
        } else {
            ((self.operand >> (8 * (i - 1))) & 0xFF) as u8
        }
    }
}

/// Decode the instruction at `addr`, reading bytes with `fetch`.
pub fn decode(addr: u16, fetch: &dyn Fn(u16) -> u8) -> Instr {
    let opcode = fetch(addr);
    let op = OPCODES[opcode as usize];
    let len = op.len();
    let mut operand = 0u16;
    if len >= 2 {
        operand = fetch(addr.wrapping_add(1)) as u16;
        if len == 3 {
            operand |= (fetch(addr.wrapping_add(2)) as u16) << 8;
        }
    }
    Instr { addr, len, opcode, op, operand }
}

/// A simple memory-backed disassembler: no analysis, just decode.
pub fn disassemble_rom(prg: &[u8], base: u16, start: u16, end: u16) -> String {
    let fetch = |a: u16| -> u8 {
        let off = (a.wrapping_sub(base)) as usize;
        *prg.get(off).unwrap_or(&0)
    };
    let mut out = String::new();
    let mut pc = start;
    while pc < end {
        let ins = decode(pc, &fetch);
        out.push_str(&format!("{:04X}  {:<9} {}\n", pc, ins.bytes_hex(), ins.text(&|_| None)));
        pc = pc.wrapping_add(ins.len);
    }
    out
}
