#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
corpus = root / 'tests/fixtures-regression'
raw = (corpus / 'manifest.json').read_bytes()
assert hashlib.sha256(raw).hexdigest() == (corpus / 'manifest.sha256').read_text().split()[0]
manifest = json.loads(raw)
assert manifest['rights'] and manifest['source_fixture'] and manifest['primary_spec']
inventory = {'manifest.json', 'manifest.sha256'}
for name, info in manifest['files'].items():
    assert Path(name).name == name
    data = (corpus / name).read_bytes()
    assert len(data) == info['bytes'] and hashlib.sha256(data).hexdigest() == info['sha256']
    inventory.add(name)
assert inventory == {p.name for p in corpus.iterdir()}
source = (root / manifest['source_fixture']).read_bytes()
assert hashlib.sha256(source).hexdigest() == manifest['source_sha256']
mutated = bytearray(source); recipe = manifest['recipe']
assert mutated[recipe['container_offset']] == recipe['original_byte']
mutated[recipe['container_offset']] ^= recipe['xor_mask']
assert mutated == (corpus / 'vp8-range.webp').read_bytes()
assert (corpus / 'vp8-range-native-c.rgba').read_bytes() == (corpus / 'vp8-range-authored.rgba').read_bytes()
assert (corpus / 'vp8-range-native-simd.rgba').read_bytes() != (corpus / 'vp8-range-authored.rgba').read_bytes()
print('Pinned VP8 range regression: one-bit source recipe, rights/provenance, input/payload/both independent output digests verified')
