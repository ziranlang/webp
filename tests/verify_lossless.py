#!/usr/bin/env python3
"""Offline corpus inventory/hash/oracle/observed-feature verification."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
corpus = root / "tests/fixtures"
raw = (corpus / "manifest.json").read_bytes()
assert hashlib.sha256(raw).hexdigest() == (corpus / "manifest.sha256").read_text().split()[0]
manifest = json.loads(raw)
assert manifest["schema"] == 1
assert len(manifest["pinned_libwebp_revision"]) == 40
assert hashlib.sha256((root / manifest["generator"]).read_bytes()).hexdigest() == manifest["generator_sha256"]
inventory = {"manifest.json", "manifest.sha256"}
aggregate = {"transforms": 0, "predictor_modes": 0, "palette_width_bits": 0, "cache_bits": 0}
for record in manifest["files"]:
    assert record["provenance"] and record["rights"]
    for kind in ("input", "golden"):
        name = record[kind]
        assert Path(name).name == name
        inventory.add(name)
        data = (corpus / name).read_bytes()
        assert len(data) == record[f"{kind}_bytes"]
        assert hashlib.sha256(data).hexdigest() == record[f"{kind}_sha256"]
    assert record["golden_bytes"] == record["width"] * record["height"] * 4
    if len(sys.argv) == 2:
        trace = json.loads(subprocess.check_output([sys.argv[1], corpus / record["input"], corpus / record["golden"]], text=True))
        assert trace["streams"] > 0 and trace["literals"] > 0
        for feature, expected in record["expected_features"].items():
            if feature.endswith("_min"):
                assert trace[feature[:-4]] >= expected, (record["input"], feature, trace)
            else:
                key = "transform_mask" if feature == "transforms" else feature
                required = sum(1 << value for value in expected)
                assert trace[key] & required == required, (record["input"], feature, trace)
        for key in aggregate:
            aggregate[key] |= trace["transform_mask" if key == "transforms" else key]
assert {path.name for path in corpus.iterdir()} == inventory
if len(sys.argv) == 2:
    assert aggregate["transforms"] == 15
    assert aggregate["predictor_modes"] == (1 << 14) - 1
    assert aggregate["palette_width_bits"] == 15
    assert all(aggregate["cache_bits"] & (1 << value) for value in (1, 4, 8, 11))
print(f"VP8L corpus: {len(manifest['files'])} binary/golden/provenance pairs verified" + ("; exact authored RGBA and observed format coverage passed" if len(sys.argv) == 2 else ""))
