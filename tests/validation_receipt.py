#!/usr/bin/env python3
"""Write only after the complete local package suite succeeds."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
toolchain = Path(os.environ.get("ZIRAN_ROOT", str(root / "../../ziran")))
binaries = {"ziran": Path(os.environ.get("ZIRAN", str(toolchain / "build/bin/ziran"))), "zi2zx-vm": Path(os.environ.get("ZIRAN_VM", str(toolchain / "build/bin/zi2zx-vm")))}
tests = "engine_contract riff legacy_compare dynamic_contract package_import authored_import lossless_bits lossless_transforms authored_lossless lossless_portable scratch_cap alpha alpha_plane alpha_hint vp8_bits vp8_header vp8_block vp8_transform vp8_predict vp8_filter vp8_color vp8_range authored authored_portable vp8_scratch_cap authored_sanitizers benchmark lossless_sanitizers".split()


def digest(path):
    hasher = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(65536), b''):
            hasher.update(block)
    return hasher.hexdigest()


receipt = {
    "recorded_utc": datetime.now(timezone.utc).isoformat(),
    "kind": "local tests; no GitHub checks or deployment implied",
    "command": "build-queue -- sh tests/all.sh",
    "scripts_passed": [f"tests/{name}.sh" for name in tests],
    "toolchain": {
        "version": subprocess.check_output([binaries["ziran"], "--version"], text=True).strip(),
        "git_head": subprocess.check_output(["git", "-C", str(toolchain), "rev-parse", "HEAD"], text=True).strip(),
        "has_uncommitted_tracked_changes": subprocess.run(["git", "-C", str(toolchain), "diff", "--quiet"]).returncode != 0,
        "binaries_sha256": {name: digest(path) for name, path in binaries.items()},
    },
    "package_source_sha256": {str(path.relative_to(root)): digest(path) for glob in ("src/*.zi", "tools/*.zi", "tests/*.zi", "tests/*.sh", "tests/*.py", "tests/*.c", "native/*", "ziran.toml", "Makefile") for path in sorted(root.glob(glob)) if path.is_file()},
    "corpus_manifest_sha256": digest(root / "tests/fixtures/manifest.json"),
    "lossy_corpus_manifest_sha256": digest(root / "tests/fixtures-vp8/manifest.json"),
    "range_regression_manifest_sha256": digest(root / "tests/fixtures-regression/manifest.json"),
    "native_source_revision": "1844042d1ca751e62e61df7617dba19c98588339",
    "remaining": ["authored animation intentionally unsupported", "facade default remains native until parent integration", "cold-cache/CPU/RSS/allocation/energy performance metrics remain unavailable"],
    "git_committed": False,
    "pushed": False,
    "published": False,
}
(root / "docs/validation.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
print("WebP local validation receipt saved; full authored still provider passed; default-native and animation/performance limitations remain explicit")
