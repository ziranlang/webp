#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/dynamic-contract"
mkdir -p "$out"
test -f "$root/build/native/libimagewebp.so"
"$ziran" ir --root tests --module-path "webp=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/dynamic_contract.zi
for form in source saved; do
    input="$root/tests/dynamic_contract.zi"
    set -- --root tests --module-path "webp=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/dynamic_contract.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --entry dynamic_contract:main "$@" -o "$out/$form" "$input"
    # Deliberately no static imagewebp archive or -lwebp link dependency.
    "${CC:-cc}" -std=c99 -O1 -I"$toolchain/include" -I"$out/$form" "$out/$form"/*.c -ldl -lm -o "$out/$form/dynamic-contract"
    "$out/$form/dynamic-contract" "$root/build/native/libimagewebp.so" "$foundation/tests/fixtures"
done
printf '%s\n' 'WebP dynamic engine: source/saved native without codec linkage; strict pixels, caller output, unavailable symbols and engine lifetime passed'
