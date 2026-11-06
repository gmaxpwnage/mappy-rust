//! Static analysis of a 6502 program image: classification of code vs data
//! and discovery of subroutine entry points.

use std::collections::{BTreeMap, BTreeSet, VecDeque};

use mos6502::disasm::{decode, Instr};
use mos6502::Kind;

/// Physical size of the PRG image handled here (NROM-128: 16 KiB, mirrored).
pub const PRG_SIZE: usize = 0x4000;
/// CPU address of physical offset 0.
pub const PRG_BASE: u16 = 0xC000;

pub struct Analysis {
    /// One byte per physical PRG offset.
    pub image: Vec<u8>,
    /// Physical offsets that begin an instruction.
    pub code: Vec<bool>,
    /// Physical offsets that begin a referenced basic-block / subroutine.
    pub labels: BTreeMap<u16, LabelKind>,
    /// Instruction cache keyed by physical offset.
    pub instrs: BTreeMap<u16, Instr>,
    /// Data ranges (start, end-exclusive) for listing purposes.
    pub data_ranges: Vec<(u16, u16)>,
    pub reset: u16,
    pub nmi: u16,
    pub irq: u16,
    /// Addresses reached only through computed control flow: we cannot prove
    /// these are code, but they are listed as "possible" entry points.
    pub unknown_jumps: Vec<u16>,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum LabelKind {
    Reset,
    Nmi,
    Irq,
    Subroutine,
    Branch,
    Jump,
    /// Discovered by dynamic tracing (executed at runtime).
    Dynamic,
}

impl Analysis {
    pub fn read(&self, addr: u16) -> u8 {
        self.image[phys(addr) as usize]
    }

    pub fn read16(&self, addr: u16) -> u16 {
        self.read(addr) as u16 | ((self.read(addr.wrapping_add(1)) as u16) << 8)
    }

    /// Classify a physical offset.
    pub fn is_code(&self, addr: u16) -> bool {
        self.code[phys(addr) as usize]
    }

    /// Analyse, seeding the traversal with addresses observed at runtime.
    pub fn analyze_with(image: Vec<u8>, dynamic: &[u16]) -> Analysis {
        assert_eq!(image.len(), PRG_SIZE);
        let mut a = Analysis {
            image,
            code: vec![false; PRG_SIZE],
            labels: BTreeMap::new(),
            instrs: BTreeMap::new(),
            data_ranges: Vec::new(),
            reset: 0,
            nmi: 0,
            irq: 0,
            unknown_jumps: Vec::new(),
        };
        a.nmi = a.read16(PRG_BASE + 0x3FFA);
        a.reset = a.read16(PRG_BASE + 0x3FFC);
        a.irq = a.read16(PRG_BASE + 0x3FFE);

        let mut work: VecDeque<(u16, LabelKind)> = VecDeque::new();
        work.push_back((a.nmi, LabelKind::Nmi));
        work.push_back((a.reset, LabelKind::Reset));
        work.push_back((a.irq, LabelKind::Irq));

        while let Some((start, kind)) = work.pop_front() {
            if kind != LabelKind::Branch {
                a.labels.entry(start).or_insert(kind);
            } else {
                a.labels.entry(start).or_insert(LabelKind::Branch);
            }
            // Linear sweep of one basic block.
            let mut pc = start;
            loop {
                let p = phys(pc);
                if a.code[p as usize] {
                    break;
                }
                let ins = decode(pc, &|addr| a.image[phys(addr) as usize]);
                for i in 0..ins.len {
                    a.code[phys(pc.wrapping_add(i)) as usize] = true;
                }
                a.instrs.insert(pc, ins);
                match ins.op.kind {
                    Kind::Jsr => {
                        if let Some(t) = ins.target() {
                            work.push_back((t, LabelKind::Subroutine));
                        }
                    }
                    Kind::Jmp => match ins.op.mode {
                        mos6502::Mode::Abs => {
                            if let Some(t) = ins.target() {
                                work.push_back((t, LabelKind::Jump));
                            }
                            break;
                        }
                        mos6502::Mode::Ind => {
                            a.unknown_jumps.push(ins.operand);
                            break;
                        }
                        _ => {
                            break;
                        }
                    },
                    Kind::Rts | Kind::Rti | Kind::Brk => {
                        break;
                    }
                    Kind::Kil => break,
                    k if k.is_branch() => {
                        if let Some(t) = ins.target() {
                            work.push_back((t, LabelKind::Branch));
                        }
                    }
                    _ => {}
                }
                pc = pc.wrapping_add(ins.len);
            }
        }

        // Addresses observed executing during a traced play session are
        // instruction starts by construction; sweep from each one so their
        // basic blocks are decoded too (this recovers code only reachable
        // through jump tables).
        for &addr in dynamic {
            work.push_back((addr, LabelKind::Dynamic));
        }
        while let Some((start, kind)) = work.pop_front() {
            a.labels.entry(start).or_insert(kind);
            let mut pc = start;
            loop {
                let p = phys(pc);
                if a.code[p as usize] {
                    break;
                }
                let ins = decode(pc, &|addr| a.image[phys(addr) as usize]);
                for i in 0..ins.len {
                    a.code[phys(pc.wrapping_add(i)) as usize] = true;
                }
                a.instrs.insert(pc, ins);
                match ins.op.kind {
                    Kind::Jsr => {
                        if let Some(t) = ins.target() {
                            work.push_back((t, LabelKind::Subroutine));
                        }
                    }
                    Kind::Jmp => {
                        if let Some(t) = ins.target() {
                            work.push_back((t, LabelKind::Jump));
                        }
                        break;
                    }
                    Kind::Rts | Kind::Rti | Kind::Brk | Kind::Kil => break,
                    k if k.is_branch() => {
                        if let Some(t) = ins.target() {
                            work.push_back((t, LabelKind::Branch));
                        }
                    }
                    _ => {}
                }
                pc = pc.wrapping_add(ins.len);
            }
        }

        a.compute_data_ranges();
        a
    }

    fn compute_data_ranges(&mut self) {
        let mut start: Option<u16> = None;
        self.data_ranges.clear();
        for p in 0..PRG_SIZE {
            if self.code[p] {
                if let Some(s) = start.take() {
                    self.data_ranges.push((s, p as u16));
                }
            } else if start.is_none() {
                start = Some(p as u16);
            }
        }
        if let Some(s) = start {
            self.data_ranges.push((s, PRG_SIZE as u16));
        }
    }

    /// Addresses referenced by JSR, sorted — used by the code generator.
    pub fn jsr_targets(&self) -> BTreeSet<u16> {
        self.instrs
            .values()
            .filter(|i| i.op.kind == Kind::Jsr)
            .filter_map(|i| i.target())
            .collect()
    }
}

#[inline]
pub fn phys(addr: u16) -> u16 {
    (addr.wrapping_sub(PRG_BASE)) & 0x3FFF
}

