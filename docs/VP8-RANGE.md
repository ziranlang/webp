# VP8 arithmetic regression

The pinned 1692-byte fixture changes one source byte, at offset175, by XOR32.
Its manifest preserves the CC0 source digest, recipe, native library/tool
digests, observed CPU features, and both binary native outputs. The complete
RGBA results differ in62 bytes between native SIMD and native C.

The isolated U subblock at macroblock(4,2) has coefficient29000: coded value1160
times quantizer25. Its token is representable, dequantized value fits signed16,
and every first-pass value fits signed16. A second-pass sum is37827 including
rounding. Shifting first yields4728; adding prediction128 and clamping gives255.
The SIMD16-bit add wraps that sum to-27709, producing0 after shift and clamp.

[RFC6386 sections14.4–14.5](https://www.rfc-editor.org/rfc/rfc6386.html#section-14.4)
specify signed16 storage between passes, integer second-pass sums followed by
shift, then a32-bit predictor/residue sum and unsigned8 saturation. The authored
code follows that order. Its intermediate narrowing is explicit.

`tests/vp8_range.sh` independently derives the RFC stage and compares authored,
native C and native SIMD on the pinned binary. `tests/vp8_transform.sh` also
tests the arithmetic through C, Go and direct VM. This named native SIMD
exception does not permit other pixel differences: the mutation validator
requires this exact input and both pinned outputs. Ordinary corpus parity
still compares against the default native decoder.
