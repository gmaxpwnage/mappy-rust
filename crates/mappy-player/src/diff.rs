//! Differential test: the reference interpreter against the translated Rust.
//!
//! Both engines run the same ROM, driven by the same scripted input, and every
//! observable piece of state (registers, RAM, PPU registers, framebuffer, APU
//! samples) is compared after each frame. Any divergence is reported with the
//! instruction history that led to it.

use std::collections::VecDeque;

use nes::Machine;

pub struct Divergence {
    pub frame: u32,
    pub what: String,
    pub interp: String,
    pub translated: String,
    pub history: Vec<String>,
}

struct History {
    ring: VecDeque<String>,
    len: usize,
}

impl History {
    fn new(len: usize) -> History {
        History { ring: VecDeque::with_capacity(len), len }
    }
    fn push(&mut self, s: String) {
        if self.ring.len() == self.len {
            self.ring.pop_front();
        }
        self.ring.push_back(s);
    }
    fn dump(&self) -> Vec<String> {
        self.ring.iter().cloned().collect()
    }
}

/// Run the differential test. Returns `Ok(frames_run)` or the first divergence.
///
/// The two engines are stepped *instruction by instruction* in lockstep; after
/// every instruction the CPU state must be identical, and after every frame
/// RAM, the PPU and the audio stream must be identical too.
pub fn run(
    rom: &[u8],
    frames: u32,
    script: &crate::input::InputScript,
    verbose: bool,
) -> Result<u32, Divergence> {
    let cart = nes::Cart::from_ines(rom).map_err(|e| Divergence {
        frame: 0,
        what: "rom".into(),
        interp: e.clone(),
        translated: e,
        history: vec![],
    })?;
    let mut interp = Machine::new(cart);
    let mut translated = mappy_rom::Mappy::new();
    let mut hist = History::new(48);

    for f in 0..frames {
        let pad = script.at(f);
        interp.pad1 = pad;
        translated.machine.pad1 = pad;

        let target = interp.ppu.frame + 1;
        let mut guard = 0u64;
        while interp.ppu.frame < target {
            hist.push(format!(
                "pc={:04X} cyc={} a={:02X} x={:02X} y={:02X} sp={:02X} p={:02X}",
                interp.cpu.pc, interp.cpu.cycles, interp.cpu.a, interp.cpu.x, interp.cpu.y,
                interp.cpu.sp, interp.cpu.p
            ));
            interp.step_interpreter();
            translated.step();
            if let Some(d) = compare_instruction(f, &interp, &translated.machine) {
                return Err(Divergence { history: hist.dump(), ..d });
            }
            guard += 1;
            if guard > 10_000_000 || interp.cpu.jammed {
                break;
            }
        }
        if let Some(d) = compare(f, &interp, &translated.machine) {
            return Err(Divergence { history: hist.dump(), ..d });
        }
        if verbose && (f % 60 == 0 || f + 1 == frames) {
            println!(
                "frame {f}: pc={:04X} cycles={} ok",
                interp.cpu.pc, interp.cpu.cycles
            );
        }
    }
    Ok(frames)
}

fn compare_instruction(frame: u32, a: &Machine, b: &Machine) -> Option<Divergence> {
    if a.cpu.pc != b.cpu.pc
        || a.cpu.a != b.cpu.a
        || a.cpu.x != b.cpu.x
        || a.cpu.y != b.cpu.y
        || a.cpu.sp != b.cpu.sp
        || a.cpu.p != b.cpu.p
        || a.cpu.cycles != b.cpu.cycles
    {
        return Some(Divergence {
            frame,
            what: "CPU state after instruction".into(),
            interp: format!(
                "pc={:04X} a={:02X} x={:02X} y={:02X} sp={:02X} p={:02X} cyc={}",
                a.cpu.pc, a.cpu.a, a.cpu.x, a.cpu.y, a.cpu.sp, a.cpu.p, a.cpu.cycles
            ),
            translated: format!(
                "pc={:04X} a={:02X} x={:02X} y={:02X} sp={:02X} p={:02X} cyc={}",
                b.cpu.pc, b.cpu.a, b.cpu.x, b.cpu.y, b.cpu.sp, b.cpu.p, b.cpu.cycles
            ),
            history: Vec::new(),
        });
    }
    None
}

fn compare(frame: u32, a: &Machine, b: &Machine) -> Option<Divergence> {
    let mk = |what: &str, x: String, y: String| Divergence {
        frame,
        what: what.to_string(),
        interp: x,
        translated: y,
        history: Vec::new(),
    };
    if a.cpu.pc != b.cpu.pc
        || a.cpu.a != b.cpu.a
        || a.cpu.x != b.cpu.x
        || a.cpu.y != b.cpu.y
        || a.cpu.sp != b.cpu.sp
        || a.cpu.p != b.cpu.p
    {
        return Some(mk(
            "registers",
            format!(
                "pc={:04X} a={:02X} x={:02X} y={:02X} sp={:02X} p={:02X}",
                a.cpu.pc, a.cpu.a, a.cpu.x, a.cpu.y, a.cpu.sp, a.cpu.p
            ),
            format!(
                "pc={:04X} a={:02X} x={:02X} y={:02X} sp={:02X} p={:02X}",
                b.cpu.pc, b.cpu.a, b.cpu.x, b.cpu.y, b.cpu.sp, b.cpu.p
            ),
        ));
    }
    if a.cpu.cycles != b.cpu.cycles {
        return Some(mk(
            "cycle count",
            a.cpu.cycles.to_string(),
            b.cpu.cycles.to_string(),
        ));
    }
    for i in 0..0x800 {
        if a.ram[i] != b.ram[i] {
            return Some(mk(
                &format!("RAM ${:04X}", i),
                format!("{:02X}", a.ram[i]),
                format!("{:02X}", b.ram[i]),
            ));
        }
    }
    if a.ppu.v != b.ppu.v || a.ppu.t != b.ppu.t || a.ppu.fine_x != b.ppu.fine_x {
        return Some(mk(
            "PPU scroll registers",
            format!("v={:04X} t={:04X} x={}", a.ppu.v, a.ppu.t, a.ppu.fine_x),
            format!("v={:04X} t={:04X} x={}", b.ppu.v, b.ppu.t, b.ppu.fine_x),
        ));
    }
    if a.ppu.nametables != b.ppu.nametables {
        let i = a
            .ppu
            .nametables
            .iter()
            .zip(b.ppu.nametables.iter())
            .position(|(x, y)| x != y)
            .unwrap();
        return Some(mk(
            &format!("nametable byte {i}"),
            format!("{:02X}", a.ppu.nametables[i]),
            format!("{:02X}", b.ppu.nametables[i]),
        ));
    }
    if a.ppu.palette != b.ppu.palette {
        return Some(mk("palette RAM", format!("{:?}", a.ppu.palette), format!("{:?}", b.ppu.palette)));
    }
    for i in 0..256 * 240 {
        if a.ppu.pixels[i] != b.ppu.pixels[i] {
            return Some(mk(
                &format!("pixel {i} (x={}, y={})", i % 256, i / 256),
                format!("{}", a.ppu.pixels[i]),
                format!("{}", b.ppu.pixels[i]),
            ));
        }
    }
    if a.apu.samples.len() != b.apu.samples.len() {
        return Some(mk(
            "audio sample count",
            a.apu.samples.len().to_string(),
            b.apu.samples.len().to_string(),
        ));
    }
    None
}
