//! Waveform-level tests: what the APU *sounds like* must match the RP2A03
//! specification, not just the register values it was handed.
//!
//! These tests measure the produced waveform (channel output transitions and
//! duty ratio) against the documented frequencies:
//!   pulse     f = CPU / (16 * (t + 1))
//!   triangle  f = CPU / (32 * (t + 1))
//! A timer clocked at the wrong rate (e.g. CPU instead of CPU / 2) would show
//! up here as an octave error even though every register write was correct.

use nes::apu::{pulse_frequency, triangle_frequency, Apu};
use nes::Cart;

fn cart() -> Cart {
    Cart::from_image(vec![0u8; 16384], vec![0u8; 8192])
}

/// Enable pulse 1 at a given duty and timer period, with a long length and a
/// non-decaying envelope at maximum volume.
fn setup_pulse(apu: &mut Apu, duty: u8, period: u16) {
    apu.write_register(0x4015, 0x01); // pulse 1 on
    apu.write_register(0x4000, (duty << 6) | 0x3F); // halt, constant volume 15
    apu.write_register(0x4001, 0x00); // sweep off
    apu.write_register(0x4002, (period & 0xFF) as u8);
    apu.write_register(0x4003, (((period >> 8) & 0x07) as u8) | 0x08); // long length
}

/// Count rising edges of the pulse output over `cycles` CPU cycles.
fn count_edges(apu: &mut Apu, cart: &Cart, cycles: u32) -> u32 {
    let mut edges = 0;
    let mut prev = apu.snapshot().pulse1.output != 0;
    for _ in 0..cycles {
        apu.run(cart, 1);
        let now = apu.snapshot().pulse1.output != 0;
        if now && !prev {
            edges += 1;
        }
        prev = now;
    }
    edges
}

#[test]
fn pulse_tone_matches_hardware_frequency() {
    let cart = cart();
    // A range of periods covering the game's melody register range.
    for period in [100u16, 253, 511, 700] {
        for duty in [2u8, 3] {
            let mut apu = Apu::new();
            setup_pulse(&mut apu, duty, period);
            let cycles = 447_443u32; // 0.25 s of CPU time
            let edges = count_edges(&mut apu, &cart, cycles);
            let measured = edges as f64 / (cycles as f64 / 1_789_773.0);
            let expected = pulse_frequency(period);
            let ratio = measured / expected;
            assert!(
                (ratio - 1.0).abs() < 0.02,
                "pulse period {period} produced {measured:.1} Hz, expected {expected:.1} Hz \
                 (ratio {ratio:.3}); an octave error means the timer is clocked at the wrong rate"
            );
        }
    }
}

#[test]
fn pulse_duty_matches_the_register() {
    let cart = cart();
    for (duty, expected) in [(0u8, 0.125), (1, 0.25), (2, 0.5), (3, 0.75)] {
        let mut apu = Apu::new();
        setup_pulse(&mut apu, duty, 200);
        let cycles = 400_000u32;
        let mut high = 0u64;
        for _ in 0..cycles {
            apu.run(&cart, 1);
            if apu.snapshot().pulse1.output != 0 {
                high += 1;
            }
        }
        let ratio = high as f64 / cycles as f64;
        assert!(
            (ratio - expected).abs() < 0.02,
            "duty {duty} was {:.3} high, expected {expected:.3}",
            ratio
        );
    }
}

#[test]
fn triangle_tone_matches_hardware_frequency() {
    let cart = cart();
    for period in [100u16, 300, 600] {
        let mut apu = Apu::new();
        apu.write_register(0x4015, 0x04); // triangle on
        apu.write_register(0x4008, 0x7F); // control set: linear counter held loaded
        apu.write_register(0x400A, (period & 0xFF) as u8);
        apu.write_register(0x400B, (((period >> 8) & 0x07) as u8) | 0x08);
        let cycles = 600_000u32;
        // The 32-step sequence visits every value once per cycle, so count
        // transitions and divide by 32.
        let mut transitions = 0u64;
        let mut prev = apu.snapshot().triangle.output;
        for _ in 0..cycles {
            apu.run(&cart, 1);
            let now = apu.snapshot().triangle.output;
            if now != prev {
                transitions += 1;
            }
            prev = now;
        }
        // The 32-step sequence repeats two peak values, so it produces 30
        // transitions per cycle.
        let measured = transitions as f64 / 30.0 / (cycles as f64 / 1_789_773.0);
        let expected = triangle_frequency(period);
        let ratio = measured / expected;
        assert!(
            (ratio - 1.0).abs() < 0.03,
            "triangle period {period} produced {measured:.1} Hz, expected {expected:.1} Hz"
        );
    }
}

#[test]
fn sweep_can_raise_the_period_and_mute_the_channel() {
    let mut apu = Apu::new();
    setup_pulse(&mut apu, 2, 0x100);
    apu.write_register(0x4001, 0x81); // sweep on, shift 1, add
    let before = apu.snapshot().pulse1.period;
    // Two half-frame clocks.
    apu.run(&cart(), 30_000);
    let after = apu.snapshot().pulse1.period;
    assert!(after > before, "sweep did not raise the period ({before} -> {after})");

    // A period whose sweep target would overflow $7FF must silence the
    // channel even when the sweep unit is disabled (here: 0x7F8 + 0xF).
    let mut apu = Apu::new();
    setup_pulse(&mut apu, 2, 0x7F8);
    apu.write_register(0x4001, 0x87); // sweep on, add, shift 7
    apu.run(&cart(), 1000);
    assert_eq!(apu.snapshot().pulse1.output, 0, "out-of-range sweep target must mute");
}

#[test]
fn noise_shift_register_clocks_at_the_table_rate() {
    let cart = cart();
    // $400E low nibble selects the period table entry, which is a count of
    // CPU cycles between shift-register clocks: clock rate = CPU / period.
    for (index, period) in [(0u8, 4u16), (1, 8), (4, 64), (0x0C, 762)] {
        let mut apu = Apu::new();
        apu.write_register(0x4015, 0x08); // noise on
        apu.write_register(0x400C, 0x3F); // halt, constant volume 15
        apu.write_register(0x400E, index);
        apu.write_register(0x400F, 0x08); // long length
        let cycles = 894_886u32; // 0.5 s
        apu.run(&cart, cycles);
        let clocks = apu.snapshot().noise_clocks as f64;
        let measured = clocks / (cycles as f64 / 1_789_773.0);
        let expected = 1_789_773.0 / period as f64;
        let ratio = measured / expected;
        assert!(
            (ratio - 1.0).abs() < 0.01,
            "noise index {index} clocked at {measured:.0} Hz, expected {expected:.0} Hz"
        );
    }
}

#[test]
fn frame_sequencer_runs_at_its_documented_rate() {
    let cart = cart();
    // Four-step mode: quarter-frame clocks at 7456, 14912, 22370 and 29828
    // cycles and half-frame clocks at 14912 and 29828, i.e. 4 and 2 per
    // 29830-cycle sequence (240 Hz and 120 Hz). One second is 60 sequences.
    let mut apu = Apu::new();
    apu.write_register(0x4017, 0x40); // four-step mode, frame IRQ inhibited
    apu.run(&cart, 1_789_773);
    let snap = apu.snapshot();
    let quarter = snap.quarter_clocks as f64;
    let half = snap.half_clocks as f64;
    let sequences = 1_789_773.0 / 29_830.0;
    assert!(
        (quarter - 4.0 * sequences).abs() < 6.0,
        "{quarter} quarter-frame clocks in one second, expected about {}",
        4.0 * sequences
    );
    assert!(
        (half - 2.0 * sequences).abs() < 6.0,
        "{half} half-frame clocks in one second, expected about {}",
        2.0 * sequences
    );
}

#[test]
fn envelope_decays_at_the_quarter_frame_rate() {
    let cart = cart();
    // Constant volume off, divider = 10: one decay step every 11 quarter-frame
    // clocks. The envelope has 15 steps, so it reaches zero after
    // 15 * 11 / 240 Hz = 0.6875 s. A sequencer clocked at 180 Hz (a missing
    // quarter-frame clock) would take 0.917 s, so the *duration* is what makes
    // this test meaningful - counting steps saturates at 15.
    let mut apu = Apu::new();
    apu.write_register(0x4000, 0x0A); // envelope mode, divider 10
    apu.write_register(0x4003, 0x08); // start the envelope
    // The envelope reads zero until the first quarter-frame clock loads it.
    let mut started_at = None;
    let mut zero_at = None;
    for i in 0..1_789_773u32 {
        apu.run(&cart, 1);
        let v = apu.snapshot().pulse1.volume;
        if started_at.is_none() && v == 15 {
            started_at = Some(i as f64 / 1_789_773.0);
        }
        if started_at.is_some() && zero_at.is_none() && v == 0 {
            zero_at = Some(i as f64 / 1_789_773.0 - started_at.unwrap());
        }
    }
    let t = zero_at.expect("envelope never reached zero");
    assert!(
        (0.66..0.72).contains(&t),
        "envelope reached zero after {t:.3}s, expected about 0.6875s          (a quarter-frame clock of 240 Hz)"
    );
}

#[test]
fn length_counter_counts_down_at_the_half_frame_rate() {
    let cart = cart();
    let mut apu = Apu::new();
    apu.write_register(0x4015, 0x01);
    apu.write_register(0x4000, 0x00); // halt flag clear so the length runs
    apu.write_register(0x4003, 0xF8); // length index 31 = 30
    let before = apu.snapshot().pulse1.length;
    apu.run(&cart, 447_443); // 0.25 s
    let after = apu.snapshot().pulse1.length;
    let dropped = before as i32 - after as i32;
    // Two half-frame clocks per frame, 60 frames/s, 0.25 s => about 30.
    assert!(
        (24..=32).contains(&dropped),
        "length counter dropped {dropped} in 0.25 s, expected about 30"
    );
}
