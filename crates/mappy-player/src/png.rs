//! Minimal PNG writer (RGB8, stored deflate blocks).
//!
//! Used by the headless frame dumper so screenshots need no external crate,
//! which keeps the toolchain dependency-free on every platform.

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for &b in data {
        crc ^= b as u32;
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xEDB8_8320 & mask);
        }
    }
    !crc
}

fn adler32(data: &[u8]) -> u32 {
    let mut a = 1u32;
    let mut b = 0u32;
    for &byte in data {
        a = (a + byte as u32) % 65521;
        b = (b + a) % 65521;
    }
    (b << 16) | a
}

fn chunk(out: &mut Vec<u8>, kind: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_be_bytes());
    let mut crc_input = Vec::with_capacity(4 + data.len());
    crc_input.extend_from_slice(kind);
    crc_input.extend_from_slice(data);
    out.extend_from_slice(&crc_input);
    out.extend_from_slice(&crc32(&crc_input).to_be_bytes());
}

/// Encode `rgb` (3 bytes per pixel, row-major) as a PNG file.
pub fn encode_rgb(width: u32, height: u32, rgb: &[u8]) -> Vec<u8> {
    let mut raw = Vec::with_capacity((width as usize * 3 + 1) * height as usize);
    for y in 0..height as usize {
        raw.push(0); // filter: none
        let row = &rgb[y * width as usize * 3..(y + 1) * width as usize * 3];
        raw.extend_from_slice(row);
    }

    // zlib stream with stored (uncompressed) deflate blocks.
    let mut z = Vec::with_capacity(raw.len() + raw.len() / 65535 * 5 + 16);
    z.push(0x78);
    z.push(0x01);
    let mut pos = 0;
    while pos < raw.len() {
        let n = (raw.len() - pos).min(65535);
        let last = pos + n == raw.len();
        z.push(if last { 1 } else { 0 });
        z.extend_from_slice(&(n as u16).to_le_bytes());
        z.extend_from_slice(&(!(n as u16)).to_le_bytes());
        z.extend_from_slice(&raw[pos..pos + n]);
        pos += n;
    }
    z.extend_from_slice(&adler32(&raw).to_be_bytes());

    let mut out = Vec::with_capacity(z.len() + 64);
    out.extend_from_slice(&[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]);
    let mut ihdr = Vec::new();
    ihdr.extend_from_slice(&width.to_be_bytes());
    ihdr.extend_from_slice(&height.to_be_bytes());
    ihdr.extend_from_slice(&[8, 2, 0, 0, 0]); // 8-bit, truecolor, deflate, no filter, no interlace
    chunk(&mut out, b"IHDR", &ihdr);
    chunk(&mut out, b"IDAT", &z);
    chunk(&mut out, b"IEND", &[]);
    out
}

/// Write a 256x240 NES frame (RGB u32 values) to a PNG file.
pub fn write_nes_frame(path: &str, pixels: &[u32]) -> std::io::Result<()> {
    let mut rgb = Vec::with_capacity(256 * 240 * 3);
    for &p in pixels.iter().take(256 * 240) {
        rgb.push((p >> 16) as u8);
        rgb.push((p >> 8) as u8);
        rgb.push(p as u8);
    }
    let png = encode_rgb(256, 240, &rgb);
    std::fs::write(path, png)
}

/// Write an arbitrary RGB buffer (used for debug dumps such as nametables).
pub fn write_rgb(path: &str, width: u32, height: u32, rgb: &[u8]) -> std::io::Result<()> {
    std::fs::write(path, encode_rgb(width, height, rgb))
}
