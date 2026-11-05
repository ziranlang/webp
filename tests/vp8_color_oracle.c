/* Test tooling only: independently execute pinned native fancy upsampling. */
#include "vp8_color_native.h"
#include "src/dsp/dsp.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    WebPInitUpsamplers();
    for (unsigned trial = 0; trial < 4; trial++) {
        uint8_t y[2048], u[1024], v[1024];
        uint32_t state = 305419896u + trial;
        for (int i = 0; i < 2048; i++) { state = state * 1664525u + 1013904223u; y[i] = (uint8_t)(state >> 24); }
        for (int i = 0; i < 1024; i++) { state = state * 1664525u + 1013904223u; u[i] = (uint8_t)(state >> 24); }
        for (int i = 0; i < 1024; i++) { state = state * 1664525u + 1013904223u; v[i] = (uint8_t)(state >> 24); }
        for (int width = 1; width <= 33; width++) for (int height = 1; height <= 9; height++) {
            uint8_t expected[4096], actual[4096];
            memset(expected, 213, sizeof(expected)); memset(actual, 213, sizeof(actual));
            const int stride = width * 4 + 5, ch = (height + 1) / 2;
            WebPUpsamplers[MODE_RGBA](y, NULL, u, v, u, v, expected, NULL, width);
            for (int row = 1; row < height; row += 2) {
                int top = (row - 1) / 2, bottom = top + 1 < ch ? top + 1 : ch - 1;
                WebPUpsamplers[MODE_RGBA](y + row * 64, row + 1 < height ? y + (row + 1) * 64 : NULL,
                                         u + top * 32, v + top * 32, u + bottom * 32, v + bottom * 32,
                                         expected + row * stride, row + 1 < height ? expected + (row + 1) * stride : NULL, width);
            }
            if (Convert(y, u, v, actual, width, height)) return 1;
            uint64_t hash = UINT64_C(14695981039346656037);
            for (int i = 0; i < 4096; i++) {
                if (actual[i] != expected[i]) { fprintf(stderr, "color mismatch trial=%u width=%d height=%d byte=%d\n", trial, width, height, i); return 2; }
                hash = (hash ^ expected[i]) * UINT64_C(1099511628211);
            }
            if (trial == 0 && width == 17 && height == 7) printf("Independent VP8 fancy RGBA fingerprint: %" PRIu64 "\n", hash);
        }
    }
    puts("VP8 color: 1188 independent odd/even/single-axis images exactly match pinned fancy RGBA, padding unchanged");
    return 0;
}
