#!/usr/bin/env python3
"""Verify normative VP8 table data against the exact pinned reference source.

--write is an explicit authoring operation for the generated .zi data file;
normal package tests only verify. No codec implementation runs in Python.
"""
import re
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
pin = "1844042d1ca751e62e61df7617dba19c98588339"
assert subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip() == pin
tables = (
    ("tree_dec.c", "CoeffsProba0", "Vp8CoefficientDefaults", 1056, "u8"),
    ("tree_dec.c", "CoeffsUpdateProba", "Vp8CoefficientUpdates", 1056, "u8"),
    ("tree_dec.c", "kBModesProba", "Vp8Intra4Probabilities", 900, "u8"),
    ("quant_dec.c", "kDcTable", "Vp8DcQuant", 128, "s32"),
    ("quant_dec.c", "kAcTable", "Vp8AcQuant", 128, "s32"),
)
output = ["// VP8 normative probability/quantization data, cross-checked against\n",
          f"// libwebp {pin}. BSD notice: docs/NOTICE.md.\n",
          "// Regeneration is explicit test/build tooling; product decoding is .zi.\n"]
for file, original, name, count, kind in tables:
    path = source / "src/dec" / file
    assert path.stat().st_size < 131072
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(), flags=re.S)
    start = text.index("{", text.index(original))
    depth, at = 1, start + 1
    while depth:
        depth += (text[at] == "{") - (text[at] == "}")
        at += 1
    values = [int(value) for value in re.findall(r"\b\d+\b", text[start:at])]
    assert len(values) == count, (name, len(values), count)
    # Keep each ordinary initializer below the current frontend's limit.
    chunks = [values[offset:offset + 256] for offset in range(0, count, 256)]
    for part, chunk in enumerate(chunks):
        suffix = str(part) if len(chunks) > 1 else ""
        output.append(f"{name}{suffix}: [{len(chunk)}]{kind} = .[\n")
        for offset in range(0, len(chunk), 16):
            output.append("    " + ",".join(map(str, chunk[offset:offset + 16])) + ("," if offset + 16 < len(chunk) else "") + "\n")
        output.append("];\n")
    if len(chunks) > 1:
        output.append(f"{name} :: (index: s32) -> {kind} {{\n")
        for part in range(len(chunks) - 1):
            output.append(f"    if index < {(part + 1) * 256} {{ return {name}{part}[index - {part * 256}] }}\n")
        output.append(f"    return {name}{len(chunks) - 1}[index - {(len(chunks) - 1) * 256}]\n}}\n")
expected = "".join(output).encode()
destination = root / "src/vtables.zi"
if sys.argv[2:] == ["--write"]:
    destination.write_bytes(expected)
assert destination.read_bytes() == expected, "VP8 normative table data/provenance mismatch"
print("VP8 normative probability/quantization data: 3268 values match exact pinned reference")
