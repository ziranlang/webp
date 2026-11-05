# Decode API

All owning pixel results reuse `std/image.Image` through image-codec's
`DecodeResult`. Inspect `is_ok` and `error` before using the image. Inputs and
caller output buffers are synchronous borrows; keep their storage alive and
do not overlap input with output. Owned results survive input/library release.

- `webp/facade`: `WebpDecode(input,options) -> DecodeResult` and
  `WebpDecodeInto(input,output,options) -> WebpOutputResult` use the pinned native
  reference bridge. They preserve the first complete composed animation frame
  and report the source frame count.
- `webp/authored_lossless`: `WebpAuthoredLosslessDecode(input,options,trace=null)`
  and `WebpAuthoredLosslessDecodeInto(input,output,options,trace=null)` decode
  VP8L in Ziran, with no native fallback. Lossy VP8, animation, FastColor and
  reserved predictor modes 14/15 return `UnsupportedCapability`.
- `webp/authored`: `WebpAuthoredDecode(input,options)` and
  `WebpAuthoredDecodeInto(input,output,options)` decode VP8L or keyframe VP8
  with raw/compressed ALPH, using authored Ziran modules and no native fallback.
  Animation, FastColor and the reserved VP8 color-space bit return
  `UnsupportedCapability`. VP8 reconstruction
  follows portable integer arithmetic. On extreme mutated coefficients the
  pinned native SIMD decoder can differ from its own portable C decoder;
  this provider is validated against the latter in those cases. Exhausted
  entropy partitions are rejected without synthesizing missing zero bits.
- `webp/dynamic`: `OpenDynamicWebp(path)`, `DynamicWebpDecode`,
  `DynamicWebpDecodeInto`, `CloseDynamicWebp` load the same native ABI without
  static codec linkage. Keep a non-copied engine alive through its calls.
  Missing libraries/symbols return an unavailable engine and capability error.
- `webp/riff`: `WebpHasSignature(input)` tests the 12-byte RIFF/WEBP prefix for
  format dispatch, without requiring a complete body. `WebpProbe(input,limits)` validates bounded container structure
  without allocation. Its alpha bit is a source hint; successful pixel results
  also report any observed non-opaque alpha even when that hint was clear.

`WebpDefaultOptions()` retains the native 2147483647-byte input cap. Generic
`DefaultOptions()` retains image-codec's smaller default. Limits cover source
input, dimensions, pixels, output backing/span, metadata, source frames,
requested decoded frames and workers. Only strict default eight-bit RGBA output
is implemented; no ICC-managed color/HDR rendering is promised. Source color
information remains unknown when not established.

The authored provider reserves all dynamic scratch backing before allocation
and uses exact bounded Vec capacity. Its budget excludes fixed stack/static
state, runtime object/allocator overhead and RSS. The native ABI cannot enforce
its opaque allocator's scratch ceiling or interrupt a synchronous native call;
`LibwebpCapabilities()` reports these as unavailable. Both paths use one caller
execution lane and cooperate with cancellation around bounded work. Worker and
cancellation records are caller-owned single-thread state, not atomic objects.

Caller output validation precedes writes; padding is preserved. Cancellation
during work can leave output rows written. Failed owning calls return no image.
Worker leases and scratch reservations acquired by a call are released before
returning. An optional zero-initialized `LosslessTrace` accumulates actual format
events, not CPU time, memory measurements or allocation counts.
