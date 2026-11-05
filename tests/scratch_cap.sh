#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/scratch-cap"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/scratch_cap.zi
for form in source saved; do
    input="$root/tests/scratch_cap.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/scratch_cap.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --no-main --entry scratch_cap:ScratchProbe "$@" -o "$out/$form" "$input"
    "${CC:-cc}" -std=c99 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$out/$form" "$out/$form"/*.c tests/scratch_cap.c -Wl,--wrap=realloc -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=free -lm -o "$out/$form/cap-test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 "$out/$form/cap-test"
done
printf '%s\n' 'Authored scratch ceiling: actual native allocation observations and source/saved ASan+UBSan failure/cleanup passed'
