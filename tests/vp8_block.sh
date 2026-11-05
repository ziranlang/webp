#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/vp8-block"
mkdir -p "$out"
source=${WEBP_SOURCE:-$("$ziran" pkg path libwebp --offline)}
python3 tests/vp8_tables.py "$source"
python3 tests/verify_lossy.py
for name in vp8_block vp8_block_native; do
    "$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/$name-ir" "tests/$name.zi"
done
for form in source saved; do
    input="$root/tests/vp8_block_native.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/vp8_block_native-ir/vp8_block_native.zir"; set -- --root "$out/vp8_block_native-ir" --module-path "$out/vp8_block_native-ir"; fi
    "$ziran" build --target=c --no-main --entry vp8_block_native:Fingerprint "$@" -o "$out/$form-oracle" "$input"
    "${CC:-cc}" -std=c99 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$source" -I"$out/$form-oracle" "$out/$form-oracle"/*.c tests/vp8_block_oracle.c build/native/libimagewebp.a -lm -o "$out/$form-oracle/test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 "$out/$form-oracle/test" tests/fixtures-vp8/*.vp8
    input="$root/tests/vp8_block.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/vp8_block-ir/vp8_block.zir"; set -- --root "$out/vp8_block-ir" --module-path "$out/vp8_block-ir"; fi
    "$ziran" bundle "$@" --entry vp8_block:SelfTest -o "$out/$form.zx" "$input"
    test "$("$run_vm" run "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry vp8_block:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/vp8_block"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if Vp8Block_SelfTest() != 0 { panic("VP8 macroblock state differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/block-test" "$out/$form-go"/*.go
    "$out/$form-go/block-test"
done
printf '%s\n' 'Authored VP8 macroblocks: source/saved C/Go/direct VM and 24 independent mode/residual/context ASan+UBSan fixtures passed'
