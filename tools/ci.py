#!/usr/bin/env python3
"""CI entry points: Horizon's own shader tool, the check, and the packaged files.

`horizon-shader` is not on PyPI: it is built from Horizon's own crates. Locally it usually already
sits in `~/.local/bin`; on a runner this script downloads Horizon at the commit pinned below and
builds it once into `.ci/`, so a release is always built by the same tool the registry uses.

`.ci/` holds three things, and the workflow caches the middle one:
    .ci/horizon/   the unpacked Horizon source at HORIZON_SHA
    .ci/target/    CARGO_TARGET_DIR for that build
    .ci/bin/<sha>/  the built horizon-shader, keyed by the pin

Usage:
    python3 tools/ci.py version     # the pack's version, for a tag comparison
    python3 tools/ci.py tool        # build (or find) horizon-shader, print its path
    python3 tools/ci.py check       # the authoritative check: naga, SPIR-V/Metal/HLSL, options
    python3 tools/ci.py package     # check, then dist/*.hshader + the friend zip, as JSON
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PACK = REPO / "pack"
CACHE = REPO / ".ci"
SOURCE = CACHE / "horizon"
TARGET = CACHE / "target"

# Horizon at the commit this pack is checked against. It must be a commit that serves this pack's
# `api` line: the pack is 0.2 since 2.11.0 (main retired 0.1 on 2026-11-15, `f82620a`), so the pin
# follows main. Bump it together with the manifest's `api`, never on its own: the tool is the
# authority for that line.
HORIZON_REPO = "horizon-rust/horizon"
HORIZON_SHA = "413ef02fddfac06ece3d318e88f0764fbd7d268c"  # main, shader API 0.2
HORIZON_CRATE = "horizon-shader-api"
HORIZON_BIN = "horizon-shader"

# The built tool is keyed by the pin: a cache from another pin (another API line) must never be
# reused, which is what happened when main moved from 0.1 to 0.2 under a cached binary.
BIN = CACHE / "bin" / HORIZON_SHA[:12] / HORIZON_BIN


def version() -> str:
    with (PACK / "horizon-shaders.toml").open("rb") as fh:
        return str(tomllib.load(fh)["version"])


def fetch_source() -> None:
    """Unpack Horizon into .ci/horizon, replacing whatever sits there."""
    url = f"https://codeload.github.com/{HORIZON_REPO}/tar.gz/{HORIZON_SHA}"
    print(f"downloading {url}", file=sys.stderr, flush=True)
    request = urllib.request.Request(url, headers={"User-Agent": "vanilla-horizon-ci"})
    with urllib.request.urlopen(request, timeout=600) as response:
        payload = response.read()
    print(f"{len(payload) // 1024} KiB", file=sys.stderr, flush=True)

    with tempfile.TemporaryDirectory(dir=CACHE) as scratch:
        scratch = Path(scratch)
        archive = scratch / "horizon.tar.gz"
        archive.write_bytes(payload)
        with tarfile.open(archive) as tar:
            tar.extractall(scratch, filter="data")
        unpacked = next(p for p in scratch.iterdir() if p.is_dir())
        if SOURCE.exists():
            shutil.rmtree(SOURCE)
        shutil.move(str(unpacked), str(SOURCE))
    if not (SOURCE / "Cargo.toml").exists():
        raise SystemExit(f"error: {SOURCE}/Cargo.toml is missing after unpacking")


def build_tool() -> None:
    fetch_source()
    command = ["cargo", "build", "-p", HORIZON_CRATE, "--bin", HORIZON_BIN, "--manifest-path", str(SOURCE / "Cargo.toml")]
    if (SOURCE / "Cargo.lock").exists():
        command.append("--locked")
    print(" ".join(command), file=sys.stderr, flush=True)
    subprocess.run(command, check=True, env={**os.environ, "CARGO_TARGET_DIR": str(TARGET)})
    built = TARGET / "debug" / HORIZON_BIN
    if not built.exists():
        raise SystemExit(f"error: {built} was not built")
    BIN.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(built, BIN)


def ensure_tool() -> str:
    """`horizon-shader` from PATH (a developer machine), from `.ci/` (a warm cache), or built now."""
    found = shutil.which(HORIZON_BIN)
    if found:
        return found
    if BIN.exists():
        return str(BIN)
    CACHE.mkdir(parents=True, exist_ok=True)
    build_tool()
    return str(BIN)


def check() -> None:
    # The tool's report goes to stderr, stdout stays clean for `package`'s JSON.
    subprocess.run([ensure_tool(), "check", str(PACK)], check=True, stdout=sys.stderr)


def package() -> dict[str, str]:
    """stdout: one JSON object. Everything else — the check's report, the packer's lines — to stderr."""
    check()
    result = subprocess.run(
        [sys.executable, str(REPO / "tools" / "pack.py"), "--json", "--no-link"],
        capture_output=True,
        text=True,
        check=True,
    )
    sys.stderr.write(result.stdout)
    data = json.loads(result.stdout.strip().splitlines()[-1])
    print(json.dumps(data))
    return data


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    if command == "version":
        print(version())
    elif command == "tool":
        print(ensure_tool())
    elif command == "check":
        check()
    elif command == "package":
        package()
    else:
        print(f"unknown command {command!r}: use version, tool, check or package", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
