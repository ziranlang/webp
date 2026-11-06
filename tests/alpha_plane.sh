#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/alpha-plane"
mkdir -p "$out"
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tests/alpha_plane.zi
"$ziran" ir --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/fixture-ir" tests/alpha_fixture.zi
for form in source saved; do
    input="$root/tests/alpha_plane.zi"; fixture="$root/tests/alpha_fixture.zi"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then input="$out/ir/alpha_plane.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" bundle "$@" --entry alpha_plane:SelfTest -o "$out/$form.zx" "$input"
    test "$("$zi2zx" run --vm "$out/$form.zx")" = 0
    "$ziran" build --target=c --exe --entry alpha_plane:main "$@" -o "$out/$form-c" "$input"
    "$out/$form-c/alpha_plane"
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/main.go" <<'GO'
package main
func main() { if AlphaPlane_SelfTest() != 0 { panic("authored alpha pixels differ") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/plane-test" "$out/$form-go"/*.go
    "$out/$form-go/plane-test"
    set -- --root tests --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std"
    if test "$form" = saved; then fixture="$out/fixture-ir/alpha_fixture.zir"; set -- --root "$out/fixture-ir" --module-path "$out/fixture-ir"; fi
    "$ziran" build --target=c --entry alpha_fixture:main "$@" -o "$out/$form-fixture" "$fixture"
    "${CC:-cc}" -std=c99 -O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -I"$toolchain/include" -I"$out/$form-fixture" "$out/$form-fixture"/*.c -lm -o "$out/$form-fixture/fixture-test"
    ASAN_OPTIONS=detect_leaks=1:abort_on_error=1 "$out/$form-fixture/fixture-test" "$foundation/tests/fixtures/webp/lossy-alpha.webp" "$foundation/tests/fixtures/webp/lossy-alpha.rgba"
done
printf '%s\n' 'Authored ALPH compressed green-plane decode/filter: source/saved C/Go/direct VM, independent fixture alpha and ASan+UBSan passed'
