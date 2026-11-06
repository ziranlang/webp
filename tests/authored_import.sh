#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/authored-import"
mkdir -p "$out/src"
cp tests/authored_import.zi "$out/src/main.zi"
cat > "$out/ziran.toml" <<'TOML'
[package]
name = "webp-authored-import-test"
entry = "src/main.zi"
[toolchain]
git = "https://github.com/ziranlang/ziran.git"
ref = "master"
[dependencies.webp]
git = "https://github.com/ziranlang/webp.git"
ref = "master"
TOML
cat > "$out/ziran.local.toml" <<TOML
[overrides]
webp = "$root"
image_codec = "$foundation"
ziran = "$toolchain"
TOML
cd "$out"
"$ziran" lock --offline
"$ziran" check
"$ziran" run
"$ziran" ir --project --entry main:main -o "$out/ir" src/main.zi
"$ziran" bundle --project --entry main:SelfTest -o "$out/source.zx" src/main.zi
test "$("$zi2zx" run --vm "$out/source.zx")" = 0
"$ziran" bundle --root "$out/ir" --module-path "$out/ir" --entry main:SelfTest -o "$out/saved.zx" "$out/ir/main.zir"
test "$("$zi2zx" run --vm "$out/saved.zx")" = 0
"$ziran" build --target=c --exe --entry main:main --root "$out/ir" --module-path "$out/ir" -o "$out/saved-c" "$out/ir/main.zir"
"$out/saved-c/main"
for form in source saved; do
    input="$out/src/main.zi"
    set -- --project
    if test "$form" = saved; then input="$out/ir/main.zir"; set -- --root "$out/ir" --module-path "$out/ir"; fi
    "$ziran" build --target=go --pkg main "$@" -o "$out/$form-go" "$input"
    cat > "$out/$form-go/host_main.go" <<'GO'
package main
func main() { if Main_SelfTest() != 0 { panic("public authored VP8L import differs") } }
GO
    mkdir -p "$root/build/scratch/go-tmp" "$root/build/cache/go"
    GO111MODULE=off GOTMPDIR="$root/build/scratch/go-tmp" GOCACHE="$root/build/cache/go" go build -o "$out/$form-go/import-test" "$out/$form-go"/*.go
    "$out/$form-go/import-test"
done
printf '%s\n' 'Public authored VP8L package import: actual resolver exports, source/saved C/Go/direct VM, no native codec link passed'
