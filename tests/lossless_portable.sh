#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/lossless-portable"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/lossless_portable.zi
for form in source saved; do
    input="$root/tests/lossless_portable.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/lossless_portable.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" bundle "$@" --entry lossless_portable:SelfTest -o "$out/$form.zx" "$input"
    test "$("$run_vm" run "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry lossless_portable:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/lossless_portable"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if LosslessPortable_SelfTest() != 0 { panic("authored lossless pixels differ") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/portable-test" "$out/$form-go"/*.go
    "$out/$form-go/portable-test"
done
printf '%s\n' 'Authored VP8L independent golden fingerprints: transforms/palette/cache/backref/groups source/saved C/Go/direct VM passed'
