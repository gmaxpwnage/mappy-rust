/*
 * Headless engine smoke test for CI.
 *
 * Runs 600 frames with a scripted controller sequence and hashes the
 * framebuffer and audio. The same source is built for ARM and run under
 * qemu-arm, so a cross-compiled engine that produces different pixels or
 * samples from the reference build fails the release.
 */

#include <stdint.h>
#include <stdio.h>

#include "mappy_native.h"

static uint64_t hash_state = 1469598103934665603ULL;

static void mix32(uint32_t value) {
    hash_state ^= value;
    hash_state *= 1099511628211ULL;
}

static unsigned scripted_buttons(int frame) {
    unsigned buttons = 0;
    if (frame >= 30 && frame < 40) buttons |= 8;      /* Start */
    if (frame >= 120 && frame < 125) buttons |= 64;   /* Left */
    if (frame >= 200 && frame < 205) buttons |= 128;  /* Right */
    if (frame >= 260 && frame < 265) buttons |= 1;    /* A */
    if (frame >= 320 && frame < 330) buttons |= 8;    /* Start */
    return buttons;
}

int main(void) {
    MappyEngine *engine = mappy_create(48000.0);
    if (!engine) {
        fprintf(stderr, "mappy_create failed\n");
        return 1;
    }
    unsigned width = mappy_width();
    unsigned height = mappy_height();
    for (int frame = 0; frame < 600; frame++) {
        mappy_set_buttons(engine, scripted_buttons(frame));
        mappy_run_frame(engine);
        if (frame % 30 == 0) {
            const unsigned *pixels = mappy_rgb_ptr(engine);
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
    }
    printf("frames=%u hash=%016llx\n", mappy_frame_count(engine),
           (unsigned long long)hash_state);
    mappy_destroy(engine);
    return hash_state == 0x7e8d84c0bb8b4ac7ULL ? 0 : 2;
}
