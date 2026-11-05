# Image codec and WebP integration handoff

The image-codec foundation C-01/C-02/C-03 and the scoped authored WebP still
implementation are locally complete. Product implementations are ordinary
authored Ziran modules; no Kryon or compiler source was changed by this worker.
Both new packages remain uncommitted on master for the parent roadmap's coherent
integration. No pushes, releases, deployment or installation occurred.

## Dependency API

`../image-codec/src/api.zi` exports `DecodeResult`, `DecodeLimits`,
`ImageMetadata`, `DecodeError`, `DecodeOptions`, `BorrowedBytes`,
`OutputBuffer`, `Plane`/`PlaneView`, cooperative `Cancellation` and the
single-thread worker/working-byte ledger. Owning results reuse `std/image.Image`.
`DecodeProcedure` is an ordinary callback with an owned result; no registry or
native codec dependency is required. Exact buffer growth uses
`VecResizeBounded`, including non-power-of-two images and benchmark input files.
See the foundation's `docs/API.md`, `docs/CORPUS.md`, `docs/BENCHMARKS.md` and
`docs/validation.json` for signatures, error codes, defaults and current hashes.

`webp/authored` exports:

- `WebpAuthoredDecode(input: BorrowedBytes, options: DecodeOptions) -> DecodeResult`
- `WebpAuthoredDecodeInto(input: BorrowedBytes, output: OutputBuffer, options: DecodeOptions) -> WebpOutputResult`

These decode VP8L and keyframe VP8 with raw/compressed ALPH without native calls
or fallback. `webp/authored_lossless` retains the VP8L entry points and optional
observed format trace. Source/saved C, Go and direct VM package imports execute
the complete authored still provider without native codec linkage.

`webp/riff.WebpHasSignature(input)` is the prefix dispatch predicate. It accepts
the twelve-byte RIFF/WEBP prefix even if the body is incomplete. `WebpProbe`
performs bounded structural validation separately.

Native consumers include `native/WebP.cmake`, then call
`ziran_webp_decoder(target_name, pinned_source_directory)` using normal CMake
arguments. Kryon has already consumed this function and the predicate in its
own managed lane. The package's build and artifact staging share a lock; native
decoder-only output paths and Android CPU-feature handling are preserved.

## Final local verification

These exact foundation commands passed after all foundation changes:

```sh
build-queue -- sh tests/contracts.sh
build-queue -- sh tests/corpus.sh --verify
build-queue -- sh tests/benchmark_contract.sh
build-queue -- sh tests/package_import.sh
```

From the WebP package, after the final color-space and signed-intermediate fixes:

```sh
build-queue -- sh tests/all.sh
```

All28 scripts passed. The source/saved coverage includes C, Go, direct VM where
supported, native static/dynamic packages, frozen original compatibility and
ASan/UBSan. The complete still provider matches70 ordinary default-native
goldens. Differential coverage includes735 VP8/ALPH mutations and776 VP8L
mutations, with explicit classifications for reserved tools and strict terminal
zero-bit handling. The one default-native SIMD exception requires the exact
pinned input and both outputs; independent stage arithmetic is in
`tests/vp8_range.sh` and documented in `docs/VP8-RANGE.md`.

Actual native allocation probes observe3230 bytes/one allocation for the VP8
borrowed-output case and46976 bytes/five allocations for the VP8L palette case.
Exact caps succeed; one-byte-smaller caps reject before crossing; pre-cancel
allocates nothing; every injected allocation failure balances storage and the
ledger. Probes wrap malloc/calloc/realloc/free, including compiler-optimized
allocation calls. These are individual test observations, not RSS benchmarks.

The benchmark runner measures actual warm file-to-pixel samples for native and
authored lossy/lossless providers, validates exact correctness before timing,
and uses the shared closed schema. Cold-cache, CPU time, RSS, allocations and
energy remain unmeasured/null with reasons. No speedup claim is made.

`docs/validation.json` holds the current28-script receipt and source hashes.
The CLI and direct VM fingerprints were gated before/after the suite; all five
toolchain binaries also matched the earlier foundation snapshot after the run.
The optional ignored foundation corpus was verified historically, not repeated
in the final mandatory run. No GitHub checks have run for these new packages.

## Integration boundary

The public `webp/facade` default remains the explicit native reference bridge.
It preserves first-complete-animation-frame behavior. The authored provider
rejects animation, FastColor, reserved VP8 color space and reserved VP8L
predictor modes explicitly. Selecting a new default is left to the parent
integration; it was not silently changed by this worker. Working-byte limits
cover logical dynamic backing, excluding fixed temporary storage, allocator/
runtime overhead and RSS; cancellation/worker accounting remain single-threaded.

The parent session stopped at an account usage limit after earlier milestone
acknowledgments. Durable coordination request
`dce3d528b33533e3a1d29ddcdd2ea6bf99ca` records the handoff for the next live
ancestor/coordinator. Its delivery is pending, not an accepted integration or
permission to commit incomplete roadmap work. No additional source writer or
account/model substitution was launched.
