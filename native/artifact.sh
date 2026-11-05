#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
toolchain=${1:?toolchain root}
platform=${2:?platform}
stage=${3:?output stage}
test "$platform" = linux-x86_64-gnu
mkdir -p "$root/build"
if test "${WEBP_NATIVE_LOCK_HELD:-}" != "$root"; then
    exec flock "$root/build/native.lock" env WEBP_NATIVE_LOCK_HELD="$root" sh "$0" "$@"
fi
source=$(cd "$root" && "$toolchain/build/bin/ziran" pkg path libwebp --offline)
sh "$root/native/build.sh" "$source" >&2
mkdir -p "$stage/lib" "$stage/resources"
cp "$root/build/native/libimagewebp.a" "$stage/lib/libimagewebp.a"
cp "$root/build/native/libimagewebp.so" "$stage/lib/libimagewebp.so"
cp "$source/COPYING" "$stage/resources/LICENSE-libwebp"
cp "$source/PATENTS" "$stage/resources/PATENTS-libwebp"
