#!/usr/bin/env python3
"""CI entry points: Horizon's own shader tool, the check, and the packaged files.

`horizon-shader` is not on PyPI: it is built from Horizon's own crates. Locally it usually already
sits in `~/.local/bin`; on a runner this script downloads Horizon at the commit pinned below and
builds it once into `.ci/`, so a release is always built by the same tool the registry uses.

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
import tomllib
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PACK = REPO / "pack"
CACHE = REPO / ".ci"

# Horizon at the commit this pack was last checked against (main, 2026-11-15). Bump it together with
# a new `api` line in the manifest, never on its own: the tool is the authority for that line.
HORIZON_REPO = "horizon-rust/horizon"
HORIZON_SHA = "4626921895df51521be64d485ee763412de2917c"
HORIZON_CRATE = "horizon-shader-api"
HORIZON_BIN = "horizon-shader"


def version() -> str:
    with (PACK / "horizon-shaders.toml").open("rb") as fh:
        return str(tomllib.load(fh)["version"])


def ensure_tool() -> str:
    """`horizon-shader` from PATH (a developer machine), from `.ci/` (a warm cache), or built now."""
    found = shutil.which(HORIZON_BIN)
    if found:
        return found

    built = CACHE / "bin" / HORIZON_BIN
    if built.exists():
        return str(built)

    source = CACHE / "horizon"
    archive = CACHE / "horizon.tar.gz"
    CACHE.mkdir(parents=True, exist_ok=True)
    if not source.exists():
        url = f"https://codeload.github.com/{HORIZON_REPO}/tar.gz/{HORIZON_SHA}"
        print(f"downloading {url}", flush=True)
        urllib.request.urlretrieve(url, archive)
        with tarfile.open(archive) as tar:
            tar.extractall(CACHE, filter="data")
        unpacked = next(p for p in CACHE.iterdir() if p.is_dir() and p.name.startswith("horizon-"))
        unpacked.rename(source)
        archive.unlink()

    print("building horizon-shader", flush=True)
    subprocess.run(
        ["cargo", "build", "-p", HORIZON_CRATE, "--bin", HORIZON_BIN, "--manifest-path", str(source / "Cargo.toml")],
        check=True,
    )
    built.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / "target" / "debug" / HORIZON_BIN, built)
    return str(built)


def check() -> None:
    subprocess.run([ensure_tool(), "check", str(PACK)], check=True)


def package() -> dict[str, str]:
    check()
    result = subprocess.run(
        [sys.executable, str(REPO / "tools" / "pack.py"), "--json", "--no-link"],
        capture_output=True,
        text=True,
        check=True,
    )
    print(result.stdout.strip())
    return json.loads(result.stdout.strip().splitlines()[-1])


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
