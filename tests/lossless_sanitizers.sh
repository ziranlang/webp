#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/lossless-sanitizers"
mkdir -p "$out"
test -x "$root/build/bin/webp-oracle"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/lossless_mutation.zi
for form in source saved; do
    input="$root/tests/lossless_mutation.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/lossless_mutation.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --entry lossless_mutation:main "$@" -o "$out/$form" "$input"
    "${CC:-cc}" -std=c99 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$out/$form" "$out/$form"/*.c -lm -o "$out/$form/mutation-test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 python3 tests/mutate_lossless.py "$out/$form/mutation-test"
done
printf '%s\n' 'Authored VP8L source/saved ASan+UBSan bounded mutation/acceptance/pixel differential passed'
