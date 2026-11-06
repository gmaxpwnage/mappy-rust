//! C ABI for native frontends.
//!
//! The engine is built as a `no_std` static library so it can be linked into a
//! plain C program with the webOS NDK's glibc 2.12 toolchain: nothing here
//! pulls in Rust's standard library, its allocator or its libc bindings. The
//! frontend supplies `malloc`/`free` (and a panic handler is defined below),
//! draws the framebuffer with SDL2 and feeds the APU samples to a sound card.
//!
//! All functions take an opaque handle returned by [`mappy_create`], so more
//! than one machine can exist at a time and no global state is involved.

#![cfg_attr(not(feature = "std"), no_std)]

extern crate alloc;

use alloc::boxed::Box;
use alloc::vec;
use alloc::vec::Vec;
use core::alloc::{GlobalAlloc, Layout};
use core::panic::PanicInfo;

use mappy_rom::Mappy;

const WIDTH: usize = 256;
const HEIGHT: usize = 240;

extern "C" {
    fn malloc(size: usize) -> *mut u8;
    fn free(ptr: *mut u8);
    fn memalign(alignment: usize, size: usize) -> *mut u8;
    fn abort() -> !;
}

/// Allocator backed by the C runtime the frontend links against. Only the
/// engine's own `Vec`s go through here, so `malloc`'s 8-byte alignment covers
/// every allocation; `memalign` handles anything more demanding.
struct CAlloc;

unsafe impl GlobalAlloc for CAlloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        if layout.align() <= 8 {
            malloc(layout.size())
        } else {
            memalign(layout.align(), layout.size())
        }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, _layout: Layout) {
        free(ptr);
    }
}

#[global_allocator]
static ALLOC: CAlloc = CAlloc;

#[cfg(not(feature = "std"))]
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    unsafe { abort() }
}

pub struct Engine {
    game: Mappy,
    /// 0xAARRGGBB pixels for the frontend's texture.
    rgba: Vec<u32>,
    /// Samples produced by the last frame, so the frontend can copy them out
    /// without another allocation.
    audio: Vec<f32>,
}

/// Create a machine that synthesises at `sample_rate` Hz. Returns null only if
/// allocation fails. Free it with [`mappy_destroy`].
#[no_mangle]
pub extern "C" fn mappy_create(sample_rate: f64) -> *mut Engine {
    let mut game = Mappy::new();
    game.machine.apu.set_sample_rate(sample_rate);
    let engine = Engine {
        game,
        rgba: vec![0; WIDTH * HEIGHT],
        audio: Vec::new(),
    };
    Box::into_raw(Box::new(engine))
}

/// Destroy a machine created by [`mappy_create`].
#[no_mangle]
pub unsafe extern "C" fn mappy_destroy(handle: *mut Engine) {
    if !handle.is_null() {
        drop(Box::from_raw(handle));
    }
}

/// Controller state for player 1: 1=A, 2=B, 4=Select, 8=Start, 16=Up,
/// 32=Down, 64=Left, 128=Right (the same bits as the wasm build).
#[no_mangle]
pub unsafe extern "C" fn mappy_set_buttons(handle: *mut Engine, bits: u32) {
    if let Some(engine) = handle.as_mut() {
        engine.game.set_pad1(bits as u8);
    }
}

/// Run one video frame and refresh the framebuffer and audio buffers.
#[no_mangle]
pub unsafe extern "C" fn mappy_run_frame(handle: *mut Engine) {
    let Some(engine) = handle.as_mut() else { return };
    engine.game.run_frame();

    let pixels = engine.game.pixels();
    for (i, &index) in pixels.iter().enumerate() {
        let c = nes::NES_PALETTE[(index & 0x3F) as usize];
        engine.rgba[i] = 0xFF00_0000 | ((c[0] as u32) << 16) | ((c[1] as u32) << 8) | c[2] as u32;
    }
    engine.audio = engine.game.take_audio();
}

/// Framebuffer as 0xAARRGGBB pixels, `mappy_width() * mappy_height()` of them.
#[no_mangle]
pub unsafe extern "C" fn mappy_rgb_ptr(handle: *const Engine) -> *const u32 {
    match handle.as_ref() {
        Some(engine) => engine.rgba.as_ptr(),
        None => core::ptr::null(),
    }
}

/// Audio samples produced by the last frame, in `-1.0..=1.0`.
#[no_mangle]
pub unsafe extern "C" fn mappy_audio_ptr(handle: *const Engine) -> *const f32 {
    match handle.as_ref() {
        Some(engine) => engine.audio.as_ptr(),
        None => core::ptr::null(),
    }
}

/// Number of samples addressed by [`mappy_audio_ptr`].
#[no_mangle]
pub unsafe extern "C" fn mappy_audio_len(handle: *const Engine) -> u32 {
    match handle.as_ref() {
        Some(engine) => engine.audio.len() as u32,
        None => 0,
    }
}

/// Frames rendered since power-on.
#[no_mangle]
pub unsafe extern "C" fn mappy_frame_count(handle: *const Engine) -> u32 {
    match handle.as_ref() {
        Some(engine) => engine.game.frame as u32,
        None => 0,
    }
}

/// Framebuffer width in pixels.
#[no_mangle]
pub extern "C" fn mappy_width() -> u32 {
    WIDTH as u32
}

/// Framebuffer height in pixels.
#[no_mangle]
pub extern "C" fn mappy_height() -> u32 {
    HEIGHT as u32
}
