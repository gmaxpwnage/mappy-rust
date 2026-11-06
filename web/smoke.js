// Headless smoke test: instantiate the wasm build, run frames, check the
// framebuffer and the audio path. Run with: node web/smoke.js web/mappy.wasm
const fs = require('fs');

const file = process.argv[2] || 'web/mappy.wasm';
const bytes = fs.readFileSync(file);

WebAssembly.instantiate(bytes, {}).then(({ instance, module }) => {
  const e = instance.exports;
  const mem = e.memory;
  if (!mem) throw new Error('module does not export memory');
  const api = Object.keys(e).filter((k) => k.startsWith('mappy')).sort();
  console.log(`module ${(bytes.length / 1024 / 1024).toFixed(2)} MiB, exports: ${api.join(', ')}`);

  const rate = 48000;
  if (e.mappy_init(rate) !== 0) throw new Error('init failed');
  const w = e.mappy_width(), h = e.mappy_height();
  if (w !== 256 || h !== 240) throw new Error(`unexpected size ${w}x${h}`);

  // Run two seconds of game time.
  for (let i = 0; i < 120; i++) e.mappy_run_frame();
  if (e.mappy_frame_count() !== 120) throw new Error('frame counter wrong');

  // WebAssembly memory can grow (detaching JS views), so re-create the view
  // right before reading it.
  const ptr = e.mappy_rgb_ptr();
  const fb = new Uint8Array(e.memory.buffer, ptr, w * h * 4).slice();
  const colours = new Set();
  for (let i = 0; i < fb.length; i += 4) {
    colours.add((fb[i] << 16) | (fb[i + 1] << 8) | fb[i + 2]);
  }
  console.log(`framebuffer: ${colours.size} distinct colours, first pixel #${[...colours][0].toString(16).padStart(6, '0')}`);
  if (colours.size < 4) throw new Error('framebuffer looks blank');

  let samples = 0;
  for (let i = 0; i < 30; i++) e.mappy_run_frame();
  for (let i = 0; i < 100; i++) samples += e.mappy_take_audio(4096);
  const audioAge = samples / rate;
  console.log(`audio: ${samples} samples drained (${audioAge.toFixed(2)} s)`);
  if (samples < rate * 0.3) throw new Error('too little audio produced');

  const rgb = Buffer.alloc(w * h * 3);
  for (let i = 0, o = 0; i < fb.length; i += 4, o += 3) {
    rgb[o] = fb[i]; rgb[o + 1] = fb[i + 1]; rgb[o + 2] = fb[i + 2];
  }
  fs.writeFileSync('/tmp/wasm-frame.ppm', Buffer.concat([Buffer.from(`P6\n${w} ${h}\n255\n`), rgb]));
  console.log('wrote /tmp/wasm-frame.ppm');
  console.log('OK');
}).catch((err) => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
