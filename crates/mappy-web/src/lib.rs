//! WebAssembly frontend for the decompiled game.
//!
//! The module exports a handful of `extern "C"` functions and nothing else, so
//! the page needs no bindgen glue, no bundler and no JS framework: the driver
//! in `web/mappy.js` instantiates the module, copies the framebuffer out of
//! wasm memory and pumps audio from it.
//!
//! Everything is single-threaded; `requestAnimationFrame` (JS) paces the game
//! to the console's 60.0988 fps, exactly like the native frontends.

use std::cell::RefCell;

use mappy_rom::Mappy;

const WIDTH: usize = 256;
const HEIGHT: usize = 240;

struct Web {
    game: Mappy,
    /// RGBA pixels handed to `ImageData` (256 * 240 * 4).
    rgba: Vec<u8>,
    /// Scratch buffer the JS side copies audio out of.
    audio: Vec<f32>,
    /// Samples produced by the emulator but not yet collected.
    pending: Vec<f32>,
}

thread_local! {
    static STATE: RefCell<Option<Web>> = const { RefCell::new(None) };
}

/// Create (or re-create) the game. `sample_rate` is the AudioContext's rate, so
/// the APU synthesises at exactly that rate and nothing has to be resampled.
/// Returns 0 on success.
#[no_mangle]
pub extern "C" fn mappy_init(sample_rate: f64) -> u32 {
    let mut game = Mappy::new();
    game.machine.apu.set_sample_rate(sample_rate);
    let web = Web {
        game,
        rgba: vec![0; WIDTH * HEIGHT * 4],
        audio: Vec::with_capacity(16384),
        pending: Vec::new(),
    };
    STATE.with(|s| *s.borrow_mut() = Some(web));
    0
}

/// Controller state as a bit mask (see [`nes::button`]): 1=A, 2=B, 4=Select,
/// 8=Start, 16=Up, 32=Down, 64=Left, 128=Right.
#[no_mangle]
pub extern "C" fn mappy_set_buttons(bits: u32) {
    STATE.with(|s| {
        if let Some(w) = s.borrow_mut().as_mut() {
            w.game.set_pad1(bits as u8);
        }
    });
}

/// Advance the machine by one video frame and refresh the RGBA buffer.
#[no_mangle]
pub extern "C" fn mappy_run_frame() {
    STATE.with(|s| {
        if let Some(w) = s.borrow_mut().as_mut() {
            w.game.run_frame();
            let pixels = w.game.pixels();
            for (i, &index) in pixels.iter().enumerate() {
                let c = nes::NES_PALETTE[(index & 0x3F) as usize];
                let o = i * 4;
                w.rgba[o] = c[0];
                w.rgba[o + 1] = c[1];
                w.rgba[o + 2] = c[2];
                w.rgba[o + 3] = 0xFF;
            }
        }
    });
}

/// Pointer to the RGBA framebuffer (`WIDTH * HEIGHT * 4` bytes).
#[no_mangle]
pub extern "C" fn mappy_rgb_ptr() -> *const u8 {
    STATE.with(|s| {
        s.borrow()
            .as_ref()
            .map_or(std::ptr::null(), |w| w.rgba.as_ptr())
    })
}

/// Copy up to `max` samples of 32-bit float audio into the scratch buffer and
/// return how many were written. `mappy_audio_ptr` addresses that buffer.
#[no_mangle]
pub extern "C" fn mappy_take_audio(max: u32) -> u32 {
    STATE.with(|s| {
        let mut borrow = s.borrow_mut();
        let Some(w) = borrow.as_mut() else { return 0 };
        let produced = w.game.take_audio();
        w.pending.extend_from_slice(&produced);
        let n = w.pending.len().min(max as usize);
        w.audio.clear();
        w.audio.extend_from_slice(&w.pending[..n]);
        w.pending.drain(..n);
        n as u32
    })
}

/// Pointer to the audio scratch buffer filled by [`mappy_take_audio`].
#[no_mangle]
pub extern "C" fn mappy_audio_ptr() -> *const f32 {
    STATE.with(|s| {
        s.borrow()
            .as_ref()
            .map_or(std::ptr::null(), |w| w.audio.as_ptr())
    })
}

/// Frames rendered since power-on (handy for a HUD or for tests).
#[no_mangle]
pub extern "C" fn mappy_frame_count() -> u32 {
    STATE.with(|s| s.borrow().as_ref().map_or(0, |w| w.game.frame as u32))
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
