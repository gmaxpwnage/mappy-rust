//! NES/Famicom hardware model, independent of any platform or frontend.
//!
//! * [`cart`] — iNES loading and cartridge mappers
//! * [`ppu`] — the picture unit (dot-accurate background pipeline, sprites)
//! * [`apu`] — the audio unit (pulses, triangle, noise, DMC)
//! * [`machine`] — the bus tying them together, plus controller handling
//!
//! Everything here is plain `std` Rust with no platform dependencies, so the
//! same code runs on Linux, macOS, Windows, and (with a software framebuffer)
//! in a headless test harness.

#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

pub mod apu;
pub mod cart;
pub mod machine;
pub mod ppu;

pub use apu::{Apu, ApuSnapshot, ChannelState};
pub use cart::{Cart, Mapper, Mirroring};
pub use machine::{button, Machine};
pub use ppu::{Ppu, NES_PALETTE};

pub use mos6502;
