#ifndef MAPPY_NATIVE_H
#define MAPPY_NATIVE_H

/* C ABI of the no_std engine static library (crates/mappy-native). */

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MappyEngine MappyEngine;

MappyEngine *mappy_create(double sample_rate);
void mappy_destroy(MappyEngine *engine);

/* NES button bits: 1=A 2=B 4=Select 8=Start 16=Up 32=Down 64=Left 128=Right */
void mappy_set_buttons(MappyEngine *engine, unsigned bits);

void mappy_run_frame(MappyEngine *engine);

const unsigned int *mappy_rgb_ptr(MappyEngine *engine); /* 0xAARRGGBB */
const float *mappy_audio_ptr(MappyEngine *engine);
unsigned int mappy_audio_len(MappyEngine *engine);

unsigned int mappy_frame_count(MappyEngine *engine);
unsigned int mappy_width(void);
unsigned int mappy_height(void);

#ifdef __cplusplus
}
#endif

#endif
