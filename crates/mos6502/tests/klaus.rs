//! Conformance test: run Klaus Dormann's 6502 functional test suite.
//!
//! The suite is GPL-licensed and therefore not vendored; fetch it with
//! `tools/fetch_tests.sh`. The test is skipped (not failed) when absent.
//!
//! The suite exercises every documented instruction, all addressing modes,
//! flag behaviour, decimal mode, stack behaviour and the JMP-indirect page
//! bug. It ends by trapping in a one-instruction infinite loop at the
//! "success" label.

use mos6502::{Bus, Cpu};

struct FlatMem(Box<[u8; 65536]>);

impl Bus for FlatMem {
    #[inline]
    fn read(&mut self, addr: u16) -> u8 {
        self.0[addr as usize]
    }
    #[inline]
    fn write(&mut self, addr: u16, val: u8) {
        self.0[addr as usize] = val;
    }
}

#[test]
fn klaus_6502_functional_test() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/data/6502_functional_test.bin");
    let image = match std::fs::read(path) {
        Ok(v) => v,
        Err(_) => {
            eprintln!("skipping: {path} not present (run tools/fetch_tests.sh)");
            return;
        }
    };
    assert_eq!(image.len(), 65536, "unexpected test image size");

    let mut mem = FlatMem(Box::new([0u8; 65536]));
    mem.0.copy_from_slice(&image);

    let mut cpu = Cpu::default();
    cpu.bcd = true; // Klaus's image is assembled for a plain 6502 with decimal mode
    cpu.pc = 0x0400;

    let mut last_pc = cpu.pc;
    let mut trapped_at = None;
    let mut steps = 0u64;
    while steps < 200_000_000 {
        cpu.step(&mut mem);
        steps += 1;
        if cpu.jammed {
            panic!("CPU jammed at ${:04X}", cpu.pc);
        }
        if cpu.pc == last_pc {
            trapped_at = Some(cpu.pc);
            break;
        }
        last_pc = cpu.pc;
    }

    let trap = trapped_at.expect("test suite did not terminate (budget exhausted)");
    // The success label of the standard build.
    const SUCCESS: u16 = 0x3469;
    if trap != SUCCESS {
        let ins = mos6502::disasm::decode(trap, &|a| mem.0[a as usize]);
        panic!(
            "functional test FAILED: trapped at ${trap:04X} after {steps} instructions ({})",
            ins.text(&|_| None)
        );
    }
    eprintln!("klaus functional test: success at ${trap:04X} after {steps} instructions, {} cycles", cpu.cycles);
}
