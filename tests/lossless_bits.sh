#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/lossless-bits"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/lossless_bits.zi
for form in source saved; do
    input="$root/tests/lossless_bits.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/lossless_bits.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" bundle "$@" --entry lossless_bits:SelfTest -o "$out/$form.zx" "$input"
    test "$("$run_vm" run "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry lossless_bits:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/lossless_bits"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if LosslessBits_SelfTest() != 0 { panic("lossless Huffman/bit decoding differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/bits-test" "$out/$form-go"/*.go
    "$out/$form-go/bits-test"
done
printf '%s\n' 'WebP lossless bit reader/canonical Huffman: source/saved C/Go/direct VM passed'
