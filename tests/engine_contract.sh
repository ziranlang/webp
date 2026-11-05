#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
source=${WEBP_SOURCE:-$("$ziran" pkg path libwebp --offline)}
out="$root/build/scratch/engine-contract"
mkdir -p "$out"
python3 "$foundation/tests/hash.py" "$foundation/tests/fixtures"
if ! sh native/build.sh "$source" >"$out/native-build.log" 2>&1; then tail -60 "$out/native-build.log" >&2; exit 1; fi
"$ziran" check --root tests --module-path "webp=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" tests/engine_contract.zi
"$ziran" ir --root tests --module-path "webp=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/engine_contract.zi
for form in source saved; do
    input="$root/tests/engine_contract.zi"
    set -- --root tests --module-path "webp=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/engine_contract.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --entry engine_contract:main "$@" -o "$out/$form" "$input"
    "${CC:-cc}" -std=c99 -O1 -I"$toolchain/include" -I"$out/$form" "$out/$form"/*.c "$root/build/native/libimagewebp.a" -lm -o "$out/$form/engine-contract"
    "$out/$form/engine-contract" "$foundation/tests/fixtures"
done
printf '%s\n' 'WebP libwebp engine: source/saved native C, lossy/lossless/alpha/first animation frame and bounded error contracts passed'
