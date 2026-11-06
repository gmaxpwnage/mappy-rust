//! Rendering tests for the PPU: palette values, the first pixels of a
//! scanline (the background prefetch window) and sprite Y semantics.
//!
//! These pin down two bugs that made our output differ from a reference
//! emulator: a prefetch window that started one dot late (blanking the
//! leftmost 8 pixels of every line) and sprites drawn one scanline too high.

use nes::{Cart, Ppu};

fn cart_with_pattern(rows: [u8; 8]) -> Cart {
    let mut prg = vec![0u8; 16384];
    prg[0] = 0x40; // RTI-ish filler; never executed
    let mut chr = vec![0u8; 8192];
    // Tile 1 (pattern table 0): the given rows in bit plane 0.
    for (i, row) in rows.iter().enumerate() {
        chr[1 * 16 + i] = *row;
    }
    Cart::from_image(prg, chr)
}

/// Put a solid tile across the top of the screen and enable background
/// rendering at scroll (0, 0).
fn setup_background(ppu: &mut Ppu, cart: &mut Cart, tile: u8) {
    for i in 0..32 * 30 {
        ppu.write_vram(cart, 0x2000 + i, tile);
    }
    for i in 0..64 {
        ppu.write_vram(cart, 0x23C0 + i, 0x00); // all quadrants: palette 0
    }
    ppu.write_vram(cart, 0x3F00, 0x0F); // backdrop black
    ppu.write_vram(cart, 0x3F01, 0x30); // palette 0 colour 1: white
    ppu.write_ctrl(0x00);
    ppu.write_mask(0x0A); // background on, left column shown
    ppu.write_scroll(0);
    ppu.write_scroll(0);
}

#[test]
fn leftmost_pixels_of_each_scanline_are_rendered() {
    // This is the regression test for the prefetch window: with the window
    // starting at dot 322 instead of 321 the first 8 pixels of every line
    // stayed at the backdrop colour.
    let mut cart = cart_with_pattern([0xFF; 8]);
    let mut ppu = Ppu::new();
    setup_background(&mut ppu, &mut cart, 1);
    ppu.run(&cart, 29_780); // one frame
    let white = nes::NES_PALETTE[0x30][0];
    for y in [0usize, 1, 40, 120, 200] {
        for x in 0..16 {
            let px = ppu.pixels[y * 256 + x];
            assert_eq!(
                nes::NES_PALETTE[px as usize][0],
                white,
                "pixel ({x}, {y}) is not the background tile (index {px:#04x})"
            );
        }
    }
}

#[test]
fn sprite_y_is_the_scanline_above_its_first_row() {
    let mut cart = cart_with_pattern([0xFF; 8]);
    let mut ppu = Ppu::new();
    // Everything backdrop, one sprite at Y = 10, X = 0, in front.
    ppu.write_vram(&mut cart, 0x3F00, 0x0F);
    ppu.write_vram(&mut cart, 0x3F11, 0x16); // sprite palette 0 colour 1: red
    ppu.write_ctrl(0x00); // 8x8 sprites, pattern table 0
    ppu.write_mask(0x14); // sprites on, left column shown
    ppu.oam[0] = 10; // Y
    ppu.oam[1] = 1; // tile
    ppu.oam[2] = 0; // attributes: palette 0, in front
    ppu.oam[3] = 0; // X
    ppu.run(&cart, 29_780);
    let red = nes::NES_PALETTE[0x16][0];
    let at = |y: usize| nes::NES_PALETTE[ppu.pixels[y * 256] as usize][0];
    assert_eq!(at(11), red, "sprite should start on scanline Y+1");
    assert_ne!(at(10), red, "sprite must not appear on scanline Y");
    assert_eq!(at(11 + 7), red, "sprite should cover 8 scanlines");
    assert_ne!(at(11 + 8), red, "sprite must not bleed past 8 scanlines");
}

#[test]
fn palette_matches_the_reference_emulator() {
    // Values taken from Mednafen's built-in NES palette and verified against
    // its rendered output.
    assert_eq!(nes::NES_PALETTE[0x0F], [0, 0, 0]);
    assert_eq!(nes::NES_PALETTE[0x13], [128, 0, 240]);
    assert_eq!(nes::NES_PALETTE[0x16], [216, 40, 0]);
    assert_eq!(nes::NES_PALETTE[0x17], [200, 76, 12]);
    assert_eq!(nes::NES_PALETTE[0x21], [60, 188, 252]);
    assert_eq!(nes::NES_PALETTE[0x27], [252, 152, 56]);
    assert_eq!(nes::NES_PALETTE[0x29], [128, 208, 16]);
    assert_eq!(nes::NES_PALETTE[0x30], [252, 252, 252]);
    assert_eq!(nes::NES_PALETTE.len(), 64);
}

#[test]
fn sprites_use_the_sprite_palettes_not_the_background_ones() {
    let mut cart = cart_with_pattern([0xFF; 8]);
    let mut ppu = Ppu::new();
    // Background palette 0 colour 1 is white; sprite palette 0 colour 1 is red.
    ppu.write_vram(&mut cart, 0x3F00, 0x0F);
    ppu.write_vram(&mut cart, 0x3F01, 0x30);
    ppu.write_vram(&mut cart, 0x3F11, 0x16);
    ppu.write_ctrl(0x00);
    ppu.write_mask(0x14);
    ppu.oam[0] = 10;
    ppu.oam[1] = 1;
    ppu.oam[2] = 0;
    ppu.oam[3] = 0;
    ppu.run(&cart, 29_780);
    let px = ppu.pixels[11 * 256];
    assert_eq!(
        nes::NES_PALETTE[px as usize],
        nes::NES_PALETTE[0x16],
        "sprite pixel used {px:#04x}, which is not the sprite palette colour"
    );
}
