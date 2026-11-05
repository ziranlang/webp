#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/authored"
mkdir -p "$out"
python3 tests/verify_lossless.py
python3 tests/verify_lossy.py
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/authored.zi
for form in source saved; do
    input="$root/tests/authored.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/authored.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --exe --entry authored:main "$@" -o "$out/$form" "$input"
    python3 tests/verify_authored.py "$out/$form/authored"
done
printf '%s\n' 'Authored WebP VP8L/VP8/ALPH: exact independent RGBA, limits/cancellation/ownership/output, source/saved C passed'
