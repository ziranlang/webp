#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/alpha"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/alpha.zi
for form in source saved; do
    input="$root/tests/alpha.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/alpha.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" bundle "$@" --entry alpha:SelfTest -o "$out/$form.zx" "$input"
    test "$("$zi2zx" run --vm "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry alpha:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/alpha"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if Alpha_SelfTest() != 0 { panic("alpha filter/header differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/alpha-test" "$out/$form-go"/*.go
    "$out/$form-go/alpha-test"
done
printf '%s\n' 'Authored ALPH bounded header and allocation-free inverse filters: source/saved C/Go/direct VM passed'
