//! Native window, keyboard and sound frontend (winit + softbuffer + cpal).
//!
//! Cross-platform by construction: winit abstracts the window system, so the
//! same code runs on Linux (X11/Wayland), macOS, Windows and more. Audio is
//! optional at build time (`--no-default-features --features gui`).

use std::collections::VecDeque;
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

pub fn run(opts: &mut Opts) {
    let game = mappy_rom::Mappy::new();
    let script = crate::input::InputScript::parse(&opts.script).unwrap_or_default();
    let auto_input = !opts.script.is_empty();
    let audio: Option<AudioOut> = if opts.audio {
        AudioOut::new()
    } else {
        None
    };
    let mut app = App {
        game,
        scale: opts.scale.max(1) as usize,
        window: None,
        surface: None,
        context: None,
        audio,
        next_frame: Instant::now(),
        frames_due: 0.0f64,
        last_audio_drain: Instant::now(),
        script,
        auto_input,
        frame: 0,
    };
    let event_loop = EventLoop::new().expect("create event loop");
    event_loop.set_control_flow(ControlFlow::Poll);
    event_loop.run_app(&mut app).expect("run event loop");
}

struct App {
    game: mappy_rom::Mappy,
    scale: usize,
    window: Option<Arc<Window>>,
    surface: Option<softbuffer::Surface<Arc<Window>, Arc<Window>>>,
    context: Option<softbuffer::Context<Arc<Window>>>,
    audio: Option<AudioOut>,
    next_frame: Instant,
    frames_due: f64,
    last_audio_drain: Instant,
    /// Scripted input (see `--input`); when non-empty it drives player 1.
    script: crate::input::InputScript,
    auto_input: bool,
    frame: u32,
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

    /// Advance the game by the wall-clock time elapsed, at 60.0988 Hz.
    fn tick(&mut self) {
        let now = Instant::now();
        if now < self.next_frame {
            return;
        }
        let dt = now.duration_since(self.next_frame).as_secs_f64();
        self.frames_due = (self.frames_due + dt * 60.0988 + 1.0).min(3.0);
        self.next_frame = now;
        let whole = self.frames_due.floor();
        self.frames_due -= whole;
        for _ in 0..(whole as u32) {
            if self.auto_input {
                self.game.set_pad1(self.script.at(self.frame));
            }
            self.game.run_frame();
            self.frame = self.frame.wrapping_add(1);
        }
        // Audio: keep the output queue fed.
        let samples = self.game.take_audio();
        if let Some(a) = &self.audio {
            a.push(&samples);
        }
        self.last_audio_drain = now;
        self.present();
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
            .with_title("Mappy — decompiled to Rust")
            .with_inner_size(winit::dpi::LogicalSize::new(
                (NES_W * self.scale) as u32,
                (NES_H * self.scale) as u32,
            ));
        let window = Arc::new(event_loop.create_window(attrs).expect("create window"));
        self.set_window(window);
        self.next_frame = Instant::now();
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

    fn about_to_wait(&mut self, _event_loop: &ActiveEventLoop) {
        self.tick();
        if let Some(w) = &self.window {
            w.request_redraw();
        }
        // ~1 ms sleep keeps the loop from spinning a core while staying smooth.
        std::thread::sleep(Duration::from_millis(1));
    }
}

// ---------------------------------------------------------------------------
// Audio output.
// ---------------------------------------------------------------------------

#[cfg(feature = "audio")]
struct AudioOut {
    queue: Arc<Mutex<VecDeque<f32>>>,
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
        let queue: Arc<Mutex<VecDeque<f32>>> = Arc::new(Mutex::new(VecDeque::new()));
        let q = queue.clone();
        let err_fn = |e| eprintln!("audio error: {e}");
        let stream = match sample_format {
            cpal::SampleFormat::F32 => device
                .build_output_stream(
                    &config,
                    move |data: &mut [f32], _| fill_f32(data, &q),
                    err_fn,
                    None,
                )
                .ok()?,
            cpal::SampleFormat::I16 => device
                .build_output_stream(
                    &config,
                    move |data: &mut [i16], _| {
                        let mut out = vec![0.0f32; data.len()];
                        fill_f32(&mut out, &q);
                        for (d, s) in data.iter_mut().zip(out) {
                            *d = (s.clamp(-1.0, 1.0) * 32767.0) as i16;
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
                        let mut out = vec![0.0f32; data.len()];
                        fill_f32(&mut out, &q);
                        for (d, s) in data.iter_mut().zip(out) {
                            *d = ((s.clamp(-1.0, 1.0) * 0.5 + 0.5) * 65535.0) as u16;
                        }
                    },
                    err_fn,
                    None,
                )
                .ok()?,
            _ => return None,
        };
        stream.play().ok()?;
        Some(AudioOut { queue, _stream: stream })
    }

    fn push(&self, samples: &[f32]) {
        if samples.is_empty() {
            return;
        }
        let mut q = self.queue.lock().unwrap();
        // Drop the oldest audio rather than growing without bound.
        if q.len() > 44_100 {
            let excess = q.len() - 44_100;
            q.drain(..excess);
        }
        q.extend(samples.iter().copied());
    }
}

#[cfg(feature = "audio")]
fn fill_f32(data: &mut [f32], q: &Arc<Mutex<VecDeque<f32>>>) {
    let mut queue = q.lock().unwrap();
    for d in data.iter_mut() {
        *d = queue.pop_front().unwrap_or(0.0);
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
    fn push(&self, _samples: &[f32]) {}
}
