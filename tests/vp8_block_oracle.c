/* Test tooling: the unchanged pinned decoder supplies mode/residual truth. */
#include "vp8_block_native.h"
#include "src/dec/vp8i_dec.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
static void mix(uint64_t* hash, int32_t value) {
    uint32_t word = (uint32_t)value;
    for (int i = 0; i < 4; i++) *hash = (*hash ^ ((word >> (i * 8)) & 255)) * UINT64_C(1099511628211);
}
static int verify(const uint8_t* bytes, size_t size, int synthetic) {
    VP8Decoder* decoder = VP8New(); VP8Io io;
    if (!decoder || !VP8InitIo(&io)) return 1;
    io.data = bytes; io.data_size = size;
    if (!VP8GetHeaders(decoder, &io) || !VP8InitFrame(decoder, &io)) {
        fprintf(stderr, "native initialization: %s\n", decoder->error_msg); VP8Delete(decoder); return 2;
    }
    uint64_t hash = UINT64_C(14695981039346656037);
    for (decoder->mb_y = 0; decoder->mb_y < decoder->mb_h; decoder->mb_y++) {
        if (!VP8ParseIntraModeRow(&decoder->br, decoder)) return 3;
        for (decoder->mb_x = 0; decoder->mb_x < decoder->mb_w; decoder->mb_x++) {
            if (!VP8DecodeMB(decoder, &decoder->parts[decoder->mb_y & decoder->num_parts_minus_one])) return 4;
            VP8MBData* block = decoder->mb_data + decoder->mb_x;
            mix(&hash, block->segment); mix(&hash, decoder->use_skip_proba ? block->skip : 0); mix(&hash, block->is_i4x4);
            for (int i = 0; i < (block->is_i4x4 ? 16 : 1); i++) mix(&hash, block->imodes[i]);
            mix(&hash, block->uvmode); mix(&hash, !!(block->non_zero_y | block->non_zero_uv));
            for (int i = 0; i < 384; i++) mix(&hash, block->coeffs[i]);
            VP8MB* top = decoder->mb_info + decoder->mb_x; VP8MB* left = decoder->mb_info - 1;
            mix(&hash, top->nz_dc); mix(&hash, left->nz_dc);
            for (int i = 0; i < 8; i++) { mix(&hash, (top->nz >> i) & 1); mix(&hash, (left->nz >> i) & 1); }
        }
        VP8InitScanline(decoder);
    }
    uint64_t actual = Fingerprint((uint8_t*)bytes, (int64_t)size);
    VP8Delete(decoder);
    if (hash != actual) { fprintf(stderr, "VP8 macroblock mismatch expected=%" PRIu64 " actual=%" PRIu64 "\n", hash, actual); return 5; }
    if (synthetic) printf("Independent VP8 macroblock fingerprint: %" PRIu64 "\n", hash);
    return 0;
}
int main(int argc, char** argv) {
    uint8_t synthetic[300] = {16,16,0,157,1,42,17,0,19,0};
    if (verify(synthetic, sizeof(synthetic), 1)) return 1;
    for (int i = 1; i < argc; i++) {
        uint8_t data[65536]; FILE* file = fopen(argv[i], "rb"); if (!file) return 2;
        size_t size = fread(data, 1, sizeof(data), file); int extra = fgetc(file); fclose(file);
        if (extra != EOF || verify(data, size, 0)) { fprintf(stderr, "macroblock fixture: %s\n", argv[i]); return 3; }
    }
    puts("VP8 macroblocks: modes, all 384 dequantized coefficients and neighbor contexts exactly match pinned decoder");
    return 0;
}
