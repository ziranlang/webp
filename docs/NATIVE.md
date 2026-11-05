# Native reference decoder

Native consumers include `native/WebP.cmake`, then call
`ziran_webp_decoder(target_name, pinned_source_directory)` with ordinary CMake
space-separated arguments. This adds one static target with the requested name
and the decoder/demux objects from the pinned libwebp source. Call it once per
CMake build tree; the libwebp object target names are shared.

The recipe disables encoders, tools and threads, enables position-independent
objects and function/data sections, and includes Android's CPU feature probe
once in the aggregate archive when upstream enables that target. Android
consumers retain their toolchain/ABI flags and link `dl`. No Android runtime
execution is implied by the Linux package tests.

The package uses the same function to create `build/native/libimagewebp.a`.
`native/build.sh` also creates `build/native/libimagewebp.so`; its replacement
is atomic. Build and artifact staging hold `build/native.lock` through the
complete operation. Invoke build-producing entry points through `build-queue`.
The package artifact currently supports `linux-x86_64-gnu` only; the reusable
CMake function can be consumed by another project's configured toolchain.
