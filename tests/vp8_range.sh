#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/vp8-range"
mkdir -p "$out"
source=${WEBP_SOURCE:-$("$ziran" pkg path libwebp --offline)}
python3 tests/verify_regression.py
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/vp8_transform_native.zi
for form in source saved; do
    input="$root/tests/vp8_transform_native.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/vp8_transform_native.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --no-main --entry vp8_transform_native:TransformBoth "$@" -o "$out/$form" "$input"
    "${CC:-cc}" -std=c99 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$source" -I"$out/$form" "$out/$form"/*.c tests/vp8_range_oracle.c build/native/libimagewebp.a -lm -o "$out/$form/test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 "$out/$form/test" tests/fixtures-regression/vp8-range.vp8
done
printf '%s\n' 'VP8 range: independent RFC integer-stage derivation matches authored source/saved C; native SIMD exception isolated'
