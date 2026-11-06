//! `mappy` — the frontend for the decompiled game.
//!
//! Commands:
//!   play                     open a window and play (needs the `gui` feature)
//!   headless                 run and dump PNG frames / audio, no window
//!   trace                    record executed program counters (coverage)
//!   diff                     run interpreter vs decompiled Rust in lockstep
//!   ram                      dump RAM after running

mod diff;
mod input;
mod ntdump;
mod png;
#[cfg(feature = "gui")]
mod window;

use input::InputScript;
use nes::Machine;
use std::path::PathBuf;

const DEFAULT_ROM: &str = "rom/mappy.nes";

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let cmd = args.first().map(|s| s.as_str()).unwrap_or("play");
    let rest = &args[args.len().min(1)..];
    let mut opts = Opts::parse(rest);
    match cmd {
        "play" => {
            #[cfg(feature = "gui")]
            {
                window::run(&mut opts);
            }
            #[cfg(not(feature = "gui"))]
            {
                eprintln!("built without the `gui` feature; use `headless` instead");
                std::process::exit(1);
            }
        }
        "headless" => headless(&mut opts),
        "trace" => trace(&mut opts),
        "diff" => run_diff(&mut opts),
        "ram" => ram(&mut opts),
        "nt" => nt(&mut opts),
        "probe" => probe(&mut opts),
        "bench" => bench(&mut opts),
        "apu" => apu_dump(&mut opts),
        "-h" | "--help" | "help" => usage(),
        other => {
            eprintln!("unknown command {other:?}\n");
            usage();
            std::process::exit(2);
        }
    }
}

fn usage() {
    println!(
        "mappy — the decompiled Mappy

USAGE:
    mappy play      [--scale N] [--no-audio] [--input SCRIPT] [--fps N] [--stats]
                    [--record FILE.wav]
    mappy headless  [--frames N] [--every N] [--outdir DIR] [--input SCRIPT]
    mappy trace     [--frames N] [--input SCRIPT] [--out FILE]
    mappy diff      [--rom PATH] [--frames N] [--input SCRIPT]
    mappy probe     [--frames N] [--every N] [--region X:Y:W:H] [--input SCRIPT]
    mappy nt        [--frames N] [--every N] [--outdir DIR] [--input SCRIPT]
    mappy ram       [--frames N] [--every N] [--at ADDR:COUNT] [--input SCRIPT]
    mappy bench     [--frames N]

`play` runs the decompiled game and needs no ROM file: the cartridge data is
compiled into the binary. Its game loop is locked to the console's frame rate
(60.0988 fps NTSC, override with --fps) and is paced against the wall clock, so
game speed never depends on how fast the host is. --stats prints the measured
frame rate once a second. The other commands use `--rom` (default
rom/mappy.nes) with the reference interpreter, for analysis and testing.

INPUT SCRIPT: comma separated `BUTTONS@START-END`, e.g.
    START@19-21,RIGHT@60-200,RIGHT+A@210-230
"
    );
}

struct Opts {
    rom_path: PathBuf,
    frames: u32,
    every: u32,
    outdir: PathBuf,
    script: String,
    scale: u32,
    audio: bool,
    out: PathBuf,
    at: Option<(u16, u16)>,
    pc_range: Option<(u16, u16)>,
    max_lines: usize,
    watch_ram: Option<u16>,
    region: Option<(u32, u32, u32, u32)>,
    decompiled: bool,
    /// Write the final frame's NES palette indices (256x240 bytes).
    dump_indices: bool,
    /// True when `--rom` was given explicitly.
    rom_given: bool,
    fps: f64,
    stats: bool,
    record: Option<PathBuf>,
}

impl Opts {
    fn parse(args: &[String]) -> Opts {
        let mut o = Opts {
            rom_path: PathBuf::from(DEFAULT_ROM),
            frames: 600,
            every: 60,
            outdir: PathBuf::from("shots"),
            script: String::new(),
            scale: 2,
            audio: true,
            out: PathBuf::from("/tmp/mappy.trace"),
            at: None,
            pc_range: None,
            max_lines: 400,
            watch_ram: None,
            region: None,
            decompiled: true,
            dump_indices: false,
            rom_given: false,
            fps: 60.0988,
            stats: false,
            record: None,
        };
        let mut i = 0;
        while i < args.len() {
            let need = |i: usize| -> String {
                args.get(i + 1).cloned().unwrap_or_else(|| {
                    eprintln!("{} requires a value", args[i]);
                    std::process::exit(2);
                })
            };
            match args[i].as_str() {
                "--rom" => {
                    o.rom_path = PathBuf::from(need(i));
                    o.rom_given = true;
                    i += 2;
                }
                "--frames" => {
                    o.frames = need(i).parse().unwrap_or(600);
                    i += 2;
                }
                "--every" => {
                    o.every = need(i).parse().unwrap_or(60).max(1);
                    i += 2;
                }
                "--outdir" => {
                    o.outdir = PathBuf::from(need(i));
                    i += 2;
                }
                "--input" => {
                    o.script = need(i);
                    i += 2;
                }
                "--scale" => {
                    o.scale = need(i).parse().unwrap_or(2).max(1);
                    i += 2;
                }
                "--no-audio" => {
                    o.audio = false;
                    i += 1;
                }
                "--out" => {
                    o.out = PathBuf::from(need(i));
                    i += 2;
                }
                "--at" => {
                    let v = need(i);
                    let (a, c) = v.split_once(':').unwrap_or((&v, "16"));
                    let addr = u16::from_str_radix(a.trim_start_matches("0x").trim_start_matches('$'), 16)
                        .unwrap_or(0);
                    let count: u16 = u16::from_str_radix(c.trim_start_matches("0x"), 16).unwrap_or(16);
                    o.at = Some((addr, count));
                    i += 2;
                }
                "--pc-range" => {
                    let v = need(i);
                    let (a, b) = v.split_once('-').unwrap_or((&v, &v));
                    let lo = u16::from_str_radix(a.trim_start_matches("0x"), 16).unwrap_or(0);
                    let hi = u16::from_str_radix(b.trim_start_matches("0x"), 16).unwrap_or(0xFFFF);
                    o.pc_range = Some((lo, hi));
                    i += 2;
                }
                "--fps" => {
                    o.fps = need(i).parse().unwrap_or(60.0988);
                    i += 2;
                }
                "--stats" => {
                    o.stats = true;
                    i += 1;
                }
                "--dump-indices" => {
                    o.dump_indices = true;
                    i += 1;
                }
                "--record" => {
                    o.record = Some(PathBuf::from(need(i)));
                    i += 2;
                }
                "--engine" => {
                    let v = need(i);
                    o.decompiled = v != "interpreter" && v != "ref";
                    i += 2;
                }
                "--region" => {
                    let v = need(i);
                    let parts: Vec<u32> = v.split([':', ',']).filter_map(|p| p.parse().ok()).collect();
                    if parts.len() == 4 {
                        o.region = Some((parts[0], parts[1], parts[2], parts[3]));
                    }
                    i += 2;
                }
                "--watch-ram" => {
                    let v = need(i);
                    o.watch_ram = u16::from_str_radix(v.trim_start_matches("0x").trim_start_matches('$'), 16).ok();
                    i += 2;
                }
                "--max-lines" => {
                    o.max_lines = need(i).parse().unwrap_or(400);
                    i += 2;
                }
                other => {
                    eprintln!("unknown option {other:?}");
                    std::process::exit(2);
                }
            }
        }
        o
    }

    fn rom(&self) -> Vec<u8> {
        std::fs::read(&self.rom_path).unwrap_or_else(|e| {
            eprintln!("cannot read ROM {:?}: {e}", self.rom_path);
            eprintln!("pass --rom PATH (Mappy is a 24 KiB iNES file)");
            std::process::exit(1);
        })
    }

    /// The decompiled engine is a static translation of the embedded cartridge
    /// image, so a different `--rom` can only be run through the interpreter.
    fn use_interpreter(&self) -> bool {
        !self.decompiled || self.rom_given
    }

    fn script(&self) -> InputScript {
        InputScript::parse(&self.script).unwrap_or_else(|e| {
            eprintln!("bad --input: {e}");
            std::process::exit(2);
        })
    }
}

fn headless(o: &mut Opts) {
    std::fs::create_dir_all(&o.outdir).ok();
    let rom = o.rom();
    let cart = nes::Cart::from_ines(&rom).expect("parse rom");
    let mut m = Machine::new(cart);
    let mut game = mappy_rom::Mappy::new();
    let script = o.script();
    let started = std::time::Instant::now();
    let decompiled = !o.use_interpreter();
    if o.decompiled && o.rom_given {
        eprintln!(
            "note: the decompiled engine runs the embedded cartridge image; \
             --rom selects the interpreter engine"
        );
    }
    for f in 0..o.frames {
        if decompiled {
            game.set_pad1(script.at(f));
            game.run_frame();
        } else {
            m.pad1 = script.at(f);
            m.run_frame_interpreter();
        }
        if f % o.every == 0 || f + 1 == o.frames {
            let fb = if decompiled { game.rgb() } else { m.framebuffer_rgb() };
            let path = format!("{}/frame_{f:04}.png", o.outdir.display());
            png::write_nes_frame(&path, &fb).unwrap();
            let pc = if decompiled { game.machine.cpu.pc } else { m.cpu.pc };
            println!("frame {f}: pc={pc:04X} -> {path}");
        }
    }
    if o.dump_indices {
        let ppu = if decompiled { &game.machine.ppu } else { &m.ppu };
        std::fs::write(o.outdir.join("indices.bin"), ppu.pixels).unwrap();
        std::fs::write(o.outdir.join("nametables.bin"), ppu.nametables).unwrap();
        std::fs::write(o.outdir.join("palette.bin"), ppu.palette).unwrap();
        std::fs::write(o.outdir.join("oam.bin"), ppu.oam).unwrap();
        {
            let mut log = String::from("frame,scanline,dot,value\n");
            for (f, sl, dot, v) in &ppu.palette_writes {
                log.push_str(&format!("{f},{sl},{dot},{v:02X}\n"));
            }
            std::fs::write(o.outdir.join("palette_writes.csv"), log).unwrap();
        }
        println!("wrote framebuffer indices, nametables, palette RAM and OAM to {:?}", o.outdir);
    }
    let elapsed = started.elapsed().as_secs_f64();
    let total = if decompiled { game.machine.total_cycles } else { m.total_cycles };
    println!(
        "{} frames, {total} machine cycles ({:.2} per frame, PPU dots/frame {:.1})",
        o.frames,
        total as f64 / o.frames as f64,
        3.0 * total as f64 / o.frames as f64
    );
    if decompiled {
        println!(
            "{} frames in {:.3}s = {:.0} fps (decompiled engine, single thread)",
            o.frames,
            elapsed,
            o.frames as f64 / elapsed
        );
    }
    let samples = if decompiled { game.take_audio() } else { m.apu.drain_samples() };
    if !samples.is_empty() {
        let path = format!("{}/audio.wav", o.outdir.display());
        let rate = if decompiled {
            game.machine.apu.sample_rate() as u32
        } else {
            m.apu.sample_rate() as u32
        };
        write_wav(&path, &samples, rate);
        println!("wrote {path} ({} samples)", samples.len());
    }
}

fn trace(o: &mut Opts) {
    let rom = o.rom();
    let cart = nes::Cart::from_ines(&rom).expect("parse rom");
    let mut m = Machine::new(cart);
    let script = o.script();
    let mut seen = vec![false; 0x10000];
    let mut printed = 0usize;
    for f in 0..o.frames {
        m.pad1 = script.at(f);
        let target = m.ppu.frame + 1;
        while m.ppu.frame < target {
            seen[m.cpu.pc as usize] = true;
            if let Some((lo, hi)) = o.pc_range {
                if m.cpu.pc >= lo && m.cpu.pc <= hi && printed < o.max_lines {
                    let fetch = |a: u16| -> u8 {
                        if a < 0x2000 {
                            m.ram[(a & 0x7FF) as usize]
                        } else if (0x2000..0x6000).contains(&a) {
                            0
                        } else {
                            let off = (a as usize).wrapping_sub(0x8000) & 0x3FFF;
                            m.cart.prg[off % m.cart.prg.len()]
                        }
                    };
                    let ins = mos6502::disasm::decode(m.cpu.pc, &fetch);
                    let watch = match o.watch_ram {
                        Some(a) => format!(" [{a:02X}]={:02X}", m.ram[(a & 0x7FF) as usize]),
                        None => String::new(),
                    };
                    println!(
                        "f{f:>4} cyc={:>8} pc={:04X} pad={:02X}{watch}  {}",
                        m.cpu.cycles,
                        m.cpu.pc,
                        m.pad1,
                        ins.text(&|_| None)
                    );
                    printed += 1;
                }
            }
            m.step_interpreter();
            if m.cpu.jammed {
                eprintln!("CPU jammed at ${:04X}", m.cpu.pc);
                break;
            }
        }
    }
    if o.pc_range.is_some() {
        return;
    }
    let mut out = String::new();
    let mut count = 0;
    for (addr, used) in seen.iter().enumerate() {
        if *used {
            out.push_str(&format!("{:04X}\n", addr));
            count += 1;
        }
    }
    std::fs::write(&o.out, out).unwrap();
    println!("traced {} distinct PCs over {} frames -> {:?}", count, o.frames, o.out);
}

fn run_diff(o: &mut Opts) {
    let rom = o.rom();
    let script = o.script();
    match diff::run(&rom, o.frames, &script, true) {
        Ok(frames) => println!("OK: {frames} frames, interpreter and decompiled Rust agree exactly"),
        Err(d) => {
            println!("DIVERGENCE at frame {}", d.frame);
            println!("  state: {}", d.what);
            println!("  interpreter: {}", d.interp);
            println!("  decompiled:  {}", d.decomp);
            if !d.history.is_empty() {
                println!("  recent instructions (interpreter):");
                for h in d.history {
                    println!("    {h}");
                }
            }
            std::process::exit(1);
        }
    }
}

fn ram(o: &mut Opts) {
    let rom = o.rom();
    let cart = nes::Cart::from_ines(&rom).expect("parse rom");
    let mut m = Machine::new(cart);
    let script = o.script();
    let (watch_addr, watch_count) = o.at.unwrap_or((0x0000, 0x800));
    let mut snapshot: Option<Vec<u8>> = None;
    for f in 0..o.frames {
        m.pad1 = script.at(f);
        m.run_frame_interpreter();
        if o.every > 0 && f % o.every == 0 {
            let mut line = format!("f{f:>4} pad={:02X}:", m.pad1);
            for i in 0..watch_count {
                let a = watch_addr.wrapping_add(i);
                line.push_str(&format!(" {:02X}", m.ram[(a & 0x07FF) as usize]));
            }
            println!("{line}");
        }
        if f + 1 == o.frames {
            snapshot = Some(m.ram.to_vec());
        }
    }
    if let Some(ram) = snapshot {
        if o.out != PathBuf::from("/tmp/mappy.trace") {
            std::fs::write(&o.out, &ram).unwrap();
            println!("wrote {} RAM bytes to {:?}", ram.len(), o.out);
        }
    }
    let (addr, count) = o.at.unwrap_or((0x0000, 0x100));
    println!("RAM ${addr:04X}..${:04X}:", addr.wrapping_add(count));
    let mut i = 0u16;
    while i < count {
        let a = addr.wrapping_add(i);
        let mut row = format!("{a:04X}:");
        for j in 0..16u16 {
            if j >= count - i {
                break;
            }
            let v = m.ram[(a.wrapping_add(j) & 0x07FF) as usize];
            row.push_str(&format!(" {v:02X}"));
        }
        println!("{row}");
        i += 16;
    }
    println!(
        "cpu: pc={:04X} a={:02X} x={:02X} y={:02X} sp={:02X} p={:02X}",
        m.cpu.pc, m.cpu.a, m.cpu.x, m.cpu.y, m.cpu.sp, m.cpu.p
    );
    println!("pad1={:02X} pad_reads={} pad_writes={}", m.pad1, m.pad_reads, m.pad_writes);
    if o.out != PathBuf::from("/tmp/mappy.trace") {
        std::fs::write(&o.out, m.ram).unwrap();
        println!("wrote 2048 RAM bytes to {:?}", o.out);
    }
}

/// Per-frame APU channel state as CSV, for comparison against a reference
/// emulator (`mappy apu --frames N --input ... --out /tmp/mine.csv`).
fn apu_dump(o: &mut Opts) {
    let rom = o.rom();
    let cart = nes::Cart::from_ines(&rom).expect("parse rom");
    let mut m = Machine::new(cart);
    let script = o.script();
    let mut out = String::from(
        "frame,p1_freq,p1_vol,p1_duty,p1_len,p2_freq,p2_vol,p2_duty,p2_len,tri_freq,tri_vol,tri_len,noise_freq,noise_vol,noise_len,dmc,tri_linear,tri_halt\n",
    );
    for f in 0..o.frames {
        m.pad1 = script.at(f);
        m.run_frame_interpreter();
        let s = m.apu.snapshot();
        out.push_str(&format!(
            "{f},{:.3},{},{},{},{:.3},{},{},{},{:.3},{},{},{:.3},{},{},{},{},{}\n",
            s.pulse1.frequency, s.pulse1.volume, s.pulse1.duty, s.pulse1.length,
            s.pulse2.frequency, s.pulse2.volume, s.pulse2.duty, s.pulse2.length,
            s.triangle.frequency, s.triangle.volume, s.triangle.length,
            s.noise.frequency, s.noise.volume, s.noise.length, s.dmc_output,
            s.triangle.linear, if s.triangle.halt { 1 } else { 0 },
        ));
    }
    std::fs::write(&o.out, out).unwrap();
    println!("wrote {} frames of APU state to {:?}", o.frames, o.out);
    let mut log = String::new();
    for (addr, val) in &m.apu.write_log {
        log.push_str(&format!("{addr:04X} {val:02X}\n"));
    }
    let writes_path = o.out.with_extension("writes.txt");
    std::fs::write(&writes_path, log).unwrap();
    println!("APU register writes:");
    for (i, n) in m.apu.write_count.iter().enumerate() {
        if *n > 0 {
            print!("  ${:04X}: {n}", 0x4000 + i);
        }
    }
    println!();
}

/// Throughput measurement: frames per second of the decompiled engine.
fn bench(o: &mut Opts) {
    let frames = if o.frames == 600 { 1800 } else { o.frames };
    let mut game = mappy_rom::Mappy::new();
    let script = o.script();
    let start = std::time::Instant::now();
    for f in 0..frames {
        game.set_pad1(script.at(f));
        game.run_frame();
    }
    let elapsed = start.elapsed().as_secs_f64();
    let fps = frames as f64 / elapsed;
    println!(
        "{frames} frames in {elapsed:.3}s = {fps:.0} fps ({:.1}x realtime), {} CPU cycles",
        fps / 60.0988,
        game.machine.cpu.cycles
    );
}

/// ASCII-art dump of a screen region, one block per frame.
fn probe(o: &mut Opts) {
    let rom = o.rom();
    let cart = nes::Cart::from_ines(&rom).expect("parse rom");
    let mut m = Machine::new(cart);
    let script = o.script();
    let (x0, y0, w, h) = match o.region {
        Some(r) => r,
        None => (0, 0, 128, 32),
    };
    for f in 0..o.frames {
        m.pad1 = script.at(f);
        m.run_frame_interpreter();
        if f % o.every != 0 && f + 1 != o.frames {
            continue;
        }
        println!("--- frame {f} region {x0},{y0} {w}x{h} (palette index as hex)");
        for y in y0..(y0 + h).min(240) {
            let mut line = String::new();
            for x in x0..(x0 + w).min(256) {
                let p = m.ppu.pixels[y as usize * 256 + x as usize];
                line.push(if p == 0 { '.' } else if p == 0x0F { '#' } else { '+' });
            }
            println!("{line}");
        }
    }
}

fn nt(o: &mut Opts) {
    let rom = o.rom();
    let cart = nes::Cart::from_ines(&rom).expect("parse rom");
    let mut m = Machine::new(cart);
    let script = o.script();
    std::fs::create_dir_all(&o.outdir).ok();
    for f in 0..o.frames {
        m.pad1 = script.at(f);
        m.run_frame_interpreter();
        if f % o.every == 0 || f + 1 == o.frames {
            let (rgb, w, h) = ntdump::render(&m);
            let path = format!("{}/nametables_{f:04}.png", o.outdir.display());
            png::write_rgb(&path, w, h, &rgb).unwrap();
            let fb = m.framebuffer_rgb();
            png::write_nes_frame(&format!("{}/screen_{f:04}.png", o.outdir.display()), &fb).unwrap();
            println!("frame {f}: scroll v={:04X} t={:04X} x={} -> {path}", m.ppu.v, m.ppu.t, m.ppu.fine_x);
            for table in 0..4 {
                for row in 0..6 {
                    let base = table * 0x400 + row * 32;
                    let tiles: Vec<String> = m.ppu.nametables[base..base + 32]
                        .iter()
                        .map(|t| format!("{t:02X}"))
                        .collect();
                    println!("  t{table}r{row}: {}", tiles.join(" "));
                }
            }
        }
    }
}

fn write_wav(path: &str, samples: &[f32], rate: u32) {
    let mut data = Vec::with_capacity(44 + samples.len() * 2);
    let data_len = (samples.len() * 2) as u32;
    data.extend_from_slice(b"RIFF");
    data.extend_from_slice(&(36 + data_len).to_le_bytes());
    data.extend_from_slice(b"WAVEfmt ");
    data.extend_from_slice(&16u32.to_le_bytes());
    data.extend_from_slice(&1u16.to_le_bytes());
    data.extend_from_slice(&1u16.to_le_bytes());
    data.extend_from_slice(&rate.to_le_bytes());
    data.extend_from_slice(&(rate * 2).to_le_bytes());
    data.extend_from_slice(&2u16.to_le_bytes());
    data.extend_from_slice(&16u16.to_le_bytes());
    data.extend_from_slice(b"data");
    data.extend_from_slice(&data_len.to_le_bytes());
    for &s in samples {
        data.extend_from_slice(&nes::apu::to_i16(s).to_le_bytes());
    }
    std::fs::write(path, data).unwrap();
}
