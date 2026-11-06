//! The 2A03 audio processing unit.
//!
//! Two pulse channels (with envelopes and sweep units), triangle, noise and
//! DMC, mixed with the console's non-linear output curve.
//!
//! Timing follows the RP2A03 data sheet / NESdev reference:
//!
//! * the pulse timers count in **APU cycles** (half the CPU clock), so a pulse
//!   period of `t` gives the tone frequency `CPU / (16 * (t + 1))`;
//! * the triangle timer counts in CPU cycles: `CPU / (32 * (t + 1))`;
//! * the noise period table is already in CPU cycles, so the shift register is
//!   clocked at `CPU / period`;
//! * the DMC timer runs at the CPU clock;
//! * the frame sequencer is a 240 Hz (7457 CPU cycle) four-step machine.

/// Tone frequency of a pulse channel for timer period `t`.
#[inline]
pub fn pulse_frequency(t: u16) -> f64 {
    CPU_HZ / (16.0 * (t as f64 + 1.0))
}

/// Tone frequency of the triangle channel for timer period `t`.
#[inline]
pub fn triangle_frequency(t: u16) -> f64 {
    CPU_HZ / (32.0 * (t as f64 + 1.0))
}

/// LFSR clock rate of the noise channel for a period-table entry `p`, which
/// is expressed in CPU cycles (APU_Noise, "Noise mode and period").
#[inline]
pub fn noise_frequency(p: u16) -> f64 {
    CPU_HZ / (p.max(1) as f64)
}

use crate::cart::Cart;

const CPU_HZ: f64 = 1_789_773.0;
pub const SAMPLE_RATE: f64 = 44_100.0;

const LENGTH_TABLE: [u8; 32] = [
    10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14, 12, 16, 24, 18, 48, 20, 96, 22,
    192, 24, 72, 26, 16, 28, 32, 30,
];

// Duty cycle output waveforms (APU_Pulse, "Duty Cycle Sequences"):
// 12.5%, 25%, 50%, and the "25% negated" 75% pattern.
const DUTY_TABLE: [[u8; 8]; 4] = [
    [0, 1, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 0, 0, 0],
    [1, 0, 0, 1, 1, 1, 1, 1],
];

const TRIANGLE_TABLE: [u8; 32] = [
    15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    12, 13, 14, 15,
];

const NOISE_PERIODS: [u16; 16] = [
    4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068,
];

#[derive(Default)]
struct Envelope {
    start: bool,
    loop_loop: bool,
    constant: bool,
    volume: u8,
    divider: u8,
    decay: u8,
}

impl Envelope {
    fn clock(&mut self) {
        if self.start {
            self.start = false;
            self.decay = 15;
            self.divider = self.volume;
        } else if self.divider == 0 {
            self.divider = self.volume;
            if self.decay > 0 {
                self.decay -= 1;
            } else if self.loop_loop {
                self.decay = 15;
            }
        } else {
            self.divider -= 1;
        }
    }

    fn output(&self) -> u8 {
        if self.constant {
            self.volume
        } else {
            self.decay
        }
    }
}

/// The sweep unit shared by both pulse channels.
#[derive(Default)]
struct Sweep {
    enabled: bool,
    period: u8,
    negate: bool,
    shift: u8,
    divider: u8,
    reload: bool,
}

impl Sweep {
    /// Signed change the sweep applies to `period`.
    ///
    /// The two adders' carry inputs are wired differently: pulse 1 negates
    /// with the ones' complement (one more than the plain negation), pulse 2
    /// with the two's complement.
    fn delta(&self, period: u16, negate_extra: bool) -> i32 {
        let d = (period >> self.shift) as i32;
        if self.negate {
            -d - if negate_extra { 1 } else { 0 }
        } else {
            d
        }
    }

    fn target(&self, period: u16, negate_extra: bool) -> i32 {
        period as i32 + self.delta(period, negate_extra)
    }

    /// A pulse is silenced when its period is under 8 or the sweep would push
    /// the target period past $7FF. This muting applies whether or not the
    /// sweep unit is enabled.
    fn muted(&self, period: u16, negate_extra: bool) -> bool {
        period < 8 || self.target(period, negate_extra) > 0x7FF
    }

    /// Half-frame clock.
    fn clock(&mut self, period: &mut u16, negate_extra: bool) {
        if self.divider == 0
            && self.enabled
            && self.shift > 0
            && !self.muted(*period, negate_extra)
        {
            *period = self.target(*period, negate_extra).clamp(0, 0x7FF) as u16;
        }
        if self.divider == 0 || self.reload {
            self.divider = self.period;
            self.reload = false;
        } else {
            self.divider -= 1;
        }
    }
}

#[derive(Default)]
struct Pulse {
    enabled: bool,
    duty: u8,
    seq: u8,
    timer: u16,
    timer_period: u16,
    length: u8,
    length_halt: bool,
    envelope: Envelope,
    sweep: Sweep,
}

impl Pulse {
    /// One APU cycle: the pulse timer counts in APU cycles (CPU cycles / 2).
    fn clock_timer(&mut self) {
        if self.timer == 0 {
            self.timer = self.timer_period;
            self.seq = (self.seq + 1) & 7;
        } else {
            self.timer -= 1;
        }
    }

    fn output(&self, negate_extra: bool) -> u8 {
        if !self.enabled || self.length == 0 || self.sweep.muted(self.timer_period, negate_extra) {
            return 0;
        }
        if DUTY_TABLE[self.duty as usize][self.seq as usize] == 0 {
            0
        } else {
            self.envelope.output()
        }
    }
}

#[derive(Default)]
struct Triangle {
    enabled: bool,
    control: bool,
    timer: u16,
    timer_period: u16,
    length: u8,
    seq: u8,
    linear_reload: bool,
    linear_counter: u8,
    linear_reload_value: u8,
}

impl Triangle {
    /// One CPU cycle: the triangle timer counts in CPU cycles, unlike pulses.
    fn clock_timer(&mut self) {
        if self.timer == 0 {
            self.timer = self.timer_period;
            if self.length > 0 && self.linear_counter > 0 {
                self.seq = (self.seq + 1) & 31;
            }
        } else {
            self.timer -= 1;
        }
    }

    fn output(&self) -> u8 {
        if !self.enabled || self.timer_period < 2 {
            return 0;
        }
        TRIANGLE_TABLE[self.seq as usize]
    }

    fn clock_linear(&mut self) {
        if self.linear_reload {
            self.linear_counter = self.linear_reload_value;
        } else if self.linear_counter > 0 {
            self.linear_counter -= 1;
        }
        if !self.control {
            self.linear_reload = false;
        }
    }
}

#[derive(Default)]
struct Noise {
    enabled: bool,
    mode: bool,
    timer: u16,
    timer_period: u16,
    /// Shift-register clocks since power-on (diagnostics and tests).
    clocks: u64,
    shift: u16,
    length: u8,
    length_halt: bool,
    envelope: Envelope,
}

impl Noise {
    fn new() -> Noise {
        Noise { shift: 1, ..Default::default() }
    }

    /// One CPU cycle. The period-table value is a count of CPU cycles, so the
    /// shift register is clocked every `timer_period` cycles.
    fn clock_timer(&mut self) {
        if self.timer <= 1 {
            self.timer = self.timer_period;
            self.clocks += 1;
            let feedback = if self.mode {
                ((self.shift >> 0) & 1) ^ ((self.shift >> 6) & 1)
            } else {
                ((self.shift >> 0) & 1) ^ ((self.shift >> 1) & 1)
            };
            self.shift = (self.shift >> 1) | (feedback << 14);
        } else {
            self.timer -= 1;
        }
    }

    fn output(&self) -> u8 {
        if !self.enabled || self.length == 0 || self.shift & 1 != 0 {
            return 0;
        }
        self.envelope.output()
    }
}

#[derive(Default)]
struct Dmc {
    enabled: bool,
    irq_enabled: bool,
    loop_: bool,
    rate_index: u8,
    timer: u16,
    timer_period: u16,
    sample_addr: u16,
    sample_len: u16,
    cur_addr: u16,
    bytes_remaining: u16,
    shift: u8,
    bits_remaining: u8,
    output: u8,
    silence: bool,
    buffer: Option<u8>,
    irq_flag: bool,
}

const DMC_RATES: [u16; 16] = [
    428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54,
];

impl Dmc {
    fn restart(&mut self) {
        self.cur_addr = self.sample_addr;
        self.bytes_remaining = self.sample_len;
    }

    fn clock_timer(&mut self, cart: &Cart) {
        if self.timer == 0 {
            self.timer = self.timer_period;
            if !self.silence {
                if self.shift & 1 != 0 {
                    if self.output <= 125 {
                        self.output += 2;
                    }
                } else if self.output >= 2 {
                    self.output -= 2;
                }
            }
            self.shift >>= 1;
            if self.bits_remaining == 0 {
                self.bits_remaining = 8;
                match self.buffer.take() {
                    Some(b) => {
                        self.silence = false;
                        self.shift = b;
                    }
                    None => {
                        self.silence = true;
                        self.shift = 0;
                    }
                }
            }
            self.bits_remaining -= 1;
        } else {
            self.timer -= 1;
        }
        if self.buffer.is_none() && self.bytes_remaining > 0 && self.enabled {
            let addr = 0xC000 | (self.cur_addr & 0x3FFF);
            self.buffer = Some(cart.read_prg(addr));
            self.cur_addr = self.cur_addr.wrapping_add(1);
            if self.cur_addr == 0 {
                self.cur_addr = 0x8000;
            }
            self.bytes_remaining -= 1;
            if self.bytes_remaining == 0 {
                if self.loop_ {
                    self.restart();
                } else if self.irq_enabled {
                    self.irq_flag = true;
                }
            }
        }
    }
}

/// Observable state of one APU channel, for tests and the `apu` debug command.
#[derive(Clone, Copy, Debug, Default)]
pub struct ChannelState {
    pub enabled: bool,
    pub length: u8,
    /// Timer period in CPU cycles per sequencer step (the raw register value
    /// for pulses/triangle, the period-table entry for noise).
    pub period: u16,
    /// Resulting tone frequency in Hz.
    pub frequency: f64,
    pub duty: u8,
    /// Envelope volume (0-15).
    pub volume: u8,
    /// Current output level (0-15, or 0-127 for the DMC).
    pub output: u8,
    /// Triangle linear counter (0 for the other channels).
    pub linear: u8,
    /// Length counter halt flag.
    pub halt: bool,
}

#[derive(Clone, Copy, Debug, Default)]
pub struct ApuSnapshot {
    pub pulse1: ChannelState,
    pub pulse2: ChannelState,
    pub triangle: ChannelState,
    pub noise: ChannelState,
    pub dmc_output: u8,
    /// Shift-register clocks of the noise channel since power-on.
    pub noise_clocks: u64,
    /// Frame sequencer clocks since power-on.
    pub quarter_clocks: u64,
    pub half_clocks: u64,
    pub frame_irq: bool,
}

pub struct Apu {
    pulse1: Pulse,
    pulse2: Pulse,
    triangle: Triangle,
    noise: Noise,
    dmc: Dmc,
    /// Toggles every CPU cycle; true on the APU (CPU / 2) tick.
    apu_phase: bool,
    /// 0 = 4-step (~240 Hz), 1 = 5-step (~192 Hz).
    five_step: bool,
    frame_irq_inhibit: bool,
    frame_irq: bool,
    frame_cycle: u64,
    /// Frame-sequencer clocks since power-on (diagnostics and tests).
    quarter_clocks: u64,
    half_clocks: u64,

    /// Resampling state: fractional position of the next output sample.
    sample_accum: f64,
    /// CPU cycles accumulated in the current sample period (for averaging).
    sample_count: u32,
    /// Channel sums accumulated over the current output sample period.
    acc_pulse: u32,
    acc_triangle: u32,
    acc_noise: u32,
    acc_dmc: u32,
    /// One-pole DC blocker state (the mixer's output is unipolar; sound
    /// hardware is AC-coupled, so remove the bias here too).
    dc_x: f32,
    dc_y: f32,
    /// Output sample rate in Hz. The frontend sets this to whatever the audio
    /// device wants; headless tools keep the default.
    sample_rate: f64,
    pub samples: Vec<f32>,
    /// Number of writes to each APU register ($4000-$4017), for diagnostics.
    pub write_count: [u32; 0x18],
    /// Recent register writes (address, value), for diagnostics.
    pub write_log: Vec<(u16, u8)>,
}

impl Default for Apu {
    fn default() -> Self {
        Apu::new()
    }
}

impl Apu {
    pub fn new() -> Apu {
        Apu {
            pulse1: Pulse::default(),
            pulse2: Pulse::default(),
            triangle: Triangle::default(),
            noise: Noise::new(),
            dmc: Dmc::default(),
            apu_phase: false,
            five_step: false,
            frame_irq_inhibit: false,
            frame_irq: false,
            frame_cycle: 0,
            quarter_clocks: 0,
            half_clocks: 0,
            sample_accum: 0.0,
            sample_count: 0,
            acc_pulse: 0,
            acc_triangle: 0,
            acc_noise: 0,
            acc_dmc: 0,
            dc_x: 0.0,
            dc_y: 0.0,
            sample_rate: SAMPLE_RATE,
            samples: Vec::with_capacity(4096),
            write_count: [0; 0x18],
            write_log: Vec::new(),
        }
    }

    /// Set the output sample rate (Hz). Must be called before running.
    pub fn set_sample_rate(&mut self, hz: f64) {
        if hz > 1000.0 {
            self.sample_rate = hz;
        }
    }

    pub fn sample_rate(&self) -> f64 {
        self.sample_rate
    }

    pub fn write_register(&mut self, addr: u16, val: u8) {
        if (0x4000..0x4018).contains(&addr) {
            self.write_count[(addr - 0x4000) as usize] += 1;
            if self.write_log.len() < 200_000 {
                self.write_log.push((addr, val));
            }
        }
        match addr {
            0x4000 => {
                self.pulse1.duty = val >> 6;
                self.pulse1.length_halt = val & 0x20 != 0;
                self.pulse1.envelope.loop_loop = val & 0x20 != 0;
                self.pulse1.envelope.constant = val & 0x10 != 0;
                self.pulse1.envelope.volume = val & 0x0F;
            }
            0x4001 => {
                self.pulse1.sweep.enabled = val & 0x80 != 0;
                self.pulse1.sweep.period = (val >> 4) & 0x07;
                self.pulse1.sweep.negate = val & 0x08 != 0;
                self.pulse1.sweep.shift = val & 0x07;
                self.pulse1.sweep.reload = true;
            }
            0x4002 => {
                self.pulse1.timer_period = (self.pulse1.timer_period & 0x700) | val as u16;
            }
            0x4003 => {
                self.pulse1.timer_period =
                    (self.pulse1.timer_period & 0x0FF) | (((val as u16) & 0x07) << 8);
                if self.pulse1.enabled {
                    self.pulse1.length = LENGTH_TABLE[(val >> 3) as usize];
                }
                self.pulse1.seq = 0;
                self.pulse1.envelope.start = true;
            }
            0x4004 => {
                self.pulse2.duty = val >> 6;
                self.pulse2.length_halt = val & 0x20 != 0;
                self.pulse2.envelope.loop_loop = val & 0x20 != 0;
                self.pulse2.envelope.constant = val & 0x10 != 0;
                self.pulse2.envelope.volume = val & 0x0F;
            }
            0x4005 => {
                self.pulse2.sweep.enabled = val & 0x80 != 0;
                self.pulse2.sweep.period = (val >> 4) & 0x07;
                self.pulse2.sweep.negate = val & 0x08 != 0;
                self.pulse2.sweep.shift = val & 0x07;
                self.pulse2.sweep.reload = true;
            }
            0x4006 => {
                self.pulse2.timer_period = (self.pulse2.timer_period & 0x700) | val as u16;
            }
            0x4007 => {
                self.pulse2.timer_period =
                    (self.pulse2.timer_period & 0x0FF) | (((val as u16) & 0x07) << 8);
                if self.pulse2.enabled {
                    self.pulse2.length = LENGTH_TABLE[(val >> 3) as usize];
                }
                self.pulse2.seq = 0;
                self.pulse2.envelope.start = true;
            }
            0x4008 => {
                self.triangle.control = val & 0x80 != 0;
                self.triangle.linear_reload_value = val & 0x7F;
            }
            0x400A => {
                self.triangle.timer_period = (self.triangle.timer_period & 0x700) | val as u16;
            }
            0x400B => {
                self.triangle.timer_period =
                    (self.triangle.timer_period & 0x0FF) | (((val as u16) & 0x07) << 8);
                if self.triangle.enabled {
                    self.triangle.length = LENGTH_TABLE[(val >> 3) as usize];
                }
                self.triangle.linear_reload = true;
            }
            0x400C => {
                self.noise.length_halt = val & 0x20 != 0;
                self.noise.envelope.loop_loop = val & 0x20 != 0;
                self.noise.envelope.constant = val & 0x10 != 0;
                self.noise.envelope.volume = val & 0x0F;
            }
            0x400E => {
                self.noise.mode = val & 0x80 != 0;
                self.noise.timer_period = NOISE_PERIODS[(val & 0x0F) as usize];
            }
            0x400F => {
                if self.noise.enabled {
                    self.noise.length = LENGTH_TABLE[(val >> 3) as usize];
                }
                self.noise.envelope.start = true;
            }
            0x4010 => {
                self.dmc.irq_enabled = val & 0x80 != 0;
                self.dmc.loop_ = val & 0x40 != 0;
                self.dmc.rate_index = val & 0x0F;
                self.dmc.timer_period = DMC_RATES[(val & 0x0F) as usize];
                if !self.dmc.irq_enabled {
                    self.dmc.irq_flag = false;
                }
            }
            0x4011 => self.dmc.output = val & 0x7F,
            0x4012 => {
                self.dmc.sample_addr = 0xC000 | ((val as u16) << 6);
            }
            0x4013 => {
                self.dmc.sample_len = ((val as u16) << 4) | 1;
            }
            0x4015 => {
                self.pulse1.enabled = val & 0x01 != 0;
                self.pulse2.enabled = val & 0x02 != 0;
                self.triangle.enabled = val & 0x04 != 0;
                self.noise.enabled = val & 0x08 != 0;
                self.dmc.enabled = val & 0x10 != 0;
                if !self.pulse1.enabled {
                    self.pulse1.length = 0;
                }
                if !self.pulse2.enabled {
                    self.pulse2.length = 0;
                }
                if !self.triangle.enabled {
                    self.triangle.length = 0;
                }
                if !self.noise.enabled {
                    self.noise.length = 0;
                }
                if !self.dmc.enabled {
                    self.dmc.bytes_remaining = 0;
                } else if self.dmc.bytes_remaining == 0 {
                    self.dmc.restart();
                }
                self.dmc.irq_flag = false;
            }
            0x4017 => {
                self.five_step = val & 0x80 != 0;
                self.frame_irq_inhibit = val & 0x40 != 0;
                if self.frame_irq_inhibit {
                    self.frame_irq = false;
                }
                // Writing $4017 immediately clocks the sequencer and resets it.
                self.clock_quarter();
                self.clock_half();
                self.frame_cycle = 0;
            }
            _ => {}
        }
    }

    /// Snapshot every channel's musical state (used by tests and `mappy apu`).
    pub fn snapshot(&self) -> ApuSnapshot {
        let pulse = |p: &Pulse, negate_extra: bool| ChannelState {
            enabled: p.enabled,
            length: p.length,
            period: p.timer_period,
            frequency: pulse_frequency(p.timer_period),
            duty: p.duty,
            volume: p.envelope.output(),
            output: p.output(negate_extra),
            linear: 0,
            halt: p.length_halt,
        };
        ApuSnapshot {
            pulse1: pulse(&self.pulse1, true),
            pulse2: pulse(&self.pulse2, false),
            triangle: ChannelState {
                enabled: self.triangle.enabled,
                length: self.triangle.length,
                period: self.triangle.timer_period,
                frequency: triangle_frequency(self.triangle.timer_period),
                duty: 0,
                volume: if self.triangle.length > 0 && self.triangle.linear_counter > 0 { 15 } else { 0 },
                output: self.triangle.output(),
                linear: self.triangle.linear_counter,
                halt: self.triangle.control,
            },
            noise: ChannelState {
                enabled: self.noise.enabled,
                length: self.noise.length,
                period: self.noise.timer_period,
                frequency: noise_frequency(self.noise.timer_period),
                duty: 0,
                volume: self.noise.envelope.output(),
                output: self.noise.output(),
                linear: 0,
                halt: self.noise.length_halt,
            },
            dmc_output: self.dmc.output,
            noise_clocks: self.noise.clocks,
            quarter_clocks: self.quarter_clocks,
            half_clocks: self.half_clocks,
            frame_irq: self.frame_irq,
        }
    }

    pub fn read_status(&mut self) -> u8 {
        let mut v = 0u8;
        if self.pulse1.length > 0 {
            v |= 0x01;
        }
        if self.pulse2.length > 0 {
            v |= 0x02;
        }
        if self.triangle.length > 0 {
            v |= 0x04;
        }
        if self.noise.length > 0 {
            v |= 0x08;
        }
        if self.dmc.bytes_remaining > 0 {
            v |= 0x10;
        }
        if self.frame_irq {
            v |= 0x40;
        }
        if self.dmc.irq_flag {
            v |= 0x80;
        }
        self.frame_irq = false;
        v
    }

    /// The APU's IRQ output line (frame counter or DMC).
    pub fn irq(&self) -> bool {
        self.frame_irq && !self.frame_irq_inhibit || self.dmc.irq_flag
    }

    fn clock_quarter(&mut self) {
        self.pulse1.envelope.clock();
        self.pulse2.envelope.clock();
        self.noise.envelope.clock();
        self.triangle.clock_linear();
    }

    fn clock_half(&mut self) {
        self.pulse1.sweep.clock(&mut self.pulse1.timer_period, true);
        self.pulse2.sweep.clock(&mut self.pulse2.timer_period, false);
        for p in [&mut self.pulse1, &mut self.pulse2] {
            if !p.length_halt && p.length > 0 {
                p.length -= 1;
            }
        }
        if !self.triangle.control && self.triangle.length > 0 {
            self.triangle.length -= 1;
        }
        if !self.noise.length_halt && self.noise.length > 0 {
            self.noise.length -= 1;
        }
    }

    /// Advance the APU by one CPU cycle.
    pub fn tick(&mut self, cart: &Cart) {
        // Pulse timers are clocked at the APU rate (CPU / 2); the triangle,
        // noise and DMC timers are clocked at the CPU rate.
        self.apu_phase = !self.apu_phase;
        if self.apu_phase {
            self.pulse1.clock_timer();
            self.pulse2.clock_timer();
        }
        self.triangle.clock_timer();
        self.noise.clock_timer();
        self.dmc.clock_timer(cart);

        // Frame sequencer.
        //
        // The step boundaries below are the *cumulative* cycle counts of the
        // frame counter (APU_Frame_Counter): 7457 / 14913 / 22371 / 29829 for
        // the four-step mode, plus 37281 for the five-step mode, wrapping at
        // the end of the sequence. Treating them as per-step delays would run
        // every envelope, length and linear counter far too slowly.
        self.frame_cycle += 1;
        // Step boundaries in CPU cycles (APU_Frame_Counter, APU cycles x 2):
        //   mode 0: 7456 / 14912 / 22370 / 29828, wrapping after 29830
        //   mode 1: 7456 / 14912 / 22370 / 37280, wrapping after 37282
        // Every step except mode 1's fourth clocks the quarter frame; the
        // second and last steps also clock the half frame. Missing the step-2
        // quarter clock makes envelopes and the triangle's linear counter
        // decay 25% too slowly.
        let (quarter, half, irq) = match (self.five_step, self.frame_cycle) {
            (false, 7456) => (true, false, false),
            (false, 14912) => (true, true, false),
            (false, 22370) => (true, false, false),
            (false, 29828) => (true, true, true),
            (true, 7456) => (true, false, false),
            (true, 14912) => (true, true, false),
            (true, 22370) => (true, false, false),
            (true, 37280) => (true, true, false),
            _ => (false, false, false),
        };
        if quarter || half {
            if quarter {
                self.quarter_clocks += 1;
                self.clock_quarter();
            }
            if half {
                self.half_clocks += 1;
                self.clock_half();
            }
            if irq && !self.frame_irq_inhibit {
                self.frame_irq = true;
            }
        }
        let step = if self.five_step { 37282 } else { 29830 };
        if self.frame_cycle >= step {
            self.frame_cycle = 0;
        }

        // Resampling: accumulate channel outputs over one sample period.
        // Pulse 1 is the channel with the ones'-complement sweep adder.
        self.acc_pulse += self.pulse1.output(true) as u32 + self.pulse2.output(false) as u32;
        self.acc_triangle += self.triangle.output() as u32;
        self.acc_noise += self.noise.output() as u32;
        self.acc_dmc += self.dmc.output as u32;
        self.sample_count += 1;
        // Fractional accumulator: exactly `sample_rate` samples per second of
        // CPU time on average, with no integer-rounding drift.
        self.sample_accum += self.sample_rate / CPU_HZ;
        if self.sample_accum >= 1.0 {
            self.sample_accum -= 1.0;
            let n = self.sample_count as f32;
            let pulse = self.acc_pulse as f32 / n;
            let triangle = self.acc_triangle as f32 / n;
            let noise = self.acc_noise as f32 / n;
            let dmc = self.acc_dmc as f32 / n;
            // The 2A03's non-linear mixer.
            let pulse_out = if pulse > 0.0 {
                95.88 / (8128.0 / pulse + 100.0)
            } else {
                0.0
            };
            let tnd = triangle / 8227.0 + noise / 12241.0 + dmc / 22638.0;
            let tnd_out = if tnd > 0.0 {
                159.79 / (1.0 / tnd + 100.0)
            } else {
                0.0
            };
            let raw = pulse_out + tnd_out;
            // DC blocker: y[n] = x[n] - x[n-1] + 0.995 * y[n-1]
            let y = raw - self.dc_x + 0.995 * self.dc_y;
            self.dc_x = raw;
            self.dc_y = y;
            self.samples.push(y);
            self.acc_pulse = 0;
            self.acc_triangle = 0;
            self.acc_noise = 0;
            self.acc_dmc = 0;
            self.sample_count = 0;
        }
    }

    pub fn run(&mut self, cart: &Cart, cycles: u32) {
        for _ in 0..cycles {
            self.tick(cart);
        }
    }

    /// Drain buffered audio samples (`-1.0..=1.0`).
    pub fn drain_samples(&mut self) -> Vec<f32> {
        std::mem::take(&mut self.samples)
    }
}

/// Convert an APU mixed sample to i16 PCM.
pub fn to_i16(s: f32) -> i16 {
    (s.clamp(-1.0, 1.0) * 32767.0) as i16
}

/// Exposed for tests: the mixing curve used above.
pub const _CPU_HZ: f64 = CPU_HZ;
