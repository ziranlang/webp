#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/authored-lossless"
mkdir -p "$out"
python3 tests/verify_lossless.py
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/authored_lossless.zi
for form in source saved; do
    input="$root/tests/authored_lossless.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/authored_lossless.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --exe --entry authored_lossless:main "$@" -o "$out/$form" "$input"
    python3 tests/verify_lossless.py "$out/$form/authored_lossless"
done
printf '%s\n' 'Authored WebP VP8L: exact independent RGBA, observed format coverage, limits/cancellation/ownership/output, source/saved C passed'
