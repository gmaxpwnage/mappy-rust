//! The 2C02 picture processing unit.
//!
//! The PPU is modelled dot by dot: 341 dots per scanline, 262 scanlines per
//! frame, with the standard background fetch pipeline (16-pixel lookahead),
//! sprite evaluation at dot 257, sprite-0 hit detection, the odd-frame dot
//! skip, and the $2006/$2007 VRAM port including its read buffer.

use crate::cart::{Cart, Mirroring};

/// Default 2C02 palette (RGB), index 0-63. Emphasis bits are not modelled.
pub static NES_PALETTE: [[u8; 3]; 64] = [
    [124, 124, 124], [0, 0, 252], [0, 0, 188], [68, 40, 188],
    [148, 0, 132], [168, 0, 32], [168, 16, 0], [136, 20, 0],
    [80, 48, 0], [0, 120, 0], [0, 104, 0], [0, 88, 0],
    [0, 64, 88], [0, 0, 0], [0, 0, 0], [0, 0, 0],
    [188, 188, 188], [0, 120, 248], [0, 88, 248], [104, 68, 252],
    [216, 0, 204], [228, 0, 88], [248, 56, 0], [228, 92, 16],
    [172, 124, 0], [0, 184, 0], [0, 168, 0], [0, 168, 68],
    [0, 136, 136], [0, 0, 0], [0, 0, 0], [0, 0, 0],
    [248, 248, 248], [60, 188, 252], [104, 136, 252], [152, 120, 248],
    [248, 120, 248], [248, 88, 152], [248, 120, 88], [252, 160, 68],
    [248, 184, 0], [184, 248, 24], [88, 216, 84], [88, 248, 152],
    [0, 232, 216], [120, 120, 120], [0, 0, 0], [0, 0, 0],
    [252, 252, 252], [164, 228, 252], [184, 184, 248], [216, 184, 248],
    [248, 184, 248], [248, 164, 192], [240, 208, 176], [252, 224, 168],
    [248, 216, 120], [216, 248, 120], [184, 248, 184], [184, 248, 216],
    [0, 252, 252], [248, 216, 248], [0, 0, 0], [0, 0, 0],
];

#[derive(Clone, Copy, Default)]
struct SpriteSlot {
    x: u8,
    attr: u8,
    lo: u8,
    hi: u8,
    index: u8,
    active: bool,
}

pub struct Ppu {
    // Registers.
    pub ctrl: u8,     // $2000
    pub mask: u8,     // $2001
    pub status: u8,   // $2002
    pub oam_addr: u8, // $2003
    pub oam: [u8; 256],
    pub palette: [u8; 32],
    /// 4 KiB of nametable RAM, addressed through the mirroring mode.
    pub nametables: [u8; 0x1000],
    pub mirroring: Mirroring,

    // Internal scroll/address registers.
    pub v: u16,
    pub t: u16,
    pub fine_x: u8,
    pub write_toggle: bool,
    read_buffer: u8,
    open_bus: u8,

    // Timing.
    pub scanline: u16,
    pub dot: u16,
    pub frame: u64,
    odd_frame: bool,
    /// Set for one read after a frame boundary; the frontend polls this.
    pub frame_ready: bool,

    /// Rendered output, one NES palette index per pixel.
    pub pixels: [u8; 256 * 240],
    /// Number of pixels actually written this frame (for diagnostics).
    pub pixels_written: u32,

    // Background pipeline.
    bg_lo: u16,
    bg_hi: u16,
    at_lo: u16,
    at_hi: u16,
    nt_byte: u8,
    at_byte: u8,
    pat_lo: u8,
    pat_hi: u8,

    sprites: [SpriteSlot; 8],
    sprite_count: usize,

    /// True when the PPU wants to assert /NMI (edge triggered by the machine).
    pub nmi_out: bool,
}

impl Default for Ppu {
    fn default() -> Self {
        Ppu::new()
    }
}

impl Ppu {
    pub fn new() -> Ppu {
        Ppu {
            ctrl: 0,
            mask: 0,
            status: 0,
            oam_addr: 0,
            oam: [0; 256],
            palette: [0; 32],
            nametables: [0; 0x1000],
            mirroring: Mirroring::Vertical,
            v: 0,
            t: 0,
            fine_x: 0,
            write_toggle: false,
            read_buffer: 0,
            open_bus: 0,
            scanline: 261,
            dot: 0,
            frame: 0,
            odd_frame: false,
            frame_ready: false,
            pixels: [0; 256 * 240],
            pixels_written: 0,
            bg_lo: 0,
            bg_hi: 0,
            at_lo: 0,
            at_hi: 0,
            nt_byte: 0,
            at_byte: 0,
            pat_lo: 0,
            pat_hi: 0,
            sprites: [SpriteSlot::default(); 8],
            sprite_count: 0,
            nmi_out: false,
        }
    }

    // ---------------------------------------------------------------
    // Address decoding.
    // ---------------------------------------------------------------

    fn nametable_index(&self, addr: u16) -> usize {
        let a = (addr & 0x0FFF) as usize;
        let table = a >> 10;
        let off = a & 0x03FF;
        let phys = match self.mirroring {
            Mirroring::Vertical => table & 1,
            Mirroring::Horizontal => (table >> 1) & 1,
            Mirroring::FourScreen => table,
            Mirroring::SingleLower => 0,
            Mirroring::SingleUpper => 1,
        };
        (phys & 1) * 0x400 + off
    }

    fn palette_index(addr: u16) -> usize {
        let mut i = (addr & 0x1F) as usize;
        // $3F10/$3F14/$3F18/$3F1C mirror the background entries.
        if i >= 16 && i % 4 == 0 {
            i -= 16;
        }
        i
    }

    /// The PPU's view of $0000-$3FFF (pattern memory + nametables + palette).
    pub fn read_vram(&mut self, cart: &Cart, addr: u16) -> u8 {
        let addr = addr & 0x3FFF;
        match addr {
            0x0000..=0x1FFF => cart.chr_read(addr),
            0x2000..=0x3EFF => self.nametables[self.nametable_index(addr)],
            0x3F00..=0x3FFF => self.palette[Self::palette_index(addr)],
            _ => 0,
        }
    }

    pub fn write_vram(&mut self, cart: &mut Cart, addr: u16, val: u8) {
        let addr = addr & 0x3FFF;
        match addr {
            0x0000..=0x1FFF => cart.chr_write(addr, val),
            0x2000..=0x3EFF => {
                let i = self.nametable_index(addr);
                self.nametables[i] = val;
            }
            0x3F00..=0x3FFF => {
                let i = Self::palette_index(addr);
                self.palette[i] = val & 0x3F;
            }
            _ => {}
        }
    }

    // ---------------------------------------------------------------
    // CPU-visible registers.
    // ---------------------------------------------------------------

    /// The PPU's I/O latch; write-only registers read back as this value.
    pub fn open_bus(&self) -> u8 {
        self.open_bus
    }

    pub fn read_status(&mut self) -> u8 {
        let val = (self.status & 0xE0) | (self.open_bus & 0x1F);
        self.status &= !0x80;
        self.nmi_out = false;
        self.write_toggle = false;
        self.open_bus = val;
        val
    }

    pub fn read_oam(&mut self) -> u8 {
        let v = self.oam[self.oam_addr as usize];
        self.open_bus = v;
        v
    }

    pub fn read_data(&mut self, cart: &Cart) -> u8 {
        let addr = self.v & 0x3FFF;
        let mut val = self.read_vram(cart, addr);
        if addr < 0x3F00 {
            let buffered = self.read_buffer;
            self.read_buffer = val;
            val = buffered;
        } else {
            // Palette reads are immediate; the buffer gets the mirrored
            // nametable byte underneath.
            self.read_buffer = self.read_vram(cart, addr & 0x2FFF);
            self.open_bus = val;
        }
        self.increment_v();
        val
    }

    pub fn write_ctrl(&mut self, val: u8) {
        self.ctrl = val;
        self.t = (self.t & 0xF3FF) | (((val as u16) & 0x03) << 10);
        self.open_bus = val;
        if self.status & 0x80 != 0 && self.ctrl & 0x80 != 0 {
            self.nmi_out = true;
        }
    }

    pub fn write_mask(&mut self, val: u8) {
        self.mask = val;
        self.open_bus = val;
    }

    pub fn write_oam_addr(&mut self, val: u8) {
        self.oam_addr = val;
    }

    pub fn write_oam_data(&mut self, val: u8) {
        self.oam[self.oam_addr as usize] = val;
        self.oam_addr = self.oam_addr.wrapping_add(1);
    }

    pub fn write_scroll(&mut self, val: u8) {
        if !self.write_toggle {
            self.fine_x = val & 0x07;
            self.t = (self.t & 0xFFE0) | ((val as u16) >> 3);
        } else {
            self.t = (self.t & 0x8FFF) | (((val as u16) & 0x07) << 12);
            self.t = (self.t & 0xFC1F) | (((val as u16) & 0xF8) << 2);
        }
        self.write_toggle = !self.write_toggle;
        self.open_bus = val;
    }

    pub fn write_addr(&mut self, val: u8) {
        if !self.write_toggle {
            self.t = (self.t & 0x00FF) | (((val as u16) & 0x3F) << 8);
        } else {
            self.t = (self.t & 0xFF00) | (val as u16);
            self.v = self.t;
        }
        self.write_toggle = !self.write_toggle;
        self.open_bus = val;
    }

    pub fn write_data(&mut self, cart: &mut Cart, val: u8) {
        self.write_vram(cart, self.v, val);
        self.increment_v();
        self.open_bus = val;
    }

    fn increment_v(&mut self) {
        let inc = if self.ctrl & 0x04 != 0 { 32 } else { 1 };
        self.v = self.v.wrapping_add(inc) & 0x7FFF;
    }

    // ---------------------------------------------------------------
    // Scroll register helpers (the classic loopy_v "coarse/fine" dance).
    // ---------------------------------------------------------------

    fn inc_x(&mut self) {
        if (self.v & 0x001F) == 31 {
            self.v &= !0x001F;
            self.v ^= 0x0400; // toggle horizontal nametable
        } else {
            self.v += 1;
        }
    }

    fn inc_y(&mut self) {
        if (self.v & 0x7000) != 0x7000 {
            self.v += 0x1000;
        } else {
            self.v &= !0x7000;
            let mut y = (self.v & 0x03E0) >> 5;
            if y == 29 {
                y = 0;
                self.v ^= 0x0800; // toggle vertical nametable
            } else if y == 31 {
                y = 0;
            } else {
                y += 1;
            }
            self.v = (self.v & !0x03E0) | (y << 5);
        }
    }

    fn copy_x(&mut self) {
        self.v = (self.v & !0x041F) | (self.t & 0x041F);
    }

    fn copy_y(&mut self) {
        self.v = (self.v & !0x7BE0) | (self.t & 0x7BE0);
    }

    // ---------------------------------------------------------------
    // Background fetch pipeline.
    // ---------------------------------------------------------------

    fn fetch_nt(&mut self, cart: &Cart) {
        self.nt_byte = self.read_vram(cart, 0x2000 | (self.v & 0x0FFF));
    }

    fn fetch_at(&mut self, cart: &Cart) {
        let addr = 0x23C0 | (self.v & 0x0C00) | ((self.v >> 4) & 0x38) | ((self.v >> 2) & 0x07);
        let at = self.read_vram(cart, addr);
        let shift = ((self.v >> 4) & 4) | (self.v & 2);
        self.at_byte = (at >> shift) & 0x03;
    }

    fn fetch_pat_lo(&mut self, cart: &Cart) {
        let addr = ((self.ctrl as u16 & 0x10) << 8) | ((self.nt_byte as u16) << 4) | ((self.v >> 12) & 0x07);
        self.pat_lo = cart.chr_read(addr);
    }

    fn fetch_pat_hi(&mut self, cart: &Cart) {
        let addr = ((self.ctrl as u16 & 0x10) << 8) | ((self.nt_byte as u16) << 4) | ((self.v >> 12) & 0x07) | 0x08;
        self.pat_hi = cart.chr_read(addr);
    }

    fn reload_shifters(&mut self) {
        self.bg_lo = (self.bg_lo & 0xFF00) | self.pat_lo as u16;
        self.bg_hi = (self.bg_hi & 0xFF00) | self.pat_hi as u16;
        let lo = if self.at_byte & 1 != 0 { 0xFF } else { 0x00 };
        let hi = if self.at_byte & 2 != 0 { 0xFF } else { 0x00 };
        self.at_lo = (self.at_lo & 0xFF00) | lo;
        self.at_hi = (self.at_hi & 0xFF00) | hi;
    }

    fn shift_bg(&mut self) {
        self.bg_lo <<= 1;
        self.bg_hi <<= 1;
        self.at_lo <<= 1;
        self.at_hi <<= 1;
    }

    // ---------------------------------------------------------------
    // Sprites.
    // ---------------------------------------------------------------

    fn sprite_height(&self) -> u16 {
        if self.ctrl & 0x20 != 0 {
            16
        } else {
            8
        }
    }

    /// Evaluate OAM for the next scanline and prefetch pattern data.
    fn eval_sprites(&mut self, cart: &Cart) {
        let height = self.sprite_height();
        let next_line = if self.scanline == 261 { 0 } else { self.scanline + 1 };
        self.sprite_count = 0;
        let mut overflow = false;
        for i in 0..64 {
            let base = i * 4;
            let y = self.oam[base] as i16;
            let row = next_line as i16 - y;
            if row < 0 || row >= height as i16 {
                continue;
            }
            if self.sprite_count == 8 {
                overflow = true;
                break;
            }
            let tile = self.oam[base + 1];
            let attr = self.oam[base + 2];
            let x = self.oam[base + 3];
            let mut r = row as u16;
            let flip_v = attr & 0x80 != 0;
            let flip_h = attr & 0x40 != 0;
            if flip_v {
                r = height - 1 - r;
            }
            let addr = if height == 16 {
                let bank = ((tile as u16) & 1) << 12;
                let t = (tile as u16 & 0xFE) | ((r >> 3) & 1);
                bank | (t << 4) | (r & 7)
            } else {
                ((self.ctrl as u16 & 0x08) << 9) | ((tile as u16) << 4) | (r & 7)
            };
            let mut lo = cart.chr_read(addr);
            let mut hi = cart.chr_read(addr | 0x08);
            if flip_h {
                lo = lo.reverse_bits();
                hi = hi.reverse_bits();
            }
            self.sprites[self.sprite_count] = SpriteSlot { x, attr, lo, hi, index: i as u8, active: true };
            self.sprite_count += 1;
        }
        if overflow {
            self.status |= 0x20;
        }
    }

    // ---------------------------------------------------------------
    // Pixel composition.
    // ---------------------------------------------------------------

    fn bg_pixel(&self) -> (u8, bool) {
        if self.mask & 0x08 == 0 {
            return (0, false);
        }
        let shift = 15u16.saturating_sub(self.fine_x as u16);
        let lo = (self.bg_lo >> shift) & 1;
        let hi = (self.bg_hi >> shift) & 1;
        let pal = (lo | (hi << 1)) as u8;
        if pal == 0 {
            return (0, false);
        }
        let alo = (self.at_lo >> shift) & 1;
        let ahi = (self.at_hi >> shift) & 1;
        let attr = (alo | (ahi << 1)) as usize;
        let mut color = self.palette[attr * 4 + pal as usize] & 0x3F;
        if self.mask & 0x01 != 0 {
            color &= 0x30; // greyscale
        }
        (color, true)
    }

    fn render_pixel(&mut self, x: u16) -> u8 {
        let backdrop_idx = if self.mask & 0x01 != 0 { self.palette[0] & 0x30 } else { self.palette[0] & 0x3F };
        let mut color = backdrop_idx;
        let rendering = self.mask & 0x18 != 0;
        if !rendering {
            return color;
        }
        let show_bg = self.mask & 0x08 != 0 && (x >= 8 || self.mask & 0x02 != 0);
        let (bg_color, bg_opaque) = if show_bg { self.bg_pixel() } else { (0, false) };
        if bg_opaque {
            color = bg_color;
        }
        let show_sprites = self.mask & 0x10 != 0 && (x >= 8 || self.mask & 0x04 != 0);
        if show_sprites {
            for i in 0..self.sprite_count {
                let s = self.sprites[i];
                if !s.active {
                    continue;
                }
                let sx = s.x as i32;
                let px = x as i32 - sx;
                if !(0..8).contains(&px) {
                    continue;
                }
                let bit = 7 - px as u8;
                let lo = (s.lo >> bit) & 1;
                let hi = (s.hi >> bit) & 1;
                let pal = (lo | (hi << 1)) as u8;
                if pal == 0 {
                    continue;
                }
                if s.index == 0 && bg_opaque && x != 255 {
                    self.status |= 0x40;
                }
                let behind = s.attr & 0x20 != 0;
                if !(behind && bg_opaque) {
                    let pi = 4 + (s.attr as usize & 0x03) * 4 + pal as usize;
                    let mut c = self.palette[pi] & 0x3F;
                    if self.mask & 0x01 != 0 {
                        c &= 0x30;
                    }
                    color = c;
                }
                break;
            }
        }
        color
    }

    // ---------------------------------------------------------------
    // One dot of PPU time.
    // ---------------------------------------------------------------

    pub fn tick(&mut self, cart: &Cart) {
        let rendering = self.mask & 0x18 != 0;
        let visible = self.scanline < 240;
        let pre_render = self.scanline == 261;

        // VBlank / status flag transitions.
        if self.scanline == 241 && self.dot == 1 {
            self.status |= 0x80;
            if self.ctrl & 0x80 != 0 {
                self.nmi_out = true;
            }
        }
        if pre_render && self.dot == 1 {
            self.status &= !0xE0;
            self.nmi_out = false;
        }

        // Background pipeline.
        if (visible || pre_render) && rendering {
            if (2..=257).contains(&self.dot) || (322..=337).contains(&self.dot) {
                self.shift_bg();
                match (self.dot - 1) % 8 {
                    0 => {
                        self.reload_shifters();
                        self.fetch_nt(cart);
                    }
                    2 => self.fetch_at(cart),
                    4 => self.fetch_pat_lo(cart),
                    6 => self.fetch_pat_hi(cart),
                    7 => self.inc_x(),
                    _ => {}
                }
            }
            if self.dot == 256 {
                self.inc_y();
            }
            if self.dot == 257 {
                self.copy_x();
                self.eval_sprites(cart);
            }
            if pre_render && (280..=304).contains(&self.dot) {
                self.copy_y();
            }
        }

        // Composition.
        if visible && (1..=256).contains(&self.dot) {
            let px = self.render_pixel(self.dot - 1);
            self.pixels[self.scanline as usize * 256 + (self.dot as usize - 1)] = px;
            self.pixels_written += 1;
        }

        // Advance the beam.
        self.dot += 1;
        if self.dot > 340 {
            self.dot = 0;
            self.scanline += 1;
            if self.scanline > 261 {
                self.scanline = 0;
                self.frame += 1;
                self.odd_frame = !self.odd_frame;
                self.frame_ready = true;
                self.pixels_written = 0;
            }
        } else if self.odd_frame && rendering && self.scanline == 261 && self.dot == 340 {
            // Odd frames skip the last dot of the pre-render line.
            self.dot = 0;
            self.scanline = 0;
            self.frame += 1;
            self.odd_frame = !self.odd_frame;
            self.frame_ready = true;
            self.pixels_written = 0;
        }
    }

    /// Advance the PPU by `cycles` CPU cycles (3 dots each).
    pub fn run(&mut self, cart: &Cart, cpu_cycles: u32) {
        for _ in 0..cpu_cycles * 3 {
            self.tick(cart);
        }
    }

    /// Take (and clear) the "frame finished" latch.
    pub fn take_frame_ready(&mut self) -> bool {
        let r = self.frame_ready;
        self.frame_ready = false;
        r
    }
}
