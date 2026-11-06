//! iNES cartridge handling.

/// Nametable mirroring.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Mirroring {
    Horizontal,
    Vertical,
    FourScreen,
    SingleLower,
    SingleUpper,
}

/// The four iNES mapper numbers this project knows how to read. Mappy uses
/// NROM; the others exist so the emulator core is useful beyond this one game.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Mapper {
    Nrom,
    Mmc1,
    UxRom,
    CnRom,
}

pub struct Cart {
    pub prg: Vec<u8>,
    pub chr: Vec<u8>,
    pub chr_is_ram: bool,
    pub mirroring: Mirroring,
    pub mapper: Mapper,
    // MMC1 state
    shift: u8,
    shift_count: u8,
    control: u8,
    chr_bank0: u8,
    prg_bank: u8,
}

impl Cart {
    /// Build an NROM cartridge from raw PRG/CHR data (used by the decompiled
    /// game, which embeds its own data).
    pub fn from_image(prg: Vec<u8>, chr: Vec<u8>) -> Cart {
        let chr_is_ram = chr.is_empty();
        Cart {
            prg,
            chr: if chr_is_ram { vec![0u8; 8192] } else { chr },
            chr_is_ram,
            mirroring: Mirroring::Vertical,
            mapper: Mapper::Nrom,
            shift: 0,
            shift_count: 0,
            control: 0x0C,
            chr_bank0: 0,
            prg_bank: 0,
        }
    }

    /// Parse an iNES image (with NES 2.0 headers tolerated).
    pub fn from_ines(data: &[u8]) -> Result<Cart, String> {
        if data.len() < 16 || &data[0..4] != b"NES\x1a" {
            return Err("not an iNES image".into());
        }
        let prg_banks = data[4] as usize;
        let chr_banks = data[5] as usize;
        let flags6 = data[6];
        let flags7 = data[7];
        let mapper_num = (flags7 & 0xF0) | (flags6 >> 4);
        let mapper = match mapper_num {
            0 => Mapper::Nrom,
            1 => Mapper::Mmc1,
            2 => Mapper::UxRom,
            3 => Mapper::CnRom,
            n => return Err(format!("unsupported mapper {n}")),
        };
        let mirroring = match flags6 & 0x09 {
            0 => Mirroring::Horizontal,
            1 => Mirroring::Vertical,
            8 => Mirroring::FourScreen,
            _ => Mirroring::Horizontal,
        };
        let prg_len = if prg_banks == 0 { 16384 } else { prg_banks * 16384 };
        let chr_len = chr_banks * 8192;
        let mut pos = 16 + if flags6 & 0x04 != 0 { 512 } else { 0 };
        if data.len() < pos + prg_len + chr_len {
            return Err(format!(
                "truncated image: need {} bytes, have {}",
                pos + prg_len + chr_len,
                data.len()
            ));
        }
        let prg = data[pos..pos + prg_len].to_vec();
        pos += prg_len;
        let (chr, chr_is_ram) = if chr_len == 0 {
            (vec![0u8; 8192], true)
        } else {
            (data[pos..pos + chr_len].to_vec(), false)
        };
        Ok(Cart {
            prg,
            chr,
            chr_is_ram,
            mirroring,
            mapper,
            shift: 0,
            shift_count: 0,
            control: 0x0C,
            chr_bank0: 0,
            prg_bank: 0,
        })
    }

    /// Read from the CPU's $4020-$FFFF cartridge space.
    pub fn read_prg(&self, addr: u16) -> u8 {
        let a = addr as usize;
        match self.mapper {
            Mapper::Nrom => {
                let off = if self.prg.len() == 16384 {
                    (a - 0x8000) & 0x3FFF
                } else {
                    (a - 0x8000) & 0x7FFF
                };
                self.prg[off % self.prg.len()]
            }
            Mapper::CnRom => {
                let off = (a - 0x8000) & 0x7FFF;
                self.prg[off % self.prg.len()]
            }
            Mapper::UxRom => {
                if a >= 0xC000 {
                    let n = self.prg.len();
                    self.prg[n - 0x4000 + ((a - 0xC000) & 0x3FFF)]
                } else {
                    let bank = self.prg_bank as usize & (self.prg.len() / 0x4000 - 1);
                    self.prg[bank * 0x4000 + ((a - 0x8000) & 0x3FFF)]
                }
            }
            Mapper::Mmc1 => {
                if a >= 0xC000 {
                    let n = self.prg.len();
                    self.prg[n - 0x4000 + ((a - 0xC000) & 0x3FFF)]
                } else {
                    let bank = self.prg_bank as usize % (self.prg.len() / 0x4000);
                    self.prg[bank * 0x4000 + ((a - 0x8000) & 0x3FFF)]
                }
            }
        }
    }

    /// Write to the cartridge space (mapper registers and CHR RAM).
    pub fn write_prg(&mut self, addr: u16, val: u8) {
        if self.chr_is_ram && (0x8000..).contains(&addr) {
            // Mapper register writes may also select CHR banks; handled below.
        }
        match self.mapper {
            Mapper::Nrom => {}
            Mapper::CnRom => {
                self.chr_bank0 = val & 0x03;
            }
            Mapper::UxRom => {
                self.prg_bank = val & 0x0F;
            }
            Mapper::Mmc1 => {
                if val & 0x80 != 0 {
                    self.shift = 0;
                    self.shift_count = 0;
                    self.control |= 0x0C;
                    return;
                }
                self.shift |= (val & 1) << self.shift_count;
                self.shift_count += 1;
                if self.shift_count == 5 {
                    let shift = self.shift;
                    let reg = (addr >> 13) & 3;
                    match reg {
                        0 => self.control = shift,
                        1 => self.chr_bank0 = shift,
                        2 => self.chr_bank0 = shift,
                        3 => self.prg_bank = shift & 0x0F,
                        _ => {}
                    }
                    self.shift = 0;
                    self.shift_count = 0;
                }
            }
        }
    }

    /// Read pattern memory ($0000-$1FFF as seen by the PPU).
    pub fn chr_read(&self, addr: u16) -> u8 {
        let a = addr as usize & 0x1FFF;
        match self.mapper {
            Mapper::CnRom => {
                let bank = self.chr_bank0 as usize * 0x2000;
                self.chr[(bank + a) % self.chr.len()]
            }
            _ => self.chr[a % self.chr.len()],
        }
    }

    pub fn chr_write(&mut self, addr: u16, val: u8) {
        if self.chr_is_ram {
            let a = addr as usize & 0x1FFF;
            let n = self.chr.len();
            self.chr[a % n] = val;
        }
    }

    pub fn mirroring(&self) -> Mirroring {
        match self.mapper {
            Mapper::Mmc1 => match self.control & 3 {
                0 => Mirroring::SingleLower,
                1 => Mirroring::SingleUpper,
                2 => Mirroring::Vertical,
                3 => Mirroring::Horizontal,
                _ => unreachable!(),
            },
            _ => self.mirroring,
        }
    }
}
