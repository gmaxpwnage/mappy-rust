/*
 * Mappy for webOS TV — native SDL2 frontend.
 *
 * The game itself is the same recompiled Rust engine as the desktop and wasm
 * builds; crates/mappy-native exposes it as a plain C library. This file owns
 * the window, the sound device, the 60.0988 fps clock and the Magic Remote
 * mapping:
 *
 *   Left / Right  move
 *   OK            A (jump)
 *   Up            Start
 *   Down, B       unbound (the game does not use them)
 *
 * It is a normal SDL2 program, so the same source builds for Linux, macOS and
 * the webOS NDK; the webOS IPK is produced by tools/build_webos.py.
 */

#include <SDL2/SDL.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "mappy_native.h"

#define WIDTH 256
#define HEIGHT 240
#define FPS 60.0988

/* Controller bits, matching nes::button. */
#define BTN_A 1u
#define BTN_START 8u
#define BTN_LEFT 64u
#define BTN_RIGHT 128u

/* ~1.4 s of mono float audio at 48 kHz. */
#define RING_SAMPLES (1u << 16)
#define RING_MASK (RING_SAMPLES - 1u)

static float audio_ring[RING_SAMPLES];
static unsigned audio_read;
static unsigned audio_write;
static unsigned long audio_underruns;

static int running = 1;
static unsigned pad_bits;
static FILE *stats_file;

#define STATS_PATH "/media/developer/mappy-stats.txt"

/* --------------------------------------------------------------- audio --- */

static void audio_push(const float *samples, unsigned count) {
    unsigned used = (audio_write - audio_read) & RING_MASK;
    unsigned free = (RING_SAMPLES - 1u) - used;
    if (count > free) {
        /* Under/overrun: discard the oldest audio rather than stalling. */
        audio_read = (audio_read + (count - free)) & RING_MASK;
    }
    for (unsigned i = 0; i < count; i++) {
        audio_ring[audio_write] = samples[i];
        audio_write = (audio_write + 1u) & RING_MASK;
    }
}

static void audio_callback(void *userdata, Uint8 *stream, int len) {
    (void)userdata;
    Sint16 *out = (Sint16 *)stream;
    int count = len / (int)sizeof(Sint16);
    for (int i = 0; i < count; i++) {
        float sample = 0.0f;
        if (audio_read != audio_write) {
            sample = audio_ring[audio_read];
            audio_read = (audio_read + 1u) & RING_MASK;
        } else {
            audio_underruns++;
        }
        long value = (long)(sample * 32767.0f);
        if (value > 32767) value = 32767;
        if (value < -32768) value = -32768;
        out[i] = (Sint16)value;
    }
}

static void feed_audio(MappyEngine *engine, SDL_AudioDeviceID device) {
    unsigned count = mappy_audio_len(engine);
    if (!count || !device) return;
    SDL_LockAudioDevice(device);
    audio_push(mappy_audio_ptr(engine), count);
    SDL_UnlockAudioDevice(device);
}

/* ----------------------------------------------------------------- input --- */

static void set_button(unsigned bit, int down) {
    if (down) {
        pad_bits |= bit;
    } else {
        pad_bits &= ~bit;
    }
}

static void handle_key(SDL_Keycode key, int down) {
    switch (key) {
    case SDLK_LEFT:      set_button(BTN_LEFT, down); break;
    case SDLK_RIGHT:     set_button(BTN_RIGHT, down); break;
    /* Magic Remote OK / centre button. */
    case SDLK_RETURN:
    case SDLK_KP_ENTER:  set_button(BTN_A, down); break;
    /* The remote's Up button is the game's Start. */
    case SDLK_UP:        set_button(BTN_START, down); break;
    /* Down and B are deliberately unmapped: the game does not use them. */
    default:             break;
    }
}

static void poll_events(void) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_QUIT:
            running = 0;
            break;
        case SDL_KEYDOWN:
            if (!event.key.repeat) handle_key(event.key.keysym.sym, 1);
            break;
        case SDL_KEYUP:
            handle_key(event.key.keysym.sym, 0);
            break;
        /* In pointer mode the Magic Remote's OK button arrives as a click;
         * in 5-way mode it arrives as Return. Both mean A. */
        case SDL_MOUSEBUTTONDOWN:
            if (event.button.button == SDL_BUTTON_LEFT) set_button(BTN_A, 1);
            break;
        case SDL_MOUSEBUTTONUP:
            if (event.button.button == SDL_BUTTON_LEFT) set_button(BTN_A, 0);
            break;
        case SDL_WINDOWEVENT:
            if (event.window.event == SDL_WINDOWEVENT_FOCUS_LOST) pad_bits = 0;
            break;
        default:
            break;
        }
    }
}

/* -------------------------------------------------------------- selftest --- */

/* Runs the same scripted 600 frames as webos/engine_selftest.c and prints the
 * same hash, so build scripts can prove the frontend and the bare engine agree. */
static uint64_t hash_state = 1469598103934665603ULL;

static void mix32(uint32_t value) {
    hash_state ^= value;
    hash_state *= 1099511628211ULL;
}

static unsigned scripted_buttons(int frame) {
    unsigned buttons = 0;
    if (frame >= 30 && frame < 40) buttons |= BTN_START;
    if (frame >= 120 && frame < 125) buttons |= BTN_LEFT;
    if (frame >= 200 && frame < 205) buttons |= BTN_RIGHT;
    if (frame >= 260 && frame < 265) buttons |= BTN_A;
    if (frame >= 320 && frame < 330) buttons |= BTN_START;
    return buttons;
}

static void hash_frame(MappyEngine *engine) {
    const unsigned *pixels = mappy_rgb_ptr(engine);
    unsigned width = mappy_width();
    unsigned height = mappy_height();
    for (unsigned i = 0; i < width * height; i++) mix32(pixels[i]);

    const float *samples = mappy_audio_ptr(engine);
    unsigned count = mappy_audio_len(engine);
    for (unsigned i = 0; i < count; i++) {
        union {
            float f;
            uint32_t u;
        } bits;
        bits.f = samples[i];
        mix32(bits.u);
    }
}

static int selftest(SDL_Renderer *renderer, SDL_Texture *texture) {
    (void)renderer;
    MappyEngine *engine = mappy_create(48000.0);
    if (!engine) return 1;
    for (int frame = 0; frame < 600; frame++) {
        mappy_set_buttons(engine, scripted_buttons(frame));
        mappy_run_frame(engine);
        if (frame % 30 == 0) {
            hash_frame(engine);
            SDL_UpdateTexture(texture, NULL, mappy_rgb_ptr(engine), WIDTH * (int)sizeof(unsigned));
        }
    }
    printf("frames=%u hash=%016llx\n", mappy_frame_count(engine),
           (unsigned long long)hash_state);
    mappy_destroy(engine);
    return 0;
}

/* ------------------------------------------------------------------ main --- */

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    int testing = getenv("MAPPY_SELFTEST") != NULL;
    if (testing) {
        setenv("SDL_VIDEODRIVER", "dummy", 1);
        setenv("SDL_AUDIODRIVER", "dummy", 1);
    }

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_EVENTS) != 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }
    SDL_ShowCursor(SDL_DISABLE);
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");

    SDL_DisplayMode mode;
    if (SDL_GetDesktopDisplayMode(0, &mode) != 0 || mode.w <= 0 || mode.h <= 0) {
        mode.w = 1920;
        mode.h = 1080;
    }

    SDL_Window *window = SDL_CreateWindow(
        "Mappy", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, mode.w, mode.h,
        SDL_WINDOW_FULLSCREEN_DESKTOP | SDL_WINDOW_SHOWN);
    if (!window) {
        fprintf(stderr, "SDL_CreateWindow: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    if (!renderer) {
        fprintf(stderr, "SDL_CreateRenderer: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    SDL_RenderSetLogicalSize(renderer, WIDTH, HEIGHT);

    SDL_Texture *texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                             SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);
    if (!texture) {
        fprintf(stderr, "SDL_CreateTexture: %s\n", SDL_GetError());
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    if (testing) {
        int status = selftest(renderer, texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return status;
    }

    SDL_AudioSpec want;
    SDL_AudioSpec have;
    SDL_zero(want);
    want.freq = 48000;
    want.format = AUDIO_S16SYS;
    want.channels = 1;
    want.samples = 1024;
    want.callback = audio_callback;

    SDL_AudioDeviceID audio = SDL_OpenAudioDevice(NULL, 0, &want, &have,
                                                 SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);
    double sample_rate = 48000.0;
    if (audio) {
        sample_rate = (double)have.freq;
        SDL_PauseAudioDevice(audio, 0);
    } else {
        fprintf(stderr, "audio unavailable (%s); continuing silently\n", SDL_GetError());
    }

    MappyEngine *engine = mappy_create(sample_rate);
    if (!engine) {
        fprintf(stderr, "mappy_create failed\n");
        if (audio) SDL_CloseAudioDevice(audio);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    /* Diagnostics are opt-in: the file has to exist first, so a shipped
     * install never writes to the TV's storage. */
    if (access(STATS_PATH, F_OK) == 0) stats_file = fopen(STATS_PATH, "a");
    if (stats_file) {
        SDL_RendererInfo info;
        SDL_GetRendererInfo(renderer, &info);
        fprintf(stats_file, "video=%s renderer=%s flags=%u audio=%s freq=%d\n",
                SDL_GetCurrentVideoDriver(), info.name ? info.name : "?", info.flags,
                audio ? SDL_GetCurrentAudioDriver() : "none", have.freq);
        fflush(stats_file);
    }

    const double frame_seconds = 1.0 / FPS;
    const double frequency = (double)SDL_GetPerformanceFrequency();
    double last = (double)SDL_GetPerformanceCounter() / frequency;
    double accumulator = 0.0;

    double engine_seconds = 0.0;
    double present_seconds = 0.0;
    unsigned window_frames = 0;
    Uint64 window_start = SDL_GetPerformanceCounter();

    while (running) {
        poll_events();

        double now = (double)SDL_GetPerformanceCounter() / frequency;
        accumulator += now - last;
        last = now;
        if (accumulator > frame_seconds * 3.0) accumulator = 0.0; /* resync after a stall */

        Uint64 engine_start = SDL_GetPerformanceCounter();
        int due = 0;
        while (accumulator >= frame_seconds && due < 3) {
            mappy_set_buttons(engine, pad_bits);
            mappy_run_frame(engine);
            feed_audio(engine, audio);
            accumulator -= frame_seconds;
            due++;
        }
        engine_seconds += (double)(SDL_GetPerformanceCounter() - engine_start) / frequency;
        if (!due) {
            SDL_Delay(1);
            continue;
        }

        Uint64 render_start = SDL_GetPerformanceCounter();
        SDL_UpdateTexture(texture, NULL, mappy_rgb_ptr(engine), WIDTH * (int)sizeof(unsigned));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
        Uint64 render_end = SDL_GetPerformanceCounter();
        present_seconds += (double)(render_end - render_start) / frequency;

        if (++window_frames >= 120) {
            if (stats_file) {
                double wall = (double)(render_end - window_start) / frequency;
                fprintf(stats_file,
                        "frames=%u window_fps=%.1f engine_ms=%.2f present_ms=%.2f underruns=%lu\n",
                        mappy_frame_count(engine), wall > 0.0 ? window_frames / wall : 0.0,
                        1000.0 * engine_seconds / window_frames,
                        1000.0 * present_seconds / window_frames, audio_underruns);
                fflush(stats_file);
            }
            window_frames = 0;
            engine_seconds = 0.0;
            present_seconds = 0.0;
            window_start = render_end;
        }
    }

    mappy_destroy(engine);
    if (audio) SDL_CloseAudioDevice(audio);
    if (stats_file) fclose(stats_file);
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
