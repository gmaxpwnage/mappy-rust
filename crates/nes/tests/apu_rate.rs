//! The APU must produce audio at the configured rate, independent of anything
//! else: tempo and pitch follow the CPU clock, not the host's frame rate.

use nes::apu::{Apu, SAMPLE_RATE};
use nes::Cart;

fn cart() -> Cart {
    // A blank NROM image is enough: the APU only reads the cart for DMC samples.
    Cart::from_image(vec![0u8; 16384], vec![0u8; 8192])
}

#[test]
fn generates_samples_at_the_requested_rate() {
    let cart = cart();
    for rate in [44_100.0f64, 48_000.0, 96_000.0] {
        let mut apu = Apu::new();
        apu.set_sample_rate(rate);
        // One second of CPU time, fed in instruction-sized chunks.
        let mut remaining = 1_789_773u32;
        while remaining > 0 {
            let chunk = remaining.min(7);
            apu.run(&cart, chunk);
            remaining -= chunk;
        }
        let produced = apu.drain_samples().len() as f64;
        assert!(
            (produced - rate).abs() < rate * 0.005,
            "at {rate} Hz the APU produced {produced} samples for one second of CPU time \
             (expected about {rate})"
        );
    }
}

#[test]
fn default_rate_is_44_1_khz() {
    assert_eq!(Apu::new().sample_rate(), SAMPLE_RATE);
}

#[test]
fn one_frame_is_about_one_sixtieth_of_a_second_of_audio() {
    let cart = cart();
    let mut apu = Apu::new();
    // 29780.67 CPU cycles per NTSC frame.
    apu.run(&cart, 29_781);
    let produced = apu.drain_samples().len() as f64;
    let expected = SAMPLE_RATE / 60.0988;
    assert!(
        (produced - expected).abs() < 2.0,
        "a frame produced {produced} samples, expected about {expected}"
    );
}
