#!/usr/bin/env python3
"""Explicit original VP8 fixture authoring, never implicit during builds/tests."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import struct

from PIL import Image, features
import PIL

root = Path(__file__).resolve().parents[1]
original = root / "tests/fixtures"
destination = root / "tests/fixtures-vp8"
scratch = root / "build/scratch/fixture-generation"
oracle = root / "build/bin/webp-oracle"


def write_new(path, data):
    if path.exists():
        assert path.read_bytes() == data, f"refusing to overwrite changed fixture: {path}"
    else:
        path.write_bytes(data)


def main():
    destination.mkdir(parents=True, exist_ok=True)
    scratch.mkdir(parents=True, exist_ok=True)
    records = []
    source_records = json.loads((original / "manifest.json").read_text())["files"]
    for source in source_records:
        if not source["input"].endswith("-m6.webp"):
            continue
        pixels = (original / source["golden"]).read_bytes()
        assert hashlib.sha256(pixels).hexdigest() == source["golden_sha256"]
        image = Image.frombytes("RGBA", (source["width"], source["height"]), pixels)
        for quality in (20, 75, 100):
            name = source["input"].removesuffix("-m6.webp") + f"-q{quality}"
            buffer = io.BytesIO()
            image.save(buffer, "WEBP", lossless=False, quality=quality, method=6, exact=True)
            data = buffer.getvalue()
            # Keep a VP8 payload as a separate binary parser fixture; it is
            # extracted verbatim, not reconstructed or placed in source code.
            at, vp8 = 12, None
            while at < len(data):
                count = struct.unpack_from("<I", data, at + 4)[0]
                if data[at:at + 4] == b"VP8 ":
                    vp8 = data[at + 8:at + 8 + count]
                at += 8 + count + (count & 1)
            assert vp8 is not None
            input_path = destination / f"{name}.webp"
            write_new(input_path, data)
            decoded = Image.open(io.BytesIO(data)).convert("RGBA").tobytes()
            raw = scratch / "oracle.rgba"
            subprocess.run([oracle, input_path, raw], check=True)
            assert raw.read_bytes() == decoded, f"Pillow/pinned oracle pixels differ: {name}"
            record = {"name": name, "width": image.width, "height": image.height,
                      "source_rgba": "../fixtures/" + source["golden"],
                      "source_rgba_sha256": source["golden_sha256"],
                      "provenance": "tests/generate_lossy.py; original deterministic CC0 test pattern, quality recorded below",
                      "rights": "CC0-1.0, dedicated by the fixture author", "quality": quality, "method": 6}
            for kind, suffix, body in (("input", ".webp", data), ("payload", ".vp8", vp8), ("golden", ".rgba", decoded)):
                path = destination / (name + suffix)
                write_new(path, body)
                record[kind] = path.name
                record[kind + "_bytes"] = len(body)
                record[kind + "_sha256"] = hashlib.sha256(body).hexdigest()
            records.append(record)
    manifest = {"schema": 1, "generator": "tests/generate_lossy.py",
                "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "pillow_version": PIL.__version__, "pillow_libwebp_version": features.version("webp"),
                "pinned_libwebp_revision": "1844042d1ca751e62e61df7617dba19c98588339",
                "pinned_libwebp_version_packed": int(subprocess.check_output([oracle, "--version"], text=True)),
                "files": records}
    encoded = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    write_new(destination / "manifest.json", encoded)
    write_new(destination / "manifest.sha256", (hashlib.sha256(encoded).hexdigest() + "  manifest.json\n").encode())
    print(f"Original lossy corpus: {len(records)} WebP/payload/RGBA triples; independent Pillow/pinned pixels agree")


if __name__ == "__main__":
    main()
