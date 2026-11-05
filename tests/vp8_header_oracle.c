/* Test tooling only: compare full parsed state from the actual pinned decoder. */
#include "vp8_header_native.h"
#include "src/dec/vp8i_dec.h"
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
static void mix(uint64_t* hash, int32_t value) {
    uint32_t word = (uint32_t)value;
    for (int i = 0; i < 4; i++) *hash = (*hash ^ ((word >> (i * 8)) & 255)) * UINT64_C(1099511628211);
}
static int verify(const uint8_t* bytes, size_t size, int synthetic) {
    VP8Decoder* decoder = VP8New(); VP8Io io;
    if (!decoder || !VP8InitIo(&io)) return 1;
    io.data = bytes; io.data_size = size;
    if (!VP8GetHeaders(decoder, &io)) { fprintf(stderr, "native header error: %s\n", decoder->error_msg); VP8Delete(decoder); return 2; }
    uint64_t hash = UINT64_C(14695981039346656037);
    mix(&hash, decoder->pic_hdr.width); mix(&hash, decoder->pic_hdr.height); mix(&hash, decoder->frm_hdr.profile);
    mix(&hash, decoder->pic_hdr.colorspace); mix(&hash, decoder->pic_hdr.clamp_type);
    mix(&hash, decoder->num_parts_minus_one + 1); mix(&hash, decoder->segment_hdr.use_segment);
    mix(&hash, decoder->segment_hdr.update_map); mix(&hash, decoder->segment_hdr.absolute_delta);
    for (int i = 0; i < 4; i++) { mix(&hash, decoder->segment_hdr.quantizer[i]); mix(&hash, decoder->segment_hdr.filter_strength[i]); }
    for (int i = 0; i < 3; i++) mix(&hash, decoder->proba.segments[i]);
    mix(&hash, decoder->filter_hdr.simple); mix(&hash, decoder->filter_hdr.level); mix(&hash, decoder->filter_hdr.sharpness);
    mix(&hash, decoder->filter_hdr.use_lf_delta);
    for (int i = 0; i < 4; i++) { mix(&hash, decoder->filter_hdr.ref_lf_delta[i]); mix(&hash, decoder->filter_hdr.mode_lf_delta[i]); }
    for (int i = 0; i < 4; i++) {
        mix(&hash, decoder->dqm[i].y1_mat[0]); mix(&hash, decoder->dqm[i].y1_mat[1]);
        mix(&hash, decoder->dqm[i].y2_mat[0]); mix(&hash, decoder->dqm[i].y2_mat[1]);
        mix(&hash, decoder->dqm[i].uv_mat[0]); mix(&hash, decoder->dqm[i].uv_mat[1]);
    }
    for (int t = 0; t < 4; t++) for (int b = 0; b < 8; b++) for (int c = 0; c < 3; c++) for (int p = 0; p < 11; p++) mix(&hash, decoder->proba.bands[t][b].probas[c][p]);
    mix(&hash, decoder->use_skip_proba); mix(&hash, decoder->skip_p);
    uint64_t actual = Fingerprint((uint8_t*)bytes, (int64_t)size);
    VP8Delete(decoder);
    if (hash != actual) { fprintf(stderr, "VP8 header mismatch expected=%" PRIu64 " actual=%" PRIu64 "\n", hash, actual); return 3; }
    if (synthetic) printf("Independent VP8 header fingerprint: %" PRIu64 "\n", hash);
    return 0;
}
int main(int argc, char** argv) {
    uint8_t synthetic[52] = {16,4,0,157,1,42,17,0,19,0};
    if (verify(synthetic, sizeof(synthetic), 1)) return 1;
    for (int i = 1; i < argc; i++) {
        uint8_t data[65536]; FILE* file = fopen(argv[i], "rb");
        if (!file) return 2;
        size_t size = fread(data, 1, sizeof(data), file);
        int extra = fgetc(file); fclose(file);
        if (extra != EOF || verify(data, size, 0)) { fprintf(stderr, "header fixture: %s\n", argv[i]); return 3; }
    }
    puts("VP8 header: segmentation/filter/partitions/quantizers/1056 probabilities/skip state exactly match pinned decoder");
    return 0;
}
