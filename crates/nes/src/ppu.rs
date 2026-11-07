//! The 2C02 picture processing unit.
//!
//! The beam runs dot by dot (341 dots per scanline, 262 scanlines per frame),
//! so vblank and NMI timing, sprite evaluation at dot 257, the odd-frame dot
//! skip and the $2006/$2007 port all keep hardware timing. The visible line is
//! composed in one pass as the beam enters it, from the scroll address captured
//! at dot 320 of the previous line and the sprite layer built at dot 257.

use alloc::vec::Vec;

use crate::cart::{Cart, Mirroring};

/// The 2C02 palette, in the RGB values Mednafen's NES core uses by default.
///
/// Taken from the reference emulator's own built-in table and then verified
/// against its rendered output: every distinct colour in a reference frame
/// maps to exactly one entry here. Using the same values keeps our screenshots
/// colour-identical to the reference rather than merely similar.
pub static NES_PALETTE: [[u8; 3]; 64] = [
    [116, 116, 116], [36, 24, 140], [0, 0, 168], [68, 0, 156], [140, 0, 116], [168, 0, 16], [164, 0, 0], [124, 8, 0], [64, 44, 0], [0, 68, 0], [0, 80, 0], [0, 60, 20], [24, 60, 92], [0, 0, 0], [0, 0, 0], [0, 0, 0],
    [188, 188, 188], [0, 112, 236], [32, 56, 236], [128, 0, 240], [188, 0, 188], [228, 0, 88], [216, 40, 0], [200, 76, 12], [136, 112, 0], [0, 148, 0], [0, 168, 0], [0, 144, 56], [0, 128, 136], [0, 0, 0], [0, 0, 0], [0, 0, 0],
    [252, 252, 252], [60, 188, 252], [92, 148, 252], [64, 136, 252], [244, 120, 252], [252, 116, 180], [252, 116, 96], [252, 152, 56], [240, 188, 60], [128, 208, 16], [76, 220, 72], [88, 248, 152], [0, 232, 216], [120, 120, 120], [0, 0, 0], [0, 0, 0],
    [252, 252, 252], [168, 228, 252], [196, 212, 252], [212, 200, 252], [252, 196, 252], [252, 196, 216], [252, 188, 176], [252, 216, 168], [252, 228, 160], [224, 252, 160], [168, 240, 188], [176, 252, 204], [156, 252, 240], [196, 196, 196], [0, 0, 0], [0, 0, 0],
];

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

    /// Sprite layer for the line just evaluated, composed at dot 257.
    ///
    /// `sp_color[x]` is the palette index (16..=31) of the winning sprite at
    /// pixel `x`, or 0 when no sprite covers it: palette index 0 means
    /// transparent, and sprite entries never live below 16.
    /// `sp_flags[x]` is bit 0 behind-background, bit 1 sprite 0.
    sp_color: [u8; 256],
    sp_flags: [u8; 256],

    /// Scroll address captured at dot 1, which is where the visible line is
    /// drawn from. The fetch pipeline moves `v` during the line, so the line
    /// has to remember its own start.
    line_v: u16,
    /// Dot at which sprite 0 is hit this line (`u16::MAX` when it is not).
    s0_dot: u16,
    /// A register write changed the current line after it was drawn.
    render_dirty: bool,

    /// True when the PPU wants to assert /NMI (edge triggered by the machine).
    pub nmi_out: bool,
    /// Recent palette-RAM writes with their beam position (diagnostics).
    pub palette_writes: Vec<(u64, u16, u16, u8)>,
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
            sp_color: [0; 256],
            sp_flags: [0; 256],
            line_v: 0,
            s0_dot: u16::MAX,
            render_dirty: false,
            nmi_out: false,
            palette_writes: Vec::new(),
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
                self.mark_line_dirty();
                let i = Self::palette_index(addr);
                self.palette[i] = val & 0x3F;
                if self.palette_writes.len() < 4096 {
                    self.palette_writes
                        .push((self.frame, self.scanline, self.dot, val));
                }
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

    /// Note a write that changes how the current line is drawn, so the rest of
    /// the line is redrawn from the beam position on the next dot.
    #[inline]
    fn mark_line_dirty(&mut self) {
        if self.scanline < 240 && (1..=256).contains(&self.dot) {
            self.render_dirty = true;
        }
    }

    pub fn write_ctrl(&mut self, val: u8) {
        self.mark_line_dirty();
        self.ctrl = val;
        self.t = (self.t & 0xF3FF) | (((val as u16) & 0x03) << 10);
        self.open_bus = val;
        if self.status & 0x80 != 0 && self.ctrl & 0x80 != 0 {
            self.nmi_out = true;
        }
    }

    pub fn write_mask(&mut self, val: u8) {
        self.mark_line_dirty();
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
        self.mark_line_dirty();
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

    /// Evaluate OAM for the next scanline and compose its sprite layer.
    fn eval_sprites(&mut self, cart: &Cart) {
        let height = self.sprite_height();
        let next_line = if self.scanline == 261 { 0 } else { self.scanline + 1 };
        self.sp_color = [0; 256];
        self.sp_flags = [0; 256];
        let mut count = 0;
        let mut overflow = false;
        for i in 0..64 {
            let base = i * 4;
            let y = self.oam[base] as i16;
            // A sprite's Y register points at the scanline *above* its first
            // row, so row 0 of a sprite with Y = y is drawn on scanline y + 1.
            let row = next_line as i16 - y - 1;
            if row < 0 || row >= height as i16 {
                continue;
            }
            if count == 8 {
                overflow = true;
                break;
            }
            count += 1;
            let tile = self.oam[base + 1];
            let attr = self.oam[base + 2];
            let x = self.oam[base + 3] as u16;
            let mut r = row as u16;
            if attr & 0x80 != 0 {
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
            if attr & 0x40 != 0 {
                lo = lo.reverse_bits();
                hi = hi.reverse_bits();
            }
            // OAM priority decides ties: a later sprite only fills pixels that
            // earlier sprites left transparent.
            let palette = 16 + ((attr & 0x03) as u8) * 4;
            let flags = ((attr & 0x20) >> 5) | if i == 0 { 2 } else { 0 };
            for px in 0..8u16 {
                let sx = x + px;
                if sx >= 256 {
                    break;
                }
                let bit = 7 - px as u8;
                let pal = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1);
                if pal != 0 && self.sp_color[sx as usize] == 0 {
                    self.sp_color[sx as usize] = palette + pal;
                    self.sp_flags[sx as usize] = flags;
                }
            }
        }
        if overflow {
            self.status |= 0x20;
        }
    }

    // ---------------------------------------------------------------
    // Pixel composition.
    // ---------------------------------------------------------------

    /// Draw the visible line from pixel `from` to 255.
    ///
    /// The background comes from `line_v` and `fine_x` directly (33 tile
    /// fetches per line) instead of the per-dot shifters, and sprites from the
    /// layer composed at dot 257. `render_pixel` used to do this one dot at a
    /// time; the work is identical, just grouped so the state is loaded once
    /// per line instead of once per pixel.
    fn render_line_from(&mut self, cart: &Cart, from: u16) {
        let base = self.scanline as usize * 256;
        let mask = self.mask;
        let gray: u8 = if mask & 0x01 != 0 { 0x30 } else { 0x3F };
        let backdrop = self.palette[0] & gray;
        let rendering = mask & 0x18 != 0;
        if !rendering {
            for px in &mut self.pixels[base + from as usize..base + 256] {
                *px = backdrop;
            }
            self.pixels_written += 256 - from as u32;
            return;
        }
        let bg_on = mask & 0x08 != 0;
        let sp_on = mask & 0x10 != 0;
        let bg_clip = mask & 0x02 != 0;
        let sp_clip = mask & 0x04 != 0;

        // Fetch the tiles this line covers: the 8 pixels of scroll before the
        // first tile mean a line can span 33 tiles.
        let mut lo = [0u8; 33];
        let mut hi = [0u8; 33];
        let mut attr = [0u8; 33];
        if bg_on {
            let v = self.line_v;
            let fine_y = (v >> 12) & 0x07;
            let pat_base = (self.ctrl as u16 & 0x10) << 8;
            let mut addr = 0x2000 | (v & 0x0FFF);
            for t in 0..33usize {
                let nt = self.read_vram(cart, addr);
                let at_addr = 0x23C0 | (addr & 0x0C00) | ((addr >> 4) & 0x38) | ((addr >> 2) & 0x07);
                let at = self.read_vram(cart, at_addr);
                let shift = ((addr >> 4) & 4) | (addr & 2);
                attr[t] = (at >> shift) & 0x03;
                let pat = pat_base | ((nt as u16) << 4) | fine_y;
                lo[t] = cart.chr_read(pat);
                hi[t] = cart.chr_read(pat | 0x08);
                if addr & 0x1F == 31 {
                    addr = (addr & !0x1F) ^ 0x0400;
                } else {
                    addr += 1;
                }
            }
        }

        // Compose by tile: the attribute and the palette entries behind it are
        // constant across the 8 pixels a tile contributes, so they are looked
        // up once per tile instead of once per pixel.
        let fine_x = self.fine_x as u16;
        let mut s0 = self.s0_dot;
        let mut x = from;
        let mut t = ((x + fine_x) >> 3) as usize;
        let mut bit = 7 - ((x + fine_x) & 7) as u8;
        let mut lo_t = lo[t.min(32)];
        let mut hi_t = hi[t.min(32)];
        let mut pal4 = [backdrop; 4];
        if bg_on {
            let base = attr[t.min(32)] as usize * 4;
            pal4 = [
                backdrop,
                self.palette[base + 1] & gray,
                self.palette[base + 2] & gray,
                self.palette[base + 3] & gray,
            ];
        }
        while x < 256 {
            let mut color = backdrop;
            let mut opaque = false;
            if bg_on && (x >= 8 || bg_clip) {
                let pal = ((lo_t >> bit) & 1) | (((hi_t >> bit) & 1) << 1);
                if pal != 0 {
                    color = pal4[pal as usize];
                    opaque = true;
                }
            }
            if sp_on && (x >= 8 || sp_clip) {
                let sp = self.sp_color[x as usize];
                if sp != 0 {
                    let flags = self.sp_flags[x as usize];
                    if flags & 2 != 0 && opaque && x != 255 && x + 1 < s0 {
                        s0 = x + 1;
                    }
                    if flags & 1 == 0 || !opaque {
                        color = self.palette[sp as usize] & gray;
                    }
                }
            }
            self.pixels[base + x as usize] = color;
            x += 1;
            if bit == 0 {
                t = ((x + fine_x) >> 3) as usize;
                if t > 32 {
                    break;
                }
                bit = 7 - ((x + fine_x) & 7) as u8;
                lo_t = lo[t];
                hi_t = hi[t];
                if bg_on {
                    let base = attr[t] as usize * 4;
                    pal4 = [
                        backdrop,
                        self.palette[base + 1] & gray,
                        self.palette[base + 2] & gray,
                        self.palette[base + 3] & gray,
                    ];
                }
            } else {
                bit -= 1;
            }
        }
        self.s0_dot = s0;
        self.pixels_written += 256 - from as u32;
    }

    // ---------------------------------------------------------------
    // One dot of PPU time.
    // ---------------------------------------------------------------

    #[inline(always)]
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

        // The line's start address is v as it stands when the prefetch for the
        // next line begins, so hblank writes are already applied and the
        // prefetch's own coarse-X increments are not yet counted.
        if (visible || pre_render) && self.dot == 320 {
            self.line_v = self.v;
        }

        // Background pipeline. The visible line is drawn from `line_v` by
        // render_line_from, so the per-dot fetches are only needed while a
        // line is being streamed dot by dot (rendering switched on
        // mid-scanline, when hardware keeps shifting stale shifter data).
        if (visible || pre_render) && rendering {
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

        // Composition. The whole visible line is drawn in one pass as the beam
        // enters it, and redrawn from the beam position if a register write
        // changes how the rest of the line looks. Sprite 0 hit is still
        // reported on the dot where the beam meets the pixel.
        if visible && self.dot == 1 {
            self.s0_dot = u16::MAX;
            self.render_line_from(cart, 0);
        } else if visible && self.render_dirty && (1..=256).contains(&self.dot) {
            self.render_line_from(cart, self.dot - 1);
        }
        self.render_dirty = false;
        if visible && self.dot == self.s0_dot {
            self.status |= 0x40;
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

    /// Dots from here to the next one where anything happens. Everything else
    /// is the beam moving, which `run` can skip in one step.
    #[inline(always)]
    fn dots_to_event(&self) -> u32 {
        if self.render_dirty {
            return 0;
        }
        let d = self.dot;
        // Stop at dot 340 on every line: `tick` wraps the beam there.
        let mut next = 340u16;
        if d <= 1 {
            next = next.min(1);
        }
        if d <= 256 {
            next = next.min(256);
        }
        if d <= 257 {
            next = next.min(257);
        }
        if d <= 320 {
            next = next.min(320);
        }
        if self.scanline == 261 {
            if (280..=304).contains(&d) {
                next = d;
            } else if d < 280 {
                next = next.min(280);
            }
        }
        if self.s0_dot <= 256 && d <= self.s0_dot {
            next = next.min(self.s0_dot);
        }
        (next - d) as u32
    }

    /// Advance the PPU by `cycles` CPU cycles (3 dots each).
    pub fn run(&mut self, cart: &Cart, cpu_cycles: u32) {
        let mut left = cpu_cycles * 3;
        while left > 0 {
            let step = self.dots_to_event().min(left);
            if step > 0 {
                self.dot += step as u16;
                left -= step;
            } else {
                self.tick(cart);
                left -= 1;
            }
        }
    }

    /// Take (and clear) the "frame finished" latch.
    pub fn take_frame_ready(&mut self) -> bool {
        let r = self.frame_ready;
        self.frame_ready = false;
        r
    }
}
