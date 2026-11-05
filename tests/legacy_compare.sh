#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
legacy=${KRYON_ROOT:-$root/../../../kryonlabs/kryon}
baseline=${KRYON_WEBP_BASELINE_DIR:-$legacy/backup/codec-extraction-baseline}
if test ! -f "$baseline/webp_image.zi"; then baseline="$legacy/src/backend"; fi
expected=$(cut -d ' ' -f 1 "$root/tests/legacy.sha256")
actual=$(sha256sum "$baseline/webp_image.zi" | cut -d ' ' -f 1)
test "$actual" = "$expected" || { printf '%s\n' 'Original Kryon WebP decoder changed; set KRYON_WEBP_BASELINE_DIR to its verified frozen baseline' >&2; exit 1; }
out="$root/build/scratch/legacy-compare"
mkdir -p "$out"
test -f "$root/build/native/libimagewebp.a"
"$ziran" ir --root tests --module-path "webp=$root/src" --module-path "legacy_backend=$baseline" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/legacy_compare.zi
for form in source saved; do
    input="$root/tests/legacy_compare.zi"
    set -- --root tests --module-path "webp=$root/src" --module-path "legacy_backend=$baseline" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/legacy_compare.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=c --entry legacy_compare:main "$@" -o "$out/$form" "$input"
    "${CC:-cc}" -std=c99 -O1 -I"$toolchain/include" -I"$out/$form" "$out/$form"/*.c "$root/build/native/libimagewebp.a" -lm -o "$out/$form/compare"
    "$out/$form/compare" "$foundation/tests/fixtures"
done
printf '%s\n' 'WebP bridge pixels exactly match hash-pinned original Kryon decoder, including first composed animation frame, source/saved IR'
