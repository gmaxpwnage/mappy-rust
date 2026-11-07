//! Human-readable disassembly listing generation.

use std::collections::BTreeMap;
use std::fmt::Write as _;

use mos6502::disasm::decode;

use crate::analysis::{Analysis, LabelKind, PRG_BASE};

pub fn listing(a: &Analysis, symbols: &BTreeMap<u16, String>) -> String {
    let mut out = String::with_capacity(1 << 20);
    let _ = writeln!(
        out,
        "; ============================================================================
; Mappy (Japan) (En) - NROM (mapper 0), 16 KiB PRG, 8 KiB CHR, vertical mirroring
;
; Annotated disassembly produced by `recompiler` from the iNES image.
; The code is executed from the $C000-$FFFF mirror; all addresses below are
; CPU addresses in that window. `phys` offsets are shown in the header table.
;
; Vectors:  NMI ${:04X}   RESET ${:04X}   IRQ/BRK ${:04X}
; ============================================================================
",
        a.nmi, a.reset, a.irq
    );

    let mut p = 0u16;
    while p < 0x4000 {
        let addr = PRG_BASE | p;
        if a.is_code(addr) {
            if let Some(kind) = a.labels.get(&addr).filter(|k| keep_label(a, addr, **k)) {
                let name = symbols
                    .get(&addr)
                    .cloned()
                    .unwrap_or_else(|| default_label(*kind, addr));
                let _ = writeln!(out, "\n; {} entry", describe(*kind));
                let _ = writeln!(out, "{name}:");
            }
            let ins = a
                .instrs
                .get(&addr)
                .copied()
                .unwrap_or_else(|| decode(addr, &|x| a.read(x)));
            let text = ins.text(&|x| {
                symbols
                    .get(&x)
                    .map(|s| s.clone())
                    .or_else(|| a.labels.contains_key(&x).then(|| format!("L{x:04X}")))
            });
            let note = annotation(&ins);
            let _ = writeln!(
                out,
                "{addr:04X}  {:<9} {:<28} {note}",
                ins.bytes_hex(),
                text
            );
            p += ins.len;
        } else {
            // Data region: emit bytes in rows of eight with an ASCII column.
            let mut chunk = String::new();
            let mut ascii = String::new();
            let mut n = 0;
            while p < 0x4000 && !a.is_code(PRG_BASE | p) && n < 8 {
                let b = a.read(PRG_BASE | p);
                let _ = write!(chunk, "${b:02X},");
                ascii.push(if (0x20..0x7F).contains(&b) { b as char } else { '.' });
                p += 1;
                n += 1;
            }
            let _ = writeln!(out, "        .byte {:<32} ; {ascii}", chunk.trim_end_matches(','));
        }
    }
    out
}

/// Suppress labels for instructions that are simply the fall-through of the
/// previous one: they are reported as "reachable via computed jump" only
/// because dynamic tracing happened to observe them, which would bury the real
/// entry points in noise.
fn keep_label(a: &Analysis, addr: u16, kind: LabelKind) -> bool {
    if kind != LabelKind::Dynamic {
        return true;
    }
    for back in 1..=3u16 {
        let prev = addr.wrapping_sub(back);
        if let Some(ins) = a.instrs.get(&prev) {
            if ins.addr.wrapping_add(ins.len) == addr {
                return false;
            }
        }
    }
    true
}

fn describe(k: LabelKind) -> &'static str {
    match k {
        LabelKind::Reset => "RESET",
        LabelKind::Nmi => "NMI",
        LabelKind::Irq => "IRQ/BRK",
        LabelKind::Subroutine => "subroutine",
        LabelKind::Branch => "branch target",
        LabelKind::Jump => "jump target",
        LabelKind::Dynamic => "reachable via computed jump",
    }
}

pub fn default_label(k: LabelKind, addr: u16) -> String {
    match k {
        LabelKind::Reset => "reset".into(),
        LabelKind::Nmi => "nmi".into(),
        LabelKind::Irq => "irq".into(),
        LabelKind::Subroutine => format!("sub_{addr:04X}"),
        LabelKind::Branch => format!("L{addr:04X}"),
        LabelKind::Jump => format!("jmp_{addr:04X}"),
        LabelKind::Dynamic => format!("dyn_{addr:04X}"),
    }
}

/// Extra commentary derived from the instruction's operands.
fn annotation(ins: &mos6502::disasm::Instr) -> &'static str {
    use mos6502::Mode;
    match ins.op.mode {
        Mode::Abs | Mode::AbsX | Mode::AbsY => match ins.operand {
            0x2000 => "PPU: control",
            0x2001 => "PPU: mask",
            0x2002 => "PPU: status",
            0x2003 => "PPU: OAM address",
            0x2004 => "PPU: OAM data",
            0x2005 => "PPU: scroll",
            0x2006 => "PPU: VRAM address",
            0x2007 => "PPU: VRAM data",
            0x4014 => "OAM DMA",
            0x4015 => "APU: status",
            0x4016 => "APU/joy1 port",
            0x4017 => "APU frame counter",
            0x4000..=0x4013 => "APU register",
            _ => "",
        },
        _ => "",
    }
}
