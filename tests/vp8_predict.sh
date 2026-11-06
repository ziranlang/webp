#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/vp8-predict"
mkdir -p "$out"
source=${WEBP_SOURCE:-$("$ziran" pkg path libwebp --offline)}
for name in vp8_predict vp8_predict_native; do
    "$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/$name-ir" "tests/$name.zi"
done
for form in source saved; do
    input="$root/tests/vp8_predict_native.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/vp8_predict_native-ir/vp8_predict_native.zir"; set -- --root "$out/vp8_predict_native-ir" --module-path "$out/vp8_predict_native-ir"; fi
    "$ziran" build --target=c --no-main --entry vp8_predict_native:Predict "$@" -o "$out/$form-oracle" "$input"
    "${CC:-cc}" -std=c99 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$source" -I"$out/$form-oracle" "$out/$form-oracle"/*.c tests/vp8_predict_oracle.c build/native/libimagewebp.a -lm -o "$out/$form-oracle/test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 "$out/$form-oracle/test"
    input="$root/tests/vp8_predict.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/vp8_predict-ir/vp8_predict.zir"; set -- --root "$out/vp8_predict-ir" --module-path "$out/vp8_predict-ir"; fi
    "$ziran" bundle "$@" --entry vp8_predict:SelfTest -o "$out/$form.zx" "$input"
    test "$("$zi2zx" run --vm "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry vp8_predict:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/vp8_predict"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if Vp8Predict_SelfTest() != 0 { panic("VP8 prediction differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/predict-test" "$out/$form-go"/*.go
    "$out/$form-go/predict-test"
done
printf '%s\n' 'Authored VP8 prediction: source/saved C/Go/direct VM and independent ASan+UBSan oracle passed'
