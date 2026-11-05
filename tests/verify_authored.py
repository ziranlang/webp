#!/usr/bin/env python3
"""Run an authored still provider against already pinned independent goldens."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
executable = Path(sys.argv[1]).resolve()
count = 0
for directory in ("fixtures", "fixtures-vp8"):
    corpus = root / "tests" / directory
    for record in json.loads((corpus / "manifest.json").read_text())["files"]:
        result = subprocess.run([executable, corpus / record["input"], corpus / record["golden"]], capture_output=True, text=True)
        if result.returncode:
            raise SystemExit(f"{directory}/{record['input']}: exit {result.returncode}; {result.stderr[:2000]}")
        count += 1
print(f"Authored WebP still pixels and ownership/limits/cancellation/output: {count} independent goldens passed")
corpus = root / "../image-codec/tests/fixtures/webp"
for name in ("lossless", "lossy", "lossy-alpha"):
    subprocess.run([executable, corpus / (name + ".webp"), corpus / (name + ".rgba")], check=True)
print("Original shared lossless/lossy/alpha still-image goldens passed")
result = subprocess.run([executable, corpus / 'animated.webp', corpus / 'animated.rgba'], capture_output=True, text=True)
assert result.returncode == 5, ('authored animation capability', result.returncode)
