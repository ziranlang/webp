/* Test tooling only: pinned libwebp's real reader is the independent oracle. */
#include "vp8_bits_native.h"
#include "src/utils/bit_reader_inl_utils.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

int main(void) {
    for (unsigned trial = 0; trial < 256; trial++) {
        uint8_t data[256], probabilities[1024], expected[1024], actual[1024];
        uint32_t state = 305419896u + trial;
        for (int i = 0; i < 256; i++) {
            state = state * 1664525u + 1013904223u;
            data[i] = (uint8_t)(state >> 24);
        }
        if (data[0] == 255) data[0] = 254;
        for (int i = 0; i < 512; i++) {
            state = state * 1664525u + 1013904223u;
            probabilities[i] = trial == 1 ? 0 : trial == 2 ? 255 : trial == 3 ? 128 : (uint8_t)(state >> 24);
        }
        VP8BitReader reader;
        if (!VP8InitBitReader(&reader, data, sizeof(data))) return 1;
        for (int i = 0; i < 512; i++) expected[i] = VP8GetBit(&reader, probabilities[i], "test");
        if (BoolSequence(data, 256, probabilities, 512, actual) != 0) return 2;
        uint64_t hash = UINT64_C(14695981039346656037);
        for (int i = 0; i < 512; i++) {
            if (expected[i] != actual[i]) {
                fprintf(stderr, "VP8 decision mismatch trial=%u symbol=%d\n", trial, i);
                return 3;
            }
            hash = (hash ^ expected[i]) * UINT64_C(1099511628211);
        }
        if (trial == 0) printf("Independent VP8 boolean fingerprint: %" PRIu64 "\n", hash);
    }
    puts("VP8 boolean reader: 131072 individual decisions exactly match pinned libwebp");
    return 0;
}
