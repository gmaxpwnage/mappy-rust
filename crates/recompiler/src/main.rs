//! `recompiler` — turn the Mappy iNES image into Rust source and a listing.
//!
//! Usage:
//!   recompiler <rom.nes> [--asm out.asm] [--rust out.rs] [--symbols file] [--stats]
//!
//! Paths are interpreted relative to the current directory.

mod analysis;
mod codegen;
mod listing;

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() || args.iter().any(|a| a == "-h" || a == "--help") {
        println!("usage: recompiler <rom.nes> [--asm PATH] [--rust PATH] [--symbols PATH] [--data-dir DIR] [--coverage FILE] [--stats]");
        std::process::exit(if args.is_empty() { 2 } else { 0 });
    }
    let rom_path = PathBuf::from(&args[0]);
    let mut asm_path: Option<PathBuf> = None;
    let mut rust_path: Option<PathBuf> = None;
    let mut symbols_path: Option<PathBuf> = None;
    let mut data_dir: Option<PathBuf> = None;
    let mut coverage: Option<PathBuf> = None;
    let mut stats = false;
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--asm" => {
                asm_path = Some(PathBuf::from(&args[i + 1]));
                i += 2;
            }
            "--rust" => {
                rust_path = Some(PathBuf::from(&args[i + 1]));
                i += 2;
            }
            "--symbols" => {
                symbols_path = Some(PathBuf::from(&args[i + 1]));
                i += 2;
            }
            "--coverage" => {
                coverage = Some(PathBuf::from(&args[i + 1]));
                i += 2;
            }
            "--data-dir" => {
                data_dir = Some(PathBuf::from(&args[i + 1]));
                i += 2;
            }
            "--stats" => {
                stats = true;
                i += 1;
            }
            other => fail(&format!("unknown argument: {other}")),
        }
    }

    let data = std::fs::read(&rom_path).unwrap_or_else(|e| fail(&format!("{rom_path:?}: {e}")));
    let cart = nes::Cart::from_ines(&data).unwrap_or_else(|e| fail(&e));
    println!(
        "PRG: {} bytes, CHR: {} bytes, mapper {:?}, mirroring {:?}",
        cart.prg.len(),
        cart.chr.len(),
        cart.mapper,
        cart.mirroring
    );
    if cart.prg.len() != analysis::PRG_SIZE {
        fail("this recompiler targets the 16 KiB NROM image of Mappy");
    }

    let dynamic: Vec<u16> = match &coverage {
        Some(p) => {
            let text = std::fs::read_to_string(p).unwrap_or_else(|e| fail(&format!("{p:?}: {e}")));
            text.lines()
                .filter_map(|l| u16::from_str_radix(l.trim(), 16).ok())
                .collect()
        }
        None => Vec::new(),
    };
    if !dynamic.is_empty() {
        println!("coverage: {} executed addresses from {:?}", dynamic.len(), coverage.unwrap());
    }
    let a = analysis::Analysis::analyze_with(cart.prg.clone(), &dynamic);
    println!(
        "vectors: NMI ${:04X} RESET ${:04X} IRQ ${:04X}",
        a.nmi, a.reset, a.irq
    );
    let code_bytes = a.code.iter().filter(|b| **b).count();
    println!(
        "code: {} bytes in {} instructions; {} data bytes; {} labels; {} subroutines",
        code_bytes,
        a.instrs.len(),
        analysis::PRG_SIZE - code_bytes,
        a.labels.len(),
        a.jsr_targets().len()
    );
    if !a.unknown_jumps.is_empty() {
        let list: Vec<String> = a.unknown_jumps.iter().map(|x| format!("${x:04X}")).collect();
        println!("computed jump pointers: {}", list.join(", "));
    }

    let symbols = match &symbols_path {
        Some(p) => load_symbols(p),
        None => BTreeMap::new(),
    };
    if !symbols.is_empty() {
        println!("symbols: {} from {:?}", symbols.len(), symbols_path.as_ref().unwrap());
    }

    if stats {
        print_stats(&a);
    }

    if let Some(p) = asm_path {
        write_file(&p, listing::listing(&a, &symbols).as_bytes());
        println!("wrote {}", p.display());
    }
    if let Some(dir) = data_dir {
        write_file(&dir.join("prg.bin"), &cart.prg);
        write_file(&dir.join("chr.bin"), &cart.chr);
        println!("wrote {}/prg.bin and {}/chr.bin", dir.display(), dir.display());
    }
    if let Some(p) = rust_path {
        let src = codegen::generate(&a, &symbols);
        write_file(&p, src.as_bytes());
        println!("wrote {} ({} lines)", p.display(), src.lines().count());
    }
}

fn fail(msg: &str) -> ! {
    eprintln!("error: {msg}");
    std::process::exit(1)
}

fn write_file(path: &Path, data: &[u8]) {
    if let Some(dir) = path.parent() {
        if !dir.as_os_str().is_empty() {
            std::fs::create_dir_all(dir).unwrap_or_else(|e| fail(&format!("{dir:?}: {e}")));
        }
    }
    std::fs::write(path, data).unwrap_or_else(|e| fail(&format!("{path:?}: {e}")));
}

/// Symbol table: one `ADDR name` per line, `;` starts a comment.
fn load_symbols(path: &Path) -> BTreeMap<u16, String> {
    let text = std::fs::read_to_string(path).unwrap_or_else(|e| fail(&format!("{path:?}: {e}")));
    let mut map = BTreeMap::new();
    for (n, line) in text.lines().enumerate() {
        let line = line.split(';').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        let mut it = line.split_whitespace();
        let addr = it.next().unwrap();
        let name = match it.next() {
            Some(n) => n,
            None => fail(&format!("{path:?}:{}: expected `ADDR name`", n + 1)),
        };
        let addr = u16::from_str_radix(addr.trim_start_matches("0x").trim_start_matches('$'), 16)
            .unwrap_or_else(|_| fail(&format!("{path:?}:{}: bad address {addr}", n + 1)));
        map.insert(addr, name.to_string());
    }
    map
}

fn print_stats(a: &analysis::Analysis) {
    let mut by_name: BTreeMap<&str, usize> = BTreeMap::new();
    for ins in a.instrs.values() {
        *by_name.entry(ins.op.name).or_default() += 1;
    }
    let mut v: Vec<_> = by_name.into_iter().collect();
    v.sort_by_key(|(_, c)| std::cmp::Reverse(*c));
    println!("instruction mix:");
    for (name, count) in v {
        println!("  {name:<5} {count}");
    }
}
