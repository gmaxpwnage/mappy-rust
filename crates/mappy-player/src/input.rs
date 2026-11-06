//! Scripted controller input, used by the headless and test modes.
//!
//! Syntax: comma-separated segments `BUTTONS@START-END` where `START`/`END`
//! are frame numbers (inclusive start, exclusive end) and `BUTTONS` is `+`
//! joined button names: `A`, `B`, `SELECT`, `START`, `UP`, `DOWN`, `LEFT`,
//! `RIGHT`, or `NONE`.
//!
//! Example: `START@300-310,RIGHT@420-700,RIGHT+UP@700-760`.

use nes::button;

pub struct InputScript {
    segments: Vec<(u32, u32, u8)>,
}

impl InputScript {
    pub fn parse(s: &str) -> Result<InputScript, String> {
        let mut segments = Vec::new();
        for raw in s.split(',') {
            let raw = raw.trim();
            if raw.is_empty() {
                continue;
            }
            let (buttons, range) = raw
                .split_once('@')
                .ok_or_else(|| format!("missing '@' in segment {raw:?}"))?;
            let (start, end) = range
                .split_once('-')
                .ok_or_else(|| format!("missing '-' in range {range:?}"))?;
            let start: u32 = start.trim().parse().map_err(|e| format!("{start:?}: {e}"))?;
            let end: u32 = end.trim().parse().map_err(|e| format!("{end:?}: {e}"))?;
            let mut bits = 0u8;
            for name in buttons.split('+') {
                let name = name.trim().to_ascii_uppercase();
                bits |= match name.as_str() {
                    "" | "NONE" => 0,
                    "A" => button::A,
                    "B" => button::B,
                    "SELECT" => button::SELECT,
                    "START" => button::START,
                    "UP" => button::UP,
                    "DOWN" => button::DOWN,
                    "LEFT" => button::LEFT,
                    "RIGHT" => button::RIGHT,
                    other => return Err(format!("unknown button {other:?}")),
                };
            }
            segments.push((start, end, bits));
        }
        Ok(InputScript { segments })
    }

    pub fn at(&self, frame: u32) -> u8 {
        let mut bits = 0;
        for &(start, end, b) in &self.segments {
            if frame >= start && frame < end {
                bits |= b;
            }
        }
        bits
    }
}

impl Default for InputScript {
    fn default() -> Self {
        InputScript { segments: Vec::new() }
    }
}
