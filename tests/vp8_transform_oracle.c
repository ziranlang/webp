/* Test tooling only: independently execute unchanged pinned libwebp kernels. */
#include "vp8_transform_native.h"
#include "src/dsp/dsp.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    VP8DspInit();
    for (unsigned trial = 0; trial < 256; trial++) {
        int16_t coefficients[16], expected_dc[256] = {0}, actual_dc[16];
        uint8_t expected[1024], actual[1024];
        uint32_t state = 305419896u + trial;
        for (int i = 0; i < 16; i++) {
            state = state * 1664525u + 1013904223u;
            coefficients[i] = (int16_t)((state >> 20) - 2048);
        }
        for (int i = 0; i < 1024; i++) {
            state = state * 1664525u + 1013904223u;
            actual[i] = expected[i] = (uint8_t)(state >> 24);
        }
        VP8Transform(coefficients, expected + 33, 0);
        VP8TransformWHT(coefficients, expected_dc);
        if (TransformBoth(coefficients, actual, actual_dc)) return 1;
        uint64_t hash = UINT64_C(14695981039346656037);
        for (int i = 0; i < 1024; i++) {
            if (actual[i] != expected[i]) { fprintf(stderr, "DCT trial=%u byte=%d\n", trial, i); return 2; }
            hash = (hash ^ expected[i]) * UINT64_C(1099511628211);
        }
        for (int i = 0; i < 16; i++) {
            if (actual_dc[i] != expected_dc[i * 16]) { fprintf(stderr, "WHT trial=%u index=%d\n", trial, i); return 3; }
            uint16_t dc = (uint16_t)actual_dc[i];
            hash = (hash ^ (dc & 255)) * UINT64_C(1099511628211);
            hash = (hash ^ (dc >> 8)) * UINT64_C(1099511628211);
        }
        if (trial == 0) printf("Independent VP8 DCT/WHT fingerprint: %" PRIu64 "\n", hash);
    }
    puts("VP8 DCT/WHT: 256 independent blocks exactly match pinned libwebp, surrounding pixels unchanged");
    return 0;
}
