use mos6502::disasm::decode;
fn main() {
    let a: Vec<String> = std::env::args().collect();
    let path = &a[1];
    let start = u16::from_str_radix(&a[2], 16).unwrap();
    let end = u16::from_str_radix(&a[3], 16).unwrap();
    let img = std::fs::read(path).unwrap();
    let fetch = |x: u16| img[x as usize];
    let mut pc = start;
    while pc < end {
        let i = decode(pc, &fetch);
        println!("{:04X}  {:<9} {}", pc, i.bytes_hex(), i.text(&|_| None));
        pc += i.len;
    }
}
