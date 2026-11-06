#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
sha256sum "$ziran" "$zi2zx" > "$root/build/scratch/toolchain-before.sha256"
for test in engine_contract riff legacy_compare dynamic_contract package_import authored_import lossless_bits lossless_transforms authored_lossless lossless_portable scratch_cap alpha alpha_plane alpha_hint vp8_bits vp8_header vp8_block vp8_transform vp8_predict vp8_filter vp8_color vp8_range authored authored_portable vp8_scratch_cap authored_sanitizers benchmark lossless_sanitizers; do
    sh "tests/$test.sh"
done
sha256sum -c "$root/build/scratch/toolchain-before.sha256"
ZIRAN_ROOT="$toolchain" ZIRAN="$ziran" ZIRAN_ZX="$zi2zx" python3 tests/validation_receipt.py
