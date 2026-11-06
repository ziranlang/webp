#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/package-import"
mkdir -p "$out/src"
cp tests/package_import.zi "$out/src/main.zi"
cat > "$out/ziran.toml" <<'TOML'
[package]
name = "webp-import-test"
entry = "src/main.zi"
links = ["imagewebp", "m"]
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
if ! "$ziran" pkg artifact webp:libwebp --platform linux-x86_64-gnu >"$out/descriptor-path" 2>"$out/artifact.log"; then tail -60 "$out/artifact.log" >&2; exit 1; fi
descriptor=$(cat "$out/descriptor-path")
test -f "$descriptor"
stage=$(dirname -- "$descriptor")
test -f "$stage/lib/libimagewebp.a"
test -f "$stage/lib/libimagewebp.so"
test -s "$stage/resources/LICENSE-libwebp"
test -s "$stage/resources/PATENTS-libwebp"
LDFLAGS="-L$stage/lib -Wl,-rpath,$stage/lib" "$ziran" run -- "$foundation/tests/fixtures/webp/lossless.webp"
"$ziran" ir --project --entry main:main -o "$out/ir" src/main.zi
"$ziran" build --target=c --entry main:main --root "$out/ir" --module-path "$out/ir" -o "$out/saved" "$out/ir/main.zir"
"${CC:-cc}" -std=c99 -I"$toolchain/include" -I"$out/saved" "$out/saved"/*.c "$stage/lib/libimagewebp.a" -lm -o "$out/saved/import-test"
"$out/saved/import-test" "$foundation/tests/fixtures/webp/lossless.webp"
printf '%s\n' 'WebP ordinary package: local override exports, pinned source artifact/license outputs, source/saved native execution passed'
