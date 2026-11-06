//! Render the PPU's nametables to a PNG, independent of scrolling.
//!
//! This is a debug view: it shows *what is in VRAM* (tiles, attributes,
//! palettes) rather than what the beam draws, which makes scroll-window bugs
//! easy to tell apart from VRAM corruption.

use nes::Machine;

pub fn render(m: &Machine) -> (Vec<u8>, u32, u32) {
    // Two nametables side by side = 512x240, plus the attribute palettes.
    let width = 512u32;
    let height = 240u32;
    let mut rgb = vec![0u8; (width * height * 3) as usize];
    let palette = &m.ppu.palette;
    for nt in 0..2u32 {
        let base = (nt as usize) * 0x400; // nametable A then B (vertical mirroring)
        for row in 0..30usize {
            for col in 0..32usize {
                let tile = m.ppu.nametables[base + row * 32 + col];
                let attr_addr = base + 0x3C0 + (row / 4) * 8 + (col / 4);
                let attr = m.ppu.nametables[attr_addr];
                let shift = ((row % 4) / 2) * 4 + ((col % 4) / 2) * 2;
                let pal = (attr >> shift) & 0x03;
                for py in 0..8usize {
                    let lo = m.cart.chr_read((tile as u16) * 16 + py as u16);
                    let hi = m.cart.chr_read((tile as u16) * 16 + py as u16 + 8);
                    for px in 0..8usize {
                        let bit = 7 - px;
                        let index = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1);
                        let color_idx = if index == 0 { 0 } else { pal * 4 + index };
                        let c = nes::NES_PALETTE[(palette[color_idx as usize & 0x1F] & 0x3F) as usize];
                        let x = nt * 256 + (col * 8 + px) as u32;
                        let y = (row * 8 + py) as u32;
                        if x < width && y < height {
                            let o = ((y * width + x) * 3) as usize;
                            rgb[o] = c[0];
                            rgb[o + 1] = c[1];
                            rgb[o + 2] = c[2];
                        }
                    }
                }
            }
        }
    }
    (rgb, width, height)
}
