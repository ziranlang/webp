#!/usr/bin/env python3
"""Deterministic VP8/ALPH mutations exercising real entropy/pixel paths."""
from pathlib import Path
import hashlib
import json
import random
import struct
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
corpus = root / "tests/fixtures-vp8"
scratch = root / "build/scratch/authored-mutation"
scratch.mkdir(parents=True, exist_ok=True)
decoder = Path(sys.argv[1]).resolve()
oracle = root / "build/bin/webp-oracle"
scalar_oracle = Path(sys.argv[2]).resolve()
sample = scratch / "sample.webp"
expected = scratch / "expected.rgba"
actual = scratch / "actual.rgba"
scalar_output = scratch / "scalar.rgba"

def chunks(data):
    result = []
    at = 12
    while at < len(data):
        size = struct.unpack_from('<I', data, at + 4)[0]
        result.append((data[at:at + 4], data[at + 8:at + 8 + size]))
        at += 8 + size + (size & 1)
    return result

def wrap(parts):
    body = b''.join(tag + struct.pack('<I', len(payload)) + payload + b'\0' * (len(payload) & 1) for tag, payload in parts)
    return b'RIFF' + struct.pack('<I', len(body) + 4) + b'WEBP' + body

def run(program, output):
    output.unlink(missing_ok=True)
    result = subprocess.run([program, sample, output], capture_output=True, timeout=8)
    assert len(result.stdout) < 4096 and len(result.stderr) < 65536
    assert 0 <= result.returncode <= 12, (label, result.returncode, result.stderr[-2000:])
    assert b'runtime error:' not in result.stderr and b'Sanitizer' not in result.stderr, (label, result.stderr[-2000:])
    return result.returncode

cases = []
for record in json.loads((corpus / 'manifest.json').read_text())['files']:
    parts = chunks((corpus / record['input']).read_bytes())
    for index, (tag, payload) in enumerate(parts):
        if tag not in (b'VP8 ', b'ALPH'):
            continue
        start = 10 if tag == b'VP8 ' else 1
        stops = {start, start + 1, len(payload) // 2, len(payload) - 1}
        if tag == b'VP8 ':
            first_end = 10 + (int.from_bytes(payload[:3], 'little') >> 5)
            stops.update((first_end - 1, first_end, first_end + 1))
        for stop in sorted(stops):
            if start <= stop < len(payload):
                modified = parts.copy(); modified[index] = (tag, payload[:stop])
                cases.append((record['name'] + f':{tag!r}:cut{stop}', modified))
        rng = random.Random(record['name'] + repr(tag))
        for iteration in range(12):
            modified = bytearray(payload)
            at = rng.randrange(start, len(payload))
            modified[at] ^= 1 << rng.randrange(8)
            changed = parts.copy(); changed[index] = (tag, bytes(modified))
            cases.append((record['name'] + f':{tag!r}:flip{iteration}', changed))

valid = rejected = limited = strict_tail = scalar_parity = reserved_color = 0
for label, parts in cases:
    sample.write_bytes(wrap(parts))
    native = run(oracle, expected); authored = run(decoder, actual)
    if native == 0 and authored == 0:
        if actual.read_bytes() != expected.read_bytes():
            # Only the independently derived, pinned RFC14.4/14.5 regression
            # is an accepted exception. Another mismatch still fails here.
            regression = root / 'tests/fixtures-regression'
            assert label == "repeat-q75:b'VP8 ':flip3", (label, 'new unresolved default-native difference')
            assert hashlib.sha256(wrap(parts)).hexdigest() == 'dffefdd22edc80aafb8b642aed771d96b63e2b4806de7042c4a1c33237281876'
            assert actual.read_bytes() == (regression / 'vp8-range-native-c.rgba').read_bytes()
            assert expected.read_bytes() == (regression / 'vp8-range-native-simd.rgba').read_bytes()
            assert run(scalar_oracle, scalar_output) == 0, (label, 'scalar native rejected')
            assert actual.read_bytes() == scalar_output.read_bytes(), (label, 'pixel mismatch against portable native C')
            scalar_parity += 1
        valid += 1
    elif native != 0 and authored != 0:
        assert not actual.exists(), (label, 'error returned pixels')
        rejected += 1
    elif authored == 6:
        limited += 1
    elif native == 0 and authored == 5:
        # First boolean decision uses probability128/range255. A first
        # partition byte128..254 explicitly selects the reserved color_space.
        payload = next(payload for tag, payload in parts if tag == b'VP8 ')
        assert 128 <= payload[10] < 255, (label, 'unexplained unsupported capability')
        reserved_color += 1
    elif native == 0 and authored == 3:
        # Prove a strict terminal zero-lookahead difference rather than
        # assuming every accepted/truncated mismatch is benign.
        expected_pixels = expected.read_bytes()
        repaired = False
        for index, (tag, payload) in enumerate(parts):
            if tag not in (b'VP8 ', b'ALPH'):
                continue
            for count in (1, 2):
                changed = parts.copy(); changed[index] = (tag, payload + b'\0' * count)
                sample.write_bytes(wrap(changed))
                if run(decoder, actual) == 0 and actual.read_bytes() == expected_pixels:
                    repaired = True
                    break
            if repaired:
                break
        assert repaired, (label, 'unexplained terminal difference')
        strict_tail += 1
    else:
        raise AssertionError((label, 'acceptance mismatch', native, authored))
print(f'VP8/ALPH mutations: {len(cases)} cases, {valid} valid pixels ({scalar_parity} pinned RFC-derived default-native SIMD exception), {rejected} paired rejections, {limited} explicit limit rejections, {reserved_color} reserved-color capability rejections, {strict_tail} proven strict zero-tail differences')
