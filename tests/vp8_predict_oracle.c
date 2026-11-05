/* Test tooling only: real pinned native prediction functions, no copied oracle. */
#include "vp8_predict_native.h"
#include "src/dsp/dsp.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    VP8DspInit();
    for (unsigned trial = 0; trial < 256; trial++) {
        uint8_t original[1024];
        uint32_t state = 305419896u + trial;
        for (int i = 0; i < 1024; i++) { state = state * 1664525u + 1013904223u; original[i] = (uint8_t)(state >> 24); }
        for (int size = 4; size <= 16; size *= 2) {
            for (int mode = 0; mode < (size == 4 ? 10 : 7); mode++) {
                uint8_t actual[1024], expected[1024];
                memcpy(actual, original, sizeof(actual)); memcpy(expected, original, sizeof(expected));
                bool top = mode != 4 && mode != 6, left = mode != 5 && mode != 6;
                if (size == 4) { top = true; left = true; VP8PredLuma4[mode](expected + 33); }
                else if (size == 8) VP8PredChroma8[mode](expected + 33);
                else VP8PredLuma16[mode](expected + 33);
                int owned_mode = size != 4 && mode >= 4 ? 0 : mode;
                if (Predict(actual, size, owned_mode, top, left)) return 1;
                uint64_t hash = UINT64_C(14695981039346656037);
                for (int i = 0; i < 1024; i++) {
                    if (actual[i] != expected[i]) { fprintf(stderr, "prediction mismatch trial=%u size=%d mode=%d byte=%d\n", trial, size, mode, i); return 2; }
                    hash = (hash ^ expected[i]) * UINT64_C(1099511628211);
                }
                if (trial == 0 && size == 4 && mode == 5) printf("Independent VP8 prediction fingerprint: %" PRIu64 "\n", hash);
            }
        }
    }
    puts("VP8 prediction: 6144 independent blocks/all modes exactly match pinned libwebp, surrounding pixels unchanged");
    return 0;
}
