//! Native window, keyboard and sound frontend (winit + softbuffer + cpal).
//!
//! Cross-platform by construction: winit abstracts the window system, so the
//! same code runs on Linux (X11/Wayland), macOS, Windows and more. Audio is
//! optional at build time (`--no-default-features --features gui`).
//!
//! # Frame pacing
//!
//! Mappy's game logic is driven by the console's vblank interrupt: one frame of
//! game time is one NMI, i.e. one 341x262-dot PPU frame. The frontend therefore
//! advances the machine by *whole frames* against the wall clock, at the
//! console's own rate (60.0988 Hz NTSC), and never by "however fast the CPU
//! happens to run". Emulation speed and game speed are decoupled: the engine
//! could render ~850 frames/s, but the game still runs at 60.

use std::collections::VecDeque;
use std::fs::File;
use std::io::{Seek, SeekFrom, Write};
use std::num::NonZeroU32;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use nes::button;
use winit::application::ApplicationHandler;
use winit::event::{ElementState, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::keyboard::{KeyCode, PhysicalKey};
use winit::window::{Window, WindowId};

use crate::Opts;

const NES_W: usize = 256;
const NES_H: usize = 240;

/// NTSC NES frame rate: 1.789773 MHz / (341 dots x 262 lines / 3 dots per CPU
/// cycle) = 60.0988 Hz. `--fps` can override it (e.g. `--fps 60`).
const NTSC_FPS: f64 = 60.0988;

/// Never try to catch up more than this many frames in one wake-up; beyond it
/// the clock is re-based instead, so a stalled window cannot fast-forward the
/// game.
const MAX_CATCHUP_FRAMES: u32 = 3;

pub fn run(opts: &mut Opts) {
    let game = mappy_rom::Mappy::new();
    let script = crate::input::InputScript::parse(&opts.script).unwrap_or_default();
    let auto_input = !opts.script.is_empty();
    let audio: Option<AudioOut> = if opts.audio { AudioOut::new() } else { None };
    let mut game = game;
    // Synthesise audio at the rate the device actually wants, so nothing has
    // to be resampled (and the pitch/tempo stay exactly right).
    if let Some(a) = &audio {
        game.machine.apu.set_sample_rate(a.sample_rate() as f64);
        if opts.stats {
            eprintln!(
                "audio: {} Hz, {} channel(s), {}",
                a.sample_rate(),
                a.channels(),
                a.sample_format()
            );
        }
    }
    let fps = if opts.fps > 1.0 { opts.fps } else { NTSC_FPS };
    // Open the recorder before `audio` is moved into the app.
    let recorder = match opts.record.as_ref() {
        Some(path) => {
            let rate = audio
                .as_ref()
                .map(|a| a.sample_rate())
                .unwrap_or(nes::apu::SAMPLE_RATE as u32);
            Some(
                Recorder::create(path.to_str().unwrap_or("mappy.wav"), rate)
                    .unwrap_or_else(|e| panic!("cannot record to {path:?}: {e}")),
            )
        }
        None => None,
    };
    let mut app = App {
        game,
        scale: opts.scale.max(1) as usize,
        window: None,
        surface: None,
        context: None,
        audio,
        fps,
        frame_duration: Duration::from_secs_f64(1.0 / fps),
        next_deadline: Instant::now(),
        catch_up: false,
        script,
        auto_input,
        frame: 0,
        stats: opts.stats,
        stats_frames: 0,
        stats_since: Instant::now(),
        stats_rendered: 0,
        recorder,
    };
    if opts.stats {
        eprintln!("pacing: locked to {fps:.4} frames/s ({:.2} ms/frame)", 1000.0 / fps);
    }
    let event_loop = EventLoop::new().expect("create event loop");
    event_loop.set_control_flow(ControlFlow::WaitUntil(app.next_deadline));
    event_loop.run_app(&mut app).expect("run event loop");
}

struct App {
    game: mappy_rom::Mappy,
    scale: usize,
    window: Option<Arc<Window>>,
    surface: Option<softbuffer::Surface<Arc<Window>, Arc<Window>>>,
    context: Option<softbuffer::Context<Arc<Window>>>,
    audio: Option<AudioOut>,
    /// Locked frame rate of the game loop, in frames per second.
    fps: f64,
    /// Wall-clock duration of one frame at that rate.
    frame_duration: Duration,
    /// Wall-clock time at which the next frame is due.
    next_deadline: Instant,
    /// Set while the loop is behind and catching up (diagnostics only).
    catch_up: bool,
    /// Scripted input (see `--input`); when non-empty it drives player 1.
    script: crate::input::InputScript,
    auto_input: bool,
    /// Frames of game time elapsed.
    frame: u32,
    stats: bool,
    stats_frames: u32,
    stats_since: Instant,
    stats_rendered: u32,
    recorder: Option<Recorder>,
}

impl App {
    fn set_window(&mut self, window: Arc<Window>) {
        let context = softbuffer::Context::new(window.clone()).expect("softbuffer context");
        let surface = softbuffer::Surface::new(&context, window.clone()).expect("surface");
        self.context = Some(context);
        self.surface = Some(surface);
        self.window = Some(window);
    }

    fn present(&mut self) {
        let (Some(window), Some(surface)) = (self.window.as_ref(), self.surface.as_mut()) else {
            return;
        };
        let size = window.inner_size();
        let (Some(w), Some(h)) = (NonZeroU32::new(size.width), NonZeroU32::new(size.height)) else {
            return;
        };
        surface.resize(w, h).expect("resize surface");
        let Ok(mut buffer) = surface.buffer_mut() else {
            return;
        };
        let scale_x = size.width as usize / NES_W;
        let scale_y = size.height as usize / NES_H;
        let (sx, sy) = (scale_x.max(1), scale_y.max(1));
        let row_pixels = size.width as usize;
        let pixels = self.game.rgb();
        for y in 0..NES_H * sy {
            let src_y = y / sy;
            let out_row = y * row_pixels;
            if out_row + row_pixels > buffer.len() {
                break;
            }
            for x in 0..NES_W * sx {
                let c = pixels[src_y * NES_W + (x / sx).min(NES_W - 1)];
                buffer[out_row + x.min(row_pixels - 1)] = c;
            }
        }
        buffer.present().expect("present");
    }

    /// Run every game frame whose deadline has arrived, then present.
    ///
    /// The game advances in exact multiples of one PPU frame at the locked
    /// rate; it never runs faster because the host is fast, and it falls
    /// behind by at most [`MAX_CATCHUP_FRAMES`] before the clock is re-based.
    fn tick(&mut self) {
        let now = Instant::now();
        if now < self.next_deadline {
            return;
        }
        let mut due = 0u32;
        while now >= self.next_deadline && due < MAX_CATCHUP_FRAMES {
            self.next_deadline += self.frame_duration;
            due += 1;
        }
        self.catch_up = now >= self.next_deadline;
        if self.catch_up {
            // Stalled for longer than the catch-up window (window drag, debug
            // breakpoint, suspend): drop the lost time instead of spiralling.
            self.next_deadline = now + self.frame_duration;
        }

        for _ in 0..due {
            if self.auto_input {
                self.game.set_pad1(self.script.at(self.frame));
            }
            self.game.run_frame();
            self.frame = self.frame.wrapping_add(1);
        }

        // Audio: hand the samples produced by those frames to the device,
        // and to the recorder if one is active.
        let samples = self.game.take_audio();
        if let Some(a) = &self.audio {
            a.push(&samples);
        }
        if let Some(r) = self.recorder.as_mut() {
            r.push(&samples);
        }

        self.present();
        self.stats_frames += due;
        self.stats_rendered += 1;
        if self.stats && self.stats_since.elapsed() >= Duration::from_secs(1) {
            let secs = self.stats_since.elapsed().as_secs_f64();
            let fps = self.stats_frames as f64 / secs;
            eprintln!(
                "game frame {:>7}: {fps:6.2} fps (target {:.2}), queue {:>5} samples{}",
                self.frame,
                self.fps,
                self.audio.as_ref().map(|a| a.queued()).unwrap_or(0),
                if self.catch_up { ", catching up" } else { "" }
            );
            self.stats_frames = 0;
            self.stats_rendered = 0;
            self.stats_since = Instant::now();
        }
    }

    fn set_button(&mut self, key: KeyCode, pressed: bool) {
        let bit = match key {
            KeyCode::ArrowUp | KeyCode::KeyW => button::UP,
            KeyCode::ArrowDown | KeyCode::KeyS => button::DOWN,
            KeyCode::ArrowLeft | KeyCode::KeyA => button::LEFT,
            KeyCode::ArrowRight | KeyCode::KeyD => button::RIGHT,
            KeyCode::KeyZ | KeyCode::KeyK | KeyCode::Space => button::A,
            KeyCode::KeyX | KeyCode::KeyJ => button::B,
            KeyCode::Enter => button::START,
            KeyCode::ShiftRight | KeyCode::ShiftLeft | KeyCode::Tab => button::SELECT,
            _ => return,
        };
        let mut pad = self.game.machine.pad1;
        if pressed {
            pad |= bit;
        } else {
            pad &= !bit;
        }
        self.game.set_pad1(pad);
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }
        let attrs = Window::default_attributes()
            .with_title("Mappy — recompiled from 6502 to Rust")
            .with_inner_size(winit::dpi::LogicalSize::new(
                (NES_W * self.scale) as u32,
                (NES_H * self.scale) as u32,
            ));
        let window = Arc::new(event_loop.create_window(attrs).expect("create window"));
        self.set_window(window);
        self.next_deadline = Instant::now();
        self.stats_since = Instant::now();
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::Resized(_) => self.present(),
            WindowEvent::RedrawRequested => self.present(),
            WindowEvent::KeyboardInput { event, .. } => {
                if let PhysicalKey::Code(code) = event.physical_key {
                    if code == KeyCode::Escape && event.state == ElementState::Pressed {
                        event_loop.exit();
                        return;
                    }
                    self.set_button(code, event.state == ElementState::Pressed);
                }
            }
            _ => {}
        }
    }

    fn about_to_wait(&mut self, event_loop: &ActiveEventLoop) {
        // Run any frames that are due, then sleep until the next deadline.
        self.tick();
        event_loop.set_control_flow(ControlFlow::WaitUntil(self.next_deadline));
    }
}

// ---------------------------------------------------------------------------
// WAV recording (`--record`).
// ---------------------------------------------------------------------------

/// Writes exactly what is sent to the audio device, as 16-bit mono PCM.
/// The header is patched on drop, so a normal window close always leaves a
/// playable file.
struct Recorder {
    file: File,
    samples: u32,
    rate: u32,
    /// Samples written since the header was last checkpointed.
    since_checkpoint: u32,
}

impl Recorder {
    fn create(path: &str, rate: u32) -> std::io::Result<Recorder> {
        let mut file = File::create(path)?;
        write_wav_header(&mut file, rate, 0)?;
        Ok(Recorder { file, samples: 0, rate, since_checkpoint: 0 })
    }

    fn push(&mut self, samples: &[f32]) {
        let mut buf = Vec::with_capacity(samples.len() * 2);
        for s in samples {
            let v = (s.clamp(-1.0, 1.0) * 32767.0) as i16;
            buf.extend_from_slice(&v.to_le_bytes());
        }
        if self.file.write_all(&buf).is_ok() {
            self.samples += samples.len() as u32;
            self.since_checkpoint += samples.len() as u32;
            // Checkpoint the header about once a second, so the file stays
            // playable even if the process is killed rather than closed.
            if self.since_checkpoint >= self.rate {
                self.since_checkpoint = 0;
                self.finish();
            }
        }
    }

    fn finish(&mut self) {
        if self.file.seek(SeekFrom::Start(0)).is_ok() {
            let _ = write_wav_header(&mut self.file, self.rate, self.samples * 2);
            let _ = self.file.flush();
            // Back to the end so the next push appends.
            let _ = self.file.seek(SeekFrom::End(0));
        }
    }
}

impl Drop for Recorder {
    fn drop(&mut self) {
        self.finish();
    }
}

fn write_wav_header(file: &mut File, rate: u32, data_len: u32) -> std::io::Result<()> {
    let mut h = Vec::with_capacity(44);
    h.extend_from_slice(b"RIFF");
    h.extend_from_slice(&(36 + data_len).to_le_bytes());
    h.extend_from_slice(b"WAVEfmt ");
    h.extend_from_slice(&16u32.to_le_bytes());
    h.extend_from_slice(&1u16.to_le_bytes());
    h.extend_from_slice(&1u16.to_le_bytes());
    h.extend_from_slice(&rate.to_le_bytes());
    h.extend_from_slice(&(rate * 2).to_le_bytes());
    h.extend_from_slice(&2u16.to_le_bytes());
    h.extend_from_slice(&16u16.to_le_bytes());
    h.extend_from_slice(b"data");
    h.extend_from_slice(&data_len.to_le_bytes());
    file.write_all(&h)
}

// ---------------------------------------------------------------------------
// Audio output.
// ---------------------------------------------------------------------------

#[cfg(feature = "audio")]
struct AudioOut {
    queue: Arc<Mutex<VecDeque<f32>>>,
    sample_rate: u32,
    channels: u16,
    format: &'static str,
    _stream: cpal::Stream,
}

#[cfg(feature = "audio")]
impl AudioOut {
    fn new() -> Option<AudioOut> {
        use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
        let host = cpal::default_host();
        let device = host.default_output_device()?;
        let supported = device.default_output_config().ok()?;
        let sample_format = supported.sample_format();
        let config: cpal::StreamConfig = supported.into();
        let sample_rate = config.sample_rate.0;
        let channels = config.channels;
        let queue: Arc<Mutex<VecDeque<f32>>> = Arc::new(Mutex::new(VecDeque::new()));
        let q = queue.clone();
        let ch = channels as usize;
        let err_fn = |e| eprintln!("audio error: {e}");
        let stream = match sample_format {
            cpal::SampleFormat::F32 => device
                .build_output_stream(
                    &config,
                    move |data: &mut [f32], _| {
                        let Ok(mut queue) = q.try_lock() else { return };
                        for frame in data.chunks_mut(ch) {
                            let s = queue.pop_front().unwrap_or(0.0);
                            for out in frame.iter_mut() {
                                *out = s;
                            }
                        }
                    },
                    err_fn,
                    None,
                )
                .ok()?,
            cpal::SampleFormat::I16 => device
                .build_output_stream(
                    &config,
                    move |data: &mut [i16], _| {
                        let Ok(mut queue) = q.try_lock() else { return };
                        for frame in data.chunks_mut(ch) {
                            let s = queue.pop_front().unwrap_or(0.0);
                            let v = (s.clamp(-1.0, 1.0) * 32767.0) as i16;
                            for out in frame.iter_mut() {
                                *out = v;
                            }
                        }
                    },
                    err_fn,
                    None,
                )
                .ok()?,
            cpal::SampleFormat::U16 => device
                .build_output_stream(
                    &config,
                    move |data: &mut [u16], _| {
                        let Ok(mut queue) = q.try_lock() else { return };
                        for frame in data.chunks_mut(ch) {
                            let s = queue.pop_front().unwrap_or(0.0);
                            let v = ((s.clamp(-1.0, 1.0) * 0.5 + 0.5) * 65535.0) as u16;
                            for out in frame.iter_mut() {
                                *out = v;
                            }
                        }
                    },
                    err_fn,
                    None,
                )
                .ok()?,
            _ => return None,
        };
        stream.play().ok()?;
        Some(AudioOut {
            queue,
            sample_rate,
            channels,
            format: match sample_format {
                cpal::SampleFormat::F32 => "f32",
                cpal::SampleFormat::I16 => "i16",
                cpal::SampleFormat::U16 => "u16",
                _ => "?",
            },
            _stream: stream,
        })
    }

    fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    fn channels(&self) -> u16 {
        self.channels
    }

    fn sample_format(&self) -> &'static str {
        self.format
    }

    fn queued(&self) -> usize {
        self.queue.try_lock().map(|q| q.len()).unwrap_or(0)
    }

    fn push(&self, samples: &[f32]) {
        if samples.is_empty() {
            return;
        }
        // Never block the game loop on the audio callback: if the device is
        // not draining (suspended sink, stalled PipeWire/ALSA), drop this
        // batch instead of freezing the game. Game speed wins over sound.
        let Ok(mut q) = self.queue.try_lock() else {
            return;
        };
        // Never let the queue grow past ~0.5 s: a little buffering absorbs
        // scheduling jitter, more than that would just add latency.
        let limit = (self.sample_rate as usize) / 2;
        if q.len() > limit {
            let excess = q.len() - limit;
            q.drain(..excess);
        }
        q.extend(samples.iter().copied());
    }
}

/// Placeholder so the code compiles when audio is disabled.
#[cfg(not(feature = "audio"))]
struct AudioOut;

#[cfg(not(feature = "audio"))]
impl AudioOut {
    fn new() -> Option<AudioOut> {
        None
    }
    fn sample_rate(&self) -> u32 {
        nes::apu::SAMPLE_RATE as u32
    }
    fn channels(&self) -> u16 {
        1
    }
    fn sample_format(&self) -> &'static str {
        "none"
    }
    fn queued(&self) -> usize {
        0
    }
    fn push(&self, _samples: &[f32]) {}
}
