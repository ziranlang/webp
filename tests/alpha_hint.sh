#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/alpha-hint"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/alpha_hint.zi
for form in source saved; do
    input="$root/tests/alpha_hint.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/alpha_hint.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --entry alpha_hint:main "$@" -o "$out/$form" "$input"
    "${CC:-cc}" -std=c99 -O1 -I"$toolchain/include" -I"$out/$form" "$out/$form"/*.c build/native/libimagewebp.a -lm -o "$out/$form/hint-test"
    "$out/$form/hint-test" tests/fixtures/palette-002.webp tests/fixtures/palette-002.rgba
done
printf '%s\n' 'Cleared VP8L alpha hint preserves exact independent pixels and truthful alpha metadata, native/authored/owned/borrowed source/saved passed'
