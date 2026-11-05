#!/usr/bin/env python3
"""Explicit, deterministic corpus authoring; ordinary tests never regenerate it.

The tiny bit writer is independent test tooling. Pillow and the separately built
pinned libwebp oracle must both accept every final stream and agree on RGBA.
"""
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess

from PIL import Image, features
import PIL

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tests/fixtures"
ORACLE = ROOT / "build/bin/webp-oracle"
PIN = "1844042d1ca751e62e61df7617dba19c98588339"


class Bits:
    def __init__(self):
        self.data = bytearray()
        self.position = 0

    def put(self, value, count):
        assert 0 <= value < (1 << count)
        for i in range(count):
            if self.position // 8 == len(self.data):
                self.data.append(0)
            self.data[self.position // 8] |= ((value >> i) & 1) << (self.position % 8)
            self.position += 1


def simple(bits, values):
    assert 1 <= len(values) <= 2 and all(0 <= x < 256 for x in values)
    bits.put(1, 1)
    bits.put(len(values) - 1, 1)
    wide = int(values[0] > 1)
    bits.put(wide, 1)
    bits.put(values[0], 1 + wide * 7)
    if len(values) == 2:
        bits.put(values[1], 8)


def normal_pair(bits, alphabet, values):
    # Complete length-one tree; normal code lengths encode symbols above 255.
    assert len(values) == 2 and values[0] < values[1] < alphabet
    bits.put(0, 1)
    bits.put(0, 4)  # four code-length codes, in format order 17,18,0,1
    for length in (0, 0, 1, 1):
        bits.put(length, 3)
    bits.put(0, 1)  # all alphabet slots
    for symbol in range(alphabet):
        bits.put(int(symbol in values), 1)


def group(bits, word, green=None, distance=0, cache_bits=0):
    g = (word >> 8) & 255
    if green is None:
        simple(bits, [g])
    elif max(green) < 256:
        simple(bits, green)
    else:
        normal_pair(bits, 280 + (1 << cache_bits if cache_bits else 0), green)
    for value in ((word >> 16) & 255, word & 255, word >> 24, distance):
        simple(bits, [value])


def substream(bits, word, green=None):
    bits.put(0, 1)  # no cache; nested streams have no transforms/entropy-map flag
    group(bits, word, green)


def container(width, height, bits):
    header = (width - 1) | ((height - 1) << 14) | (1 << 28)
    payload = b"\x2f" + struct.pack("<I", header) + bits.data
    chunk = b"VP8L" + struct.pack("<I", len(payload)) + payload
    chunk += b"\0" * (len(payload) & 1)
    return b"RIFF" + struct.pack("<I", len(chunk) + 4) + b"WEBP" + chunk


def handcrafted():
    cases = []
    for mode in range(14):
        bits = Bits()
        bits.put(1, 1); bits.put(0, 2); bits.put(0, 3)
        substream(bits, 0xFF000000 | (mode << 8))
        bits.put(0, 1); bits.put(0, 1); bits.put(0, 1)
        group(bits, 0x00010101)
        cases.append((f"predictor-{mode:02}", 9, 7, bits,
                      {"transforms": [0], "predictor_modes": [mode]}))
    bits = Bits()
    bits.put(1, 1); bits.put(1, 2); bits.put(0, 3)
    substream(bits, 0xFF20C040)
    bits.put(0, 1); bits.put(0, 1); bits.put(0, 1)
    group(bits, 0xFFC89611)
    cases.append(("signed-color", 5, 3, bits, {"transforms": [1]}))
    bits = Bits()
    bits.put(1, 1); bits.put(2, 2)
    bits.put(0, 1); bits.put(0, 1); bits.put(0, 1)
    group(bits, 0xB007FA12)
    cases.append(("subtract-green", 17, 3, bits, {"transforms": [2]}))
    for count, packed in ((2, 0x55), (4, 0xE4), (16, 0xA3), (17, 16), (256, 200)):
        bits = Bits()
        bits.put(1, 1); bits.put(3, 2); bits.put(count - 1, 8)
        substream(bits, 0x11010203)  # differential palette, including alpha wrap
        bits.put(0, 1); bits.put(0, 1); bits.put(0, 1)
        group(bits, 0xFF000000 | (packed << 8))
        width_bits = 3 if count <= 2 else 2 if count <= 4 else 1 if count <= 16 else 0
        cases.append((f"palette-{count:03}", 19, 3, bits,
                      {"transforms": [3], "palette_width_bits": [width_bits]}))
    bits = Bits()
    bits.put(0, 1); bits.put(0, 1); bits.put(0, 1)
    word = 0xFF071409
    group(bits, word, [20, 261], distance=1)
    bits.put(0, 1); bits.put(1, 1); bits.put(0, 1)  # literal then length seven
    cases.append(("overlap-backref", 8, 1, bits, {"backrefs_min": 1, "normal_trees_min": 1}))
    for cache_bits in (1, 4, 8, 11):
        bits = Bits()
        bits.put(0, 1); bits.put(1, 1); bits.put(cache_bits, 4); bits.put(0, 1)
        slot = ((word * 0x1E35A7BD) & 0xFFFFFFFF) >> (32 - cache_bits)
        group(bits, word, [20, 280 + slot], cache_bits=cache_bits)
        bits.put(0, 1)
        for _ in range(12):
            bits.put(1, 1)
        cases.append((f"cache-{cache_bits:02}", 13, 1, bits,
                      {"cache_bits": [cache_bits], "cache_hits_min": 12, "normal_trees_min": 1}))
    bits = Bits()
    bits.put(0, 1); bits.put(0, 1); bits.put(1, 1); bits.put(0, 3)
    substream(bits, 0xFF000000, [0, 1]); bits.put(0, 1); bits.put(1, 1)
    group(bits, 0xFF173149); group(bits, 0xA4DB7133)
    cases.append(("entropy-groups", 8, 4, bits, {"entropy_groups_min": 2}))
    return [(name, container(w, h, bits), expected) for name, w, h, bits, expected in cases]


def encoded_patterns():
    result = []
    for name, w, h, kind in (
        ("single", 1, 1, "gradient"), ("vertical", 1, 73, "gradient"),
        ("horizontal", 91, 1, "gradient"), ("odd-gradient", 17, 19, "gradient"),
        ("wide-gradient", 257, 13, "gradient"), ("noise", 33, 33, "noise"),
        ("repeat", 97, 45, "repeat"), ("alpha-noise", 29, 31, "noise"),
    ):
        pixels = bytearray()
        state = 0x5B370D29
        for y in range(h):
            for x in range(w):
                if kind == "noise":
                    state ^= (state << 13) & 0xFFFFFFFF
                    state ^= state >> 17
                    state ^= (state << 5) & 0xFFFFFFFF
                    rgba = (state & 255, (state >> 8) & 255, (state >> 16) & 255,
                            (state >> 24) & 255 if name == "alpha-noise" else 255)
                elif kind == "repeat":
                    rgba = ((x % 7) * 31, (y % 5) * 47, ((x + y) % 3) * 99, 255)
                else:
                    rgba = ((x * 17 + y * 3) & 255, (x * 7 + y * 23) & 255,
                            (x * 13 + y * 11) & 255, (x * 19 + y * 29) & 255)
                pixels.extend(rgba)
        image = Image.frombytes("RGBA", (w, h), bytes(pixels))
        for method in (0, 6):
            output = io.BytesIO()
            image.save(output, "WEBP", lossless=True, exact=True, method=method)
            result.append((f"{name}-m{method}", output.getvalue(), {}, bytes(pixels)))
    return result


def write_new(path, data):
    if path.exists():
        if path.read_bytes() != data:
            raise SystemExit(f"refusing to overwrite changed fixture: {path}")
    else:
        path.write_bytes(data)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    scratch = ROOT / "build/scratch/fixture-generation"
    scratch.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([ORACLE, "--version"], text=True).strip()
    records = []
    cases = [(name, data, expected, None) for name, data, expected in handcrafted()]
    cases += encoded_patterns()
    for name, data, expected_features, known_pixels in cases:
        path = OUT / f"{name}.webp"
        write_new(path, data)
        image = Image.open(io.BytesIO(data)).convert("RGBA")
        pixels = image.tobytes()
        if known_pixels is not None and known_pixels != pixels:
            raise SystemExit(f"independent pattern pixels changed: {name}")
        raw = scratch / "oracle.rgba"
        subprocess.run([ORACLE, path, raw], check=True)
        if raw.read_bytes() != pixels:
            raise SystemExit(f"Pillow and pinned oracle disagree: {name}")
        golden = OUT / f"{name}.rgba"
        write_new(golden, pixels)
        records.append({"input": path.name, "input_sha256": hashlib.sha256(data).hexdigest(),
                        "input_bytes": len(data), "golden": golden.name,
                        "golden_sha256": hashlib.sha256(pixels).hexdigest(),
                        "golden_bytes": len(pixels), "width": image.width, "height": image.height,
                        "expected_features": expected_features,
                        "provenance": "tests/generate_lossless.py, deterministic original test patterns/bitstreams",
                        "rights": "CC0-1.0, dedicated by the fixture author"})
    manifest = {"schema": 1, "generator": "tests/generate_lossless.py",
                "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "pillow_version": PIL.__version__, "pillow_libwebp_version": features.version("webp"),
                "pinned_libwebp_revision": PIN, "pinned_libwebp_version_packed": int(version),
                "files": records}
    encoded = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    write_new(OUT / "manifest.json", encoded)
    write_new(OUT / "manifest.sha256", (hashlib.sha256(encoded).hexdigest() + "  manifest.json\n").encode())
    print(f"Authored corpus: {len(records)} streams; independent Pillow/pinned libwebp RGBA agree")


if __name__ == "__main__":
    main()
