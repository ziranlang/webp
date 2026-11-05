# Third-party reference

The optional native oracle builds the unchanged libwebp source at revision
`1844042d1ca751e62e61df7617dba19c98588339`. Its copyright and BSD license are
preserved in [LICENSE-libwebp.txt](LICENSE-libwebp.txt); artifact recipes also
copy its original `COPYING` and `PATENTS` files to the output resources.

The authored decoder's local-distance ordering is a WebP lossless format
constant, cross-checked against that revision's `kCodeToPlane`. Pixel decoding
in the authored modules runs Ziran code without a native codec call or fallback.
VP8 normative probability/quantization data and scalar arithmetic are also
cross-checked against this reference. Its additional IP grant is preserved in
[PATENTS-libwebp.txt](PATENTS-libwebp.txt). `tests/vp8_tables.py` verifies all
3268 table values against the exact pinned source; builds never regenerate it.

The deterministic test patterns and handcrafted bitstreams in `tests/fixtures`
are original fixtures dedicated under CC0-1.0. Their generator, tool versions,
byte digests, dimensions and provenance are recorded in the pinned manifest.
Goldens were independently compared with Pillow and the pinned native oracle.
Existing image-codec/Kryon fixtures retain their own provenance and rights.
