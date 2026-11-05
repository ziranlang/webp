#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/vp8-filter"
mkdir -p "$out"
source=${WEBP_SOURCE:-$("$ziran" pkg path libwebp --offline)}
for name in vp8_filter vp8_filter_native; do
    "$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/$name-ir" "tests/$name.zi"
done
for form in source saved; do
    input="$root/tests/vp8_filter_native.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/vp8_filter_native-ir/vp8_filter_native.zir"; set -- --root "$out/vp8_filter_native-ir" --module-path "$out/vp8_filter_native-ir"; fi
    "$ziran" build --target=c --no-main --entry vp8_filter_native:Filter "$@" -o "$out/$form-oracle" "$input"
    "${CC:-cc}" -std=c99 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$source" -I"$out/$form-oracle" "$out/$form-oracle"/*.c tests/vp8_filter_oracle.c build/native/libimagewebp.a -lm -o "$out/$form-oracle/test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 "$out/$form-oracle/test"
    input="$root/tests/vp8_filter.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/vp8_filter-ir/vp8_filter.zir"; set -- --root "$out/vp8_filter-ir" --module-path "$out/vp8_filter-ir"; fi
    "$ziran" bundle "$@" --entry vp8_filter:SelfTest -o "$out/$form.zx" "$input"
    test "$("$run_vm" run "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry vp8_filter:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/vp8_filter"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if Vp8Filter_SelfTest() != 0 { panic("VP8 loop filter differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/filter-test" "$out/$form-go"/*.go
    "$out/$form-go/filter-test"
done
printf '%s\n' 'Authored VP8 loop filtering: source/saved C/Go/direct VM and independent ASan+UBSan oracle passed'
