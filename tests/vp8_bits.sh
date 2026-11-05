#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/vp8-bits"
mkdir -p "$out"
source=${WEBP_SOURCE:-$("$ziran" pkg path libwebp --offline)}
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/vp8_bits.zi
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/native-ir" tests/vp8_bits_native.zi
for form in source saved; do
    input="$root/tests/vp8_bits_native.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/native-ir/vp8_bits_native.zir"; set -- --root "$out/native-ir" --module-path "$out/native-ir"; fi
    "$ziran" build --target=c --no-main --entry vp8_bits_native:BoolSequence "$@" -o "$out/$form-oracle" "$input"
    "${CC:-cc}" -std=c99 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$source" -I"$out/$form-oracle" "$out/$form-oracle"/*.c tests/vp8_bits_oracle.c build/native/libimagewebp.a -lm -o "$out/$form-oracle/test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 "$out/$form-oracle/test"
    input="$root/tests/vp8_bits.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/vp8_bits.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" bundle "$@" --entry vp8_bits:SelfTest -o "$out/$form.zx" "$input"
    test "$("$run_vm" run "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry vp8_bits:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/vp8_bits"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if Vp8Bits_SelfTest() != 0 { panic("VP8 boolean reader differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/bits-test" "$out/$form-go"/*.go
    "$out/$form-go/bits-test"
done
printf '%s\n' 'Authored VP8 boolean reader: source/saved C/Go/direct VM and independent ASan+UBSan oracle passed'
