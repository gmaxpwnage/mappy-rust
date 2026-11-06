// Browser frontend for the decompiled game.
//
// The wasm module exposes a tiny C ABI (see crates/mappy-web/src/lib.rs), so
// this file is the whole "framework": it instantiates the module, paces the
// game to the console's 60.0988 fps, copies the framebuffer into a canvas and
// pumps the APU's samples into the Web Audio graph.

'use strict';

const WIDTH = 256;
const HEIGHT = 240;
const FPS = 60.0988;
const FRAME_MS = 1000 / FPS;
const MAX_CATCH_UP = 3;

// NES button bits, matching nes::button.
const BUTTONS = {
  a: 1,
  b: 2,
  select: 4,
  start: 8,
  up: 16,
  down: 32,
  left: 64,
  right: 128,
};

const params = new URLSearchParams(location.search);
const autostart = params.has('autostart'); // used by the screenshot test

const canvas = document.getElementById('screen');
const ctx = canvas.getContext('2d', { alpha: false });
const imageData = ctx.createImageData(WIDTH, HEIGHT);
const overlay = document.getElementById('overlay');
const startButton = document.getElementById('start');
const statusLine = document.getElementById('status');

let wasm = null;
let memory = null;
let running = false;
let padBits = 0;
let frames = 0;
let lastTime = 0;
let accumulator = 0;

// ---------------------------------------------------------------- audio ----

// Samples arrive in bursts of ~735 per video frame and are consumed 128 at a
// time by the audio callback, so they are queued here.
const audioQueue = { chunks: [], offset: 0, queued: 0 };
const MAX_QUEUED_SECONDS = 0.5;
let audioContext = null;
let sampleRate = 0;

function pushAudio(samples) {
  audioQueue.chunks.push(samples);
  audioQueue.queued += samples.length;
  const limit = Math.floor(sampleRate * MAX_QUEUED_SECONDS);
  while (audioQueue.queued > limit && audioQueue.chunks.length) {
    const head = audioQueue.chunks[0];
    const drop = Math.min(head.length - audioQueue.offset, audioQueue.queued - limit);
    audioQueue.offset += drop;
    audioQueue.queued -= drop;
    if (audioQueue.offset >= head.length) {
      audioQueue.chunks.shift();
      audioQueue.offset = 0;
    }
  }
}

function pullAudio(out) {
  let i = 0;
  while (i < out.length && audioQueue.chunks.length) {
    const head = audioQueue.chunks[0];
    const n = Math.min(head.length - audioQueue.offset, out.length - i);
    out.set(head.subarray(audioQueue.offset, audioQueue.offset + n), i);
    i += n;
    audioQueue.offset += n;
    audioQueue.queued -= n;
    if (audioQueue.offset >= head.length) {
      audioQueue.chunks.shift();
      audioQueue.offset = 0;
    }
  }
  for (; i < out.length; i++) out[i] = 0; // underrun: silence, never stall
}

function startAudio() {
  const Context = window.AudioContext || window.webkitAudioContext;
  if (autostart || !Context) return;
  try {
    audioContext = new Context();
  } catch (err) {
    console.warn('audio unavailable:', err.message);
    return;
  }
  // 1024 frames is ~21 ms at 48 kHz: low latency without audible crackle.
  const node = audioContext.createScriptProcessor(1024, 1, 1);
  node.onaudioprocess = (event) => {
    const out = event.outputBuffer.getChannelData(0);
    pullAudio(out);
    // The buffer is mono; the graph up-mixes to stereo.
  };
  node.connect(audioContext.destination);
}

function pumpAudio() {
  if (!running) return;
  // Re-read the pointer every frame: the buffer lives in wasm memory, which
  // this call may grow.
  const n = wasm.mappy_take_audio(16384);
  if (!n) return;
  const view = new Float32Array(memory.buffer, wasm.mappy_audio_ptr(), n);
  pushAudio(view.slice());
}

// --------------------------------------------------------------- drawing ---

function draw() {
  const ptr = wasm.mappy_rgb_ptr();
  const pixels = new Uint8Array(memory.buffer, ptr, WIDTH * HEIGHT * 4);
  imageData.data.set(pixels);
  ctx.putImageData(imageData, 0, 0);
}

// ------------------------------------------------------------ main loop ----

function loop(now) {
  requestAnimationFrame(loop);
  if (!running) return;

  // Fixed timestep paced against the wall clock: the game never runs fast
  // because the display is fast, and never drifts because a frame was slow.
  accumulator += now - lastTime;
  lastTime = now;
  let due = 0;
  while (accumulator >= FRAME_MS && due < MAX_CATCH_UP) {
    wasm.mappy_set_buttons(padBits);
    wasm.mappy_run_frame();
    accumulator -= FRAME_MS;
    due++;
    frames++;
  }
  if (accumulator > FRAME_MS * MAX_CATCH_UP) accumulator = 0; // resync after a stall
  if (!due) return;

  draw();
  pumpAudio();
  if (frames % 30 === 0) {
    statusLine.textContent = `frame ${frames} · ${(wasm.mappy_frame_count() / FPS).toFixed(1)} s of game time`;
  }
}

// ----------------------------------------------------------------- input ---

const KEY_BITS = new Map([
  ['ArrowUp', BUTTONS.up], ['KeyW', BUTTONS.up],
  ['ArrowDown', BUTTONS.down], ['KeyS', BUTTONS.down],
  ['ArrowLeft', BUTTONS.left], ['KeyA', BUTTONS.left],
  ['ArrowRight', BUTTONS.right], ['KeyD', BUTTONS.right],
  ['KeyZ', BUTTONS.a], ['KeyK', BUTTONS.a], ['Space', BUTTONS.a],
  ['KeyX', BUTTONS.b], ['KeyJ', BUTTONS.b],
  ['Enter', BUTTONS.start],
  ['ShiftLeft', BUTTONS.select], ['ShiftRight', BUTTONS.select], ['Tab', BUTTONS.select],
]);

function setBit(bit, on) {
  padBits = on ? padBits | bit : padBits & ~bit;
}

window.addEventListener('keydown', (event) => {
  const bit = KEY_BITS.get(event.code);
  if (bit === undefined) return;
  event.preventDefault();
  setBit(bit, true);
  if (audioContext && audioContext.state === 'suspended') audioContext.resume();
});

window.addEventListener('keyup', (event) => {
  const bit = KEY_BITS.get(event.code);
  if (bit === undefined) return;
  event.preventDefault();
  setBit(bit, false);
});

window.addEventListener('blur', () => { padBits = 0; });

// On-screen buttons for touch and mouse.
for (const element of document.querySelectorAll('[data-btn]')) {
  const name = element.dataset.btn;
  const bit = BUTTONS[name === 'start2' ? 'start' : name];
  if (bit === undefined) continue;
  const press = (event) => {
    event.preventDefault();
    setBit(bit, true);
    element.setPointerCapture?.(event.pointerId);
  };
  const release = (event) => {
    event.preventDefault();
    setBit(bit, false);
  };
  element.addEventListener('pointerdown', press);
  element.addEventListener('pointerup', release);
  element.addEventListener('pointercancel', release);
  element.addEventListener('pointerleave', release);
  element.addEventListener('contextmenu', (event) => event.preventDefault());
}

// ------------------------------------------------------------------ boot ---

function begin() {
  if (running) return;
  startAudio();
  sampleRate = audioContext ? audioContext.sampleRate : 48000;
  // (Re)create the machine at the AudioContext's real rate so nothing is
  // resampled on the way out.
  wasm.mappy_init(sampleRate);
  draw(); // show frame 0 straight away instead of a blank canvas
  running = true;
  overlay.classList.add('hidden');
  lastTime = performance.now();
  accumulator = 0;
  requestAnimationFrame(loop);
}

startButton.addEventListener('click', begin);

// `?autostart` is the screenshot/testing path: load the module synchronously
// (so the game is already drawn when the page's load event fires) and run a
// couple of seconds of frames. Normal visitors go through the async path and
// the "Click to play" button.
function bootSynchronously() {
  // Synchronous XHR cannot use responseType, so read the bytes through the
  // classic binary-string trick.
  const xhr = new XMLHttpRequest();
  xhr.open('GET', 'mappy.wasm', false);
  xhr.overrideMimeType('text/plain; charset=x-user-defined');
  xhr.send();
  const text = xhr.responseText;
  const bytes = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) bytes[i] = text.charCodeAt(i) & 0xff;
  const module = new WebAssembly.Module(bytes);
  wasm = new WebAssembly.Instance(module, {}).exports;
  memory = wasm.memory;
  sampleRate = 48000;
  wasm.mappy_init(sampleRate);
  for (let i = 0; i < 150; i++) wasm.mappy_run_frame();
  draw();
  running = true;
  overlay.classList.add('hidden');
  overlay.style.display = 'none'; // no fade when capturing a screenshot
  lastTime = performance.now();
  requestAnimationFrame(loop);
  statusLine.textContent = `frame ${wasm.mappy_frame_count()} (autostart)`;
}

(async function boot() {
  try {
    if (autostart && location.protocol !== 'file:') {
      bootSynchronously();
      return;
    }
    const url = 'mappy.wasm';
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    let instance;
    try {
      // Fast path: compile while downloading (needs application/wasm).
      ({ instance } = await WebAssembly.instantiateStreaming(response.clone(), {}));
    } catch {
      // Fallback for servers that mislabel the MIME type.
      const bytes = await (await fetch(url)).arrayBuffer();
      ({ instance } = await WebAssembly.instantiate(bytes, {}));
    }
    wasm = instance.exports;
    memory = wasm.memory;
    if (!memory) throw new Error('module exports no memory');
  } catch (err) {
    statusLine.textContent = `Could not load mappy.wasm: ${err.message}`;
    console.error(err);
    return;
  }
  statusLine.textContent = 'WebAssembly ready — click to play';
  if (autostart) begin();
})();
