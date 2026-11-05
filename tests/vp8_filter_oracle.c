/* Test tooling only: compare original pinned native loop filters. */
#include "vp8_filter_native.h"
#include "src/dsp/dsp.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    VP8DspInit();
    for (unsigned trial = 0; trial < 256; trial++) {
        uint8_t original[1024]; uint32_t state = 305419896u + trial;
        for (int i = 0; i < 1024; i++) { state = state * 1664525u + 1013904223u; original[i] = trial % 2 ? (uint8_t)(state >> 24) : (uint8_t)(120 + ((state >> 24) & 15)); }
        int threshold = 16 + trial % 128, inner = trial % 3 ? 16 : 255, hev = trial % 3 ? trial % 8 : 255;
        for (int simple = 0; simple < 2; simple++) for (int internal = 0; internal < 2; internal++) for (int horizontal = 0; horizontal < 2; horizontal++) {
            uint8_t actual[1024], expected[1024]; memcpy(actual, original, sizeof(actual)); memcpy(expected, original, sizeof(expected));
            if (simple) {
                VP8SimpleFilterFunc function = horizontal ? (internal ? VP8SimpleHFilter16i : VP8SimpleHFilter16) : (internal ? VP8SimpleVFilter16i : VP8SimpleVFilter16);
                function(expected + 132, 32, threshold);
            } else {
                VP8LumaFilterFunc function = horizontal ? (internal ? VP8HFilter16i : VP8HFilter16) : (internal ? VP8VFilter16i : VP8VFilter16);
                function(expected + 132, 32, threshold, inner, hev);
            }
            if (Filter(actual, threshold, inner, hev, simple, internal, horizontal)) return 1;
            uint64_t hash = UINT64_C(14695981039346656037);
            for (int i = 0; i < 1024; i++) {
                if (actual[i] != expected[i]) { fprintf(stderr, "filter mismatch trial=%u simple=%d inner=%d horizontal=%d byte=%d\n", trial, simple, internal, horizontal, i); return 2; }
                hash = (hash ^ expected[i]) * UINT64_C(1099511628211);
            }
            if (!trial && !simple && !internal && !horizontal) printf("Independent VP8 loop-filter fingerprint: %" PRIu64 "\n", hash);
        }
    }
    puts("VP8 filtering: 2048 independent simple/complex/inner/boundary/directional cases exactly match pinned libwebp");
    return 0;
}
