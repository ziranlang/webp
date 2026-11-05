# Authored decoder implementation status

The stable facade currently selects the explicit libwebp reference bridge.
`webp/authored_lossless` implements VP8L pixels with ordinary Ziran modules and
no native codec link. Its public package import executes source/saved C, Go and
the direct VM. Dynamic scratch backing is reserved before each exact-capacity
`VecResizeBounded` allocation, including all concurrently live maps, Huffman
groups, caches, code words and palette expansion buffers.

The working limit covers dynamic Vec backing, excluding fixed stack/static
state, allocator/runtime object overhead and process RSS. The native allocation
probe observes an actual 46976-byte peak for its palette case: an exact ceiling
succeeds, one byte less rejects before crossing it, pre-cancellation allocates
nothing, and each of the five injected allocation failures leaves no live
backing. Source/saved ASan/UBSan and portable budget tests pass. This observation
is a test case, not a whole-codec RSS/allocation benchmark.

The authored path decodes canonical Huffman trees, literal channels, overlapping
back references, all local distance codes, color caches, entropy groups and
the four inverse transforms. Output is owned straight RGBA8 `std/image.Image`
or a validated borrowed output buffer. Internal ARGB words are private entropy
storage. The separate private ALPH path decodes raw or VP8L-compressed green
planes and all four inverse filters. The lossless provider rejects lossy VP8
and animation with `UnsupportedCapability`. The native bridge retains its first complete
composed animation frame behavior.

`LosslessTrace` records actual bitstream events. It supplies format coverage,
not CPU time, allocation counts or performance estimates. The 43 original
binary/golden pairs cover all 14 predictor modes, signed color, subtract green,
palette packing widths 0–3, cache sizes 1/4/8/11, overlapping copies, multiple
entropy groups, gradients, noise, repeats and odd/single-axis dimensions.
`tests/verify_lossless.py` checks digests and observed coverage offline.

Reserved predictor modes 14/15 produce `UnsupportedCapability`; libwebp uses
black security sentinels for these undefined predictors. Missing terminal
Huffman bits produce `TruncatedInput`; libwebp's zero-filled lookahead sometimes
accepts them. Mutation tests classify the latter only after adding explicit
zero bytes makes the authored result exactly match the original oracle.

Locally validated commands:

```sh
build-queue -- sh tests/authored_lossless.sh
build-queue -- sh tests/lossless_bits.sh
build-queue -- sh tests/lossless_transforms.sh
build-queue -- sh tests/lossless_portable.sh
build-queue -- sh tests/scratch_cap.sh
build-queue -- sh tests/authored_import.sh
```

The portable test builds streams algorithmically and compares their pixels
with fingerprints of independently verified golden files. It executes source
and saved IR through native C, Go and the direct portable VM. Sanitizer/mutation
validation runs separately in `tests/lossless_sanitizers.sh`.

`webp/authored` now connects the VP8 boolean reader and keyframe header,
macroblock modes and residuals, dequantization, inverse DCT/WHT, all intra
prediction modes, reconstruction, per-segment simple/complex loop filtering
and strict fancy YUV420-to-RGBA conversion. It combines raw/compressed ALPH
and the VP8L provider into a complete still-image entry point with no native
fallback. Animation remains an explicit unsupported capability in this entry.

One exact-capacity Vec backs padded YUV, mode/nonzero contexts and filter flags;
no pixel-loop allocations occur. Reconstruction completes before filtering so
intra prediction observes unfiltered neighbors. Alpha scratch runs after YUV
scratch is released. Result pixels always reuse `std/image.Image`.

The complete pipeline matches70 ordinary independent default-native goldens:
43 original VP8L,24 original lossy/alpha and3 original shared still fixtures.
Owned and borrowed output, padding, exact scratch ceilings, cancellation and
balanced worker/byte accounting run from source and saved C. Actual package
exports also execute complete synthetic images in C, Go and direct VM. Separate
native oracles compare all384 coefficients and neighbor contexts per macroblock.

Source/saved ASan/UBSan differential tests exercise735 VP8/ALPH mutations:
371 accepted images,361 paired rejections,3 proven terminal-zero differences,
and one named default-native SIMD pixel exception within the accepted set.
The exception requires exact pinned input and outputs; its independent
[RFC integer-stage derivation](VP8-RANGE.md) explains the native SIMD overflow.
Every additional pixel mismatch fails. The existing776 VP8L mutations retain
their separately documented strict-tail and reserved-predictor classifications.

```sh
build-queue -- sh tests/authored.sh
build-queue -- sh tests/authored_portable.sh
build-queue -- sh tests/vp8_block.sh
build-queue -- sh tests/vp8_range.sh
build-queue -- sh tests/authored_sanitizers.sh
```

No codec performance claim, full authored WebP completion, commit, push or
deployment follows from these local results.
