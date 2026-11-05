#!/bin/sh
# Invoke via build-queue; all generated output belongs to this package.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source=${1:?provide pinned libwebp source package}
test "$(git -C "$source" rev-parse HEAD)" = 1844042d1ca751e62e61df7617dba19c98588339
mkdir -p "$root/build/native"
if test "${WEBP_NATIVE_LOCK_HELD:-}" != "$root"; then
    exec flock "$root/build/native.lock" env WEBP_NATIVE_LOCK_HELD="$root" sh "$0" "$@"
fi
cmake -S "$root/native" -B "$root/build/native" -DWEBP_DIR="$source" -DCMAKE_BUILD_TYPE=Release
cmake --build "$root/build/native" --target imagewebp --parallel 1
"${CC:-cc}" -shared -Wl,-z,defs -Wl,--whole-archive "$root/build/native/libimagewebp.a" -Wl,--no-whole-archive -lm -o "$root/build/native/libimagewebp.so.pending"
mv "$root/build/native/libimagewebp.so.pending" "$root/build/native/libimagewebp.so"
