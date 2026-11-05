#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/riff"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/riff.zi
for form in source saved; do
    input="$root/tests/riff.zi"
    set -- --root tests --module-path "webp=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/riff.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" bundle "$@" --entry riff:SelfTest -o "$out/$form.zx" "$input"
    test "$("$run_vm" run "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry riff:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/riff"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if Riff_SelfTest() != 0 { panic("RIFF contract differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/riff-test" "$out/$form-go"/*.go
    "$out/$form-go/riff-test"
done
printf '%s\n' 'WebP RIFF bounds and metadata: source/saved C/Go/direct VM passed'
