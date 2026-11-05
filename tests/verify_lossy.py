#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
corpus = root / "tests/fixtures-vp8"
raw = (corpus / "manifest.json").read_bytes()
assert hashlib.sha256(raw).hexdigest() == (corpus / "manifest.sha256").read_text().split()[0]
manifest = json.loads(raw)
assert hashlib.sha256((root / manifest["generator"]).read_bytes()).hexdigest() == manifest["generator_sha256"]
assert manifest["pinned_libwebp_revision"] == "1844042d1ca751e62e61df7617dba19c98588339"
inventory = {"manifest.json", "manifest.sha256"}
for record in manifest["files"]:
    assert record["rights"] and record["provenance"] and record["width"] > 0 and record["height"] > 0
    for kind in ("input", "payload", "golden"):
        name = record[kind]
        assert Path(name).name == name
        inventory.add(name)
        data = (corpus / name).read_bytes()
        assert len(data) == record[kind + "_bytes"] and hashlib.sha256(data).hexdigest() == record[kind + "_sha256"]
    assert record["golden_bytes"] == record["width"] * record["height"] * 4
    source = record["source_rgba"]
    assert source == "../fixtures/" + Path(source).name
    assert hashlib.sha256((corpus / source).read_bytes()).hexdigest() == record["source_rgba_sha256"]
assert {path.name for path in corpus.iterdir()} == inventory
print(f"VP8 original corpus: {len(manifest['files'])} WebP/payload/RGBA provenance and digest triples verified")
