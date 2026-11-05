#!/bin/sh
set -eu
. "$(dirname -- "$0")/common.sh"
out="$root/build/scratch/benchmark"
mkdir -p "$out"
make build/bin/webp-bench
version=$("$ziran" --version)
for form in source saved; do
    if test "$form" = saved; then
        "$ziran" ir --root tools --module-path "webp_private=$root/src" --module-path "image_codec=$foundation/src" --module-path "std=$toolchain/std" -o "$out/ir" tools/bench.zi
        "$ziran" build --target=c --entry bench:main --root "$out/ir" --module-path "$out/ir" -o "$out/saved" "$out/ir/bench.zir"
        "${CC:-cc}" -std=c99 -O2 -I"$toolchain/include" -I"$out/saved" "$out/saved"/*.c "$root/build/native/libimagewebp.a" -lm -o "$root/build/bin/webp-bench"
    fi
    for engine in libwebp authored-vp8l authored-still; do
        build/bin/webp-bench tests/fixtures/odd-gradient-m6.webp tests/fixtures/odd-gradient-m6.rgba 17 19 "$out/$form-lossless-$engine.json" 7 "$engine" "$version"
    done
    for engine in libwebp authored-still; do
        build/bin/webp-bench tests/fixtures-vp8/repeat-q75.webp tests/fixtures-vp8/repeat-q75.rgba 97 45 "$out/$form-lossy-$engine.json" 7 "$engine" "$version"
    done
done
status=0
build/bin/webp-bench tests/fixtures/odd-gradient-m6.webp tests/fixtures/predictor-00.rgba 17 19 "$out/wrong.json" 7 libwebp >"$out/wrong.log" 2>&1 || status=$?
test "$status" = 12 && test ! -e "$out/wrong.json"
status=0
build/bin/webp-bench tests/fixtures/odd-gradient-m6.webp tests/fixtures/odd-gradient-m6.rgba 17 19 "$out/unknown.json" 7 phantom >"$out/unknown.log" 2>&1 || status=$?
test "$status" = 5 && test ! -e "$out/unknown.json"
python3 - "$out" "$foundation" <<'PY'
import importlib.util, json, sys
from pathlib import Path
root = Path(sys.argv[1])
foundation = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location('benchmark_contract', foundation / 'tests/benchmark_validate.py')
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)
schema = json.loads((foundation / 'docs/benchmark.schema.json').read_text())
stable = {}
cases = [('lossless', 17, 19, 'tests/fixtures/odd-gradient-m6.rgba', ('libwebp', 'authored-vp8l', 'authored-still')),
         ('lossy', 97, 45, 'tests/fixtures-vp8/repeat-q75.rgba', ('libwebp', 'authored-still'))]
for form, case, width, height, golden, engine in [(form, case, w, h, golden, engine) for form in ('source', 'saved') for case, w, h, golden, engines in cases for engine in engines]:
    pixels = Path(golden).read_bytes()
    h = 14695981039346656037
    for value in pixels:
        h = ((h ^ value) * 1099511628211) & ((1 << 64) - 1)
    report = json.loads((root / (form + '-' + case + '-' + engine + '.json')).read_text())
    contract.validate(report)
    assert report.keys() == schema['properties'].keys()
    assert report['tool_versions'].keys() <= schema['properties']['tool_versions']['properties'].keys()
    assert report['provider'] == 'webp/' + engine
    assert report['correctness_verified'] is True and report['mode'] == 'warm'
    assert report['pixels'] == width * height and report['output_bytes'] == len(pixels)
    assert report['output_hash'] == f'{h:016x}' and report['output_hash_algorithm'] == 'fnv1a64'
    samples = report['samples_ns']
    assert len(samples) == report['iterations'] == 7 and samples == sorted(samples)
    assert all(isinstance(n, int) and n >= 0 for n in samples) and sum(samples) == report['total_ns']
    assert report['p50_ns'] == samples[3] and report['p95_ns'] == samples[6]
    assert report['active_workers'] == 1
    for key in ('allocations', 'cpu_ns_per_pixel', 'peak_rss_bytes', 'energy_joules', 'cpu_capabilities'):
        assert report[key] is None and report['unavailable'][key]
    assert report['tool_versions']['ziran']
    if engine == 'libwebp':
        assert report['tool_versions']['codec'].startswith('libwebp packed ')
        assert int(report['tool_versions']['codec'].split()[-1]) > 0
        assert len(report['tool_versions']['codec_revision']) == 40
    else:
        assert report['tool_versions']['codec'] is None and report['tool_versions']['codec_revision'] is None
    identity = {key: report[key] for key in ('provider', 'pixels', 'input_bytes', 'output_bytes', 'output_hash', 'tool_versions', 'active_workers')}
    if form == 'source':
        stable[case, engine] = identity
    else:
        assert stable[case, engine] == identity
print('WebP benchmark: actual warm file-to-pixel samples, golden-before-timing and truthful unavailable fields passed')
PY
