#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/lossless-transforms"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/lossless_transforms.zi
for form in source saved; do
    input="$root/tests/lossless_transforms.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/lossless_transforms.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" bundle "$@" --entry lossless_transforms:SelfTest -o "$out/$form.zx" "$input"
    test "$("$zi2zx" run --vm "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry lossless_transforms:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/lossless_transforms"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if LosslessTransforms_SelfTest() != 0 { panic("lossless transforms differ") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/transforms-test" "$out/$form-go"/*.go
    "$out/$form-go/transforms-test"
done
printf '%s\n' 'WebP lossless inverse transform scalar kernels: source/saved C/Go/direct VM passed'
