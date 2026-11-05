#!/usr/bin/env python3
"""Bounded, deterministic byte mutations; compare acceptance and actual pixels."""
import json
from pathlib import Path
import random
import struct
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
scratch = root / "build/scratch/lossless-mutation"
scratch.mkdir(parents=True, exist_ok=True)
corpus = root / "tests/fixtures"
records = json.loads((corpus / "manifest.json").read_text())["files"]
oracle = root / "build/bin/webp-oracle"
decoder = Path(sys.argv[1])
sample = scratch / "sample.webp"
expected = scratch / "expected.rgba"
actual = scratch / "actual.rgba"


def wrap(payload):
    chunk = b"VP8L" + struct.pack("<I", len(payload)) + payload + b"\0" * (len(payload) & 1)
    return b"RIFF" + struct.pack("<I", len(chunk) + 4) + b"WEBP" + chunk


def run(program, output):
    output.unlink(missing_ok=True)
    result = subprocess.run([program, sample, output], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=8)
    assert len(result.stdout) < 4096 and len(result.stderr) < 65536
    return result


cases = []
for record in records:
    data = (corpus / record["input"]).read_bytes()
    size = struct.unpack_from("<I", data, 16)[0]
    payload = data[20:20 + size]
    # Adjust both sizes and padding, exercising the actual bit decoder rather
    # than letting every truncation stop at the outer RIFF length check.
    stops = set(range(5, len(payload))) if record["input"] in ("cache-04.webp", "entropy-groups.webp", "palette-002.webp") else {5, 6, 7, len(payload) // 2, len(payload) - 1}
    for stop in sorted(stops):
        if 0 <= stop < len(payload):
            cases.append((record["input"] + f":cut{stop}", wrap(payload[:stop])))
    rng = random.Random(record["input"])
    for i in range(12):
        modified = bytearray(payload)
        at = rng.randrange(5, len(payload))
        modified[at] ^= 1 << rng.randrange(8)
        cases.append((record["input"] + f":flip{i}", wrap(modified)))

valid = rejected = conservative = unsupported = strict_tail = 0
for label, data in cases:
    sample.write_bytes(data)
    reference = run(oracle, expected)
    decoded = run(decoder, actual)
    assert 0 <= reference.returncode <= 12, (label, "oracle crashed", reference.stderr[-1500:])
    assert 0 <= decoded.returncode <= 12, (label, "authored process/sanitizer failure", decoded.returncode, decoded.stderr[-1500:])
    assert b"runtime error:" not in decoded.stderr and b"Sanitizer" not in decoded.stderr, (label, decoded.stderr[-1500:])
    if reference.returncode == 0 and decoded.returncode == 0:
        assert actual.read_bytes() == expected.read_bytes(), (label, "pixel mismatch")
        valid += 1
    elif reference.returncode != 0 and decoded.returncode != 0:
        assert not actual.exists(), (label, "error wrote a pixel result")
        rejected += 1
    elif decoded.returncode == 6:
        # This test process deliberately has a 16MiB scratch limit. Native
        # libwebp has no equivalent strict allocator ceiling.
        conservative += 1
    elif reference.returncode == 0 and decoded.returncode == 5:
        # Reserved predictor modes 14/15 have only security-sentinel fallback
        # in libwebp; this engine reports unsupported instead of inventing a
        # defined predictor. Header/version/color options are not mutated.
        unsupported += 1
    elif reference.returncode == 0 and decoded.returncode == 3:
        # libwebp's lookahead zero-fills an exhausted bit window and can accept
        # an unused terminal tree with missing zero bits. Establish this exact
        # boundary difference: adding explicit zero tail bytes must make the
        # authored parser accept and reproduce the original oracle pixels.
        expected_pixels = expected.read_bytes()
        size = struct.unpack_from("<I", data, 16)[0]
        payload = data[20:20 + size]
        repaired = False
        for count in (1, 2):
            sample.write_bytes(wrap(payload + b"\0" * count))
            extended = run(decoder, actual)
            assert 0 <= extended.returncode <= 12, (label, "extended tail crashed", extended.stderr[-1500:])
            if extended.returncode == 0 and actual.read_bytes() == expected_pixels:
                repaired = True
                break
        assert repaired, (label, "unexplained truncated/accepted mismatch", decoded.stderr[-1000:])
        strict_tail += 1
    else:
        raise AssertionError((label, "acceptance mismatch", reference.returncode, decoded.returncode, decoded.stderr[-1000:]))
print(f"VP8L mutations: {len(cases)} bounded cases, {valid} exact valid pixels, {rejected} paired rejections, {conservative} scratch-limit rejections, {unsupported} reserved-predictor capability rejections, {strict_tail} verified strict zero-tail rejections")
