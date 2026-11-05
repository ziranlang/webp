# WebP

Optional Ziran image package reusing `std/image.Image` and `image_codec`.
The current `webp/facade` explicitly uses a pinned libwebp oracle bridge.
Native codec integration is authored in `.zi`; the unchanged upstream library
is a pinned source dependency, built by the package's native artifact recipe.
There is no Kryon dependency in the package or its public API.

`WebpDecode(input: BorrowedBytes, options: DecodeOptions) -> DecodeResult`
owns straight RGBA8 pixels. `WebpDecodeInto` borrows a validated `OutputBuffer`
and returns metadata/error without transferring its storage. Animation returns
only the first complete composed frame and reports the source frame count.
`WebpDefaultOptions` preserves the existing native WebP input cap of
2147483647 bytes; ordinary `DefaultOptions` can impose a smaller cap.
`webp/authored` exposes the authored VP8L/VP8(+ALPH) still-image provider,
including bounded scratch backing and portable execution with no native codec
link. `webp/authored_lossless` retains the VP8L entry points and optional format
trace. The [API contract](docs/API.md) records ownership and capability limits.

`webp/riff` is an allocation-free authored RIFF parser with explicit length,
padding, image header, animation frame rectangle/count and metadata limits.
It is independently executed from source and saved IR in C, Go and the direct
portable VM. Header validation and pixel decoding have separate tests.

`LibwebpCapabilities` truthfully reports caller-owned output, one execution lane
and first-frame compatibility. Synchronous native calls cannot enforce an
internal scratch-memory allocation ceiling or stop mid-call; those capabilities
are false. Input/output/container limits and cooperative checks before/after
native work remain enforced. Native opaque objects and borrowed frames are
released before returning; native internal threads are disabled. No color
management/HDR or encoding capability is exposed. The bridge rejects FastColor.

```sh
build-queue -- sh tests/engine_contract.sh
build-queue -- sh tests/riff.sh
build-queue -- sh tests/legacy_compare.sh
build-queue -- sh tests/dynamic_contract.sh
build-queue -- sh tests/package_import.sh
build-queue -- sh tests/all.sh
```

Tests reuse the independently pinned mandatory image-codec corpus. Only the
optional legacy comparison reads the hash-pinned original Kryon decoder from
its frozen baseline (or an unchanged original checkout), without changing it.
The native tests use the existing pinned source package offline. Configure
local `ziran` and `image_codec` overrides before locking during development;
no bootstrap commit is needed. `WEBP_SOURCE` can select an existing source
package with the exact declared revision. No native source is fetched during
a build. All builds run through `build-queue`; no display is used.

The validated native artifact platform is currently Linux x86-64 GNU. Consumers
request `ziran pkg artifact webp:libwebp --platform linux-x86_64-gnu`, add the
returned descriptor's `lib` directory to link search paths, and link
`imagewebp` and `m`. The same artifact includes self-contained
`libimagewebp.so`; shared-link consumers must also provide its runtime search
path or package it beside their application. Consumers importing `webp/dynamic` can call
`OpenDynamicWebp(path)`, `DynamicWebpDecode`/`DynamicWebpDecodeInto` and
`CloseDynamicWebp` with no static codec linkage (only `dl` and `m`). The engine
owns its library handle; keep it alive through every decode and do not copy
or close it during a call. Returned pixels remain owned after closing it.
Missing libraries/symbols produce an unavailable engine and explicit capability
error. Other platforms fail explicitly until their recipes and
actual execution are validated. The [authored implementation status](docs/OWNED-DECODER.md)
records completed pixel work and remaining acceptance gates. The stable bridge
is not represented as a fully authored WebP decoder.

`build-queue -- sh tests/benchmark.sh` builds the stable `build/bin/webp-bench`.
It verifies exact golden pixels before timing real warm file reads and decode
calls. It records actual samples and active workers; unavailable CPU, RSS,
allocation and energy instruments remain null. `authored-vp8l` selects lossless
decoding; `authored-still` selects the authored VP8L/VP8/ALPH provider. The local
test measures actual warm samples for both lossless and lossy input. Cold-cache
timing, CPU time, RSS, allocations and energy remain unmeasured.
A small successful case is not a general codec performance result.
