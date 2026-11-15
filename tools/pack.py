#!/usr/bin/env python3
"""Package the pack: the .hshader and the friend-ready zip in dist/, plus the live symlink.

Horizon reads a folder holding `horizon-shaders.toml` or a zip of it renamed `.hshader`, and
re-checks a symlinked folder every half second, rebuilding the changed stage. So the workflow is:
edit `pack/`, look at the game, keep the last good stage on error; this script only makes the
distributable files (and, on a developer machine, points shaderpacks/ at `pack/` for hot reload).

The pack root may hold only what the format allows (see pack/README.md); AGENTS.md, tools/ and
dist/ live beside it, not in it.

Usage:
    python3 tools/pack.py                 # dist/ + the live symlink
    python3 tools/pack.py --no-link       # dist/ only (CI)
    python3 tools/pack.py --json          # one JSON line on stdout, for CI
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tomllib
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PACK = REPO / "pack"
DIST = REPO / "dist"
SHADERPACKS = Path.home() / ".local/share/horizon/shaderpacks"


def manifest() -> dict[str, object]:
    with (PACK / "horizon-shaders.toml").open("rb") as fh:
        return tomllib.load(fh)


def pack_files() -> list[Path]:
    return sorted(p for p in PACK.rglob("*") if p.is_file())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(version: str, pack_id: str) -> dict[str, str]:
    """Write dist/<id>-<version>.hshader and the friend-ready zip; return their paths and hashes."""
    files = pack_files()
    DIST.mkdir(parents=True, exist_ok=True)
    archive = DIST / f"{pack_id}-{version}.hshader"
    official = shutil.which("horizon-shader")
    if official:
        # Horizon's own packer, so the zip and its sha256 are the ones the registry would build.
        result = subprocess.run(
            [official, "pack", str(PACK), "--out", str(archive)], capture_output=True, text=True
        )
        if result.returncode != 0:
            sys.stderr.write(result.stdout + result.stderr)
            raise SystemExit(result.returncode)
        print(result.stdout.strip())
    else:
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
            for path in files:
                zf.write(path, path.relative_to(PACK).as_posix())
        print(f"wrote {archive} ({len(files)} files)")

    # The archive to hand to someone else: the pack as a folder to unzip into shaderpacks/, plus
    # its install note beside it (never inside: a pack root may hold only the pack's own files).
    friendly = DIST / f"vanilla-horizon-shader-{version}.zip"
    with zipfile.ZipFile(friendly, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in files:
            zf.write(path, pathlib.PurePosixPath(pack_id) / path.relative_to(PACK))
        note = REPO / "tools" / "УСТАНОВКА.txt"
        if note.exists():
            zf.write(note, "УСТАНОВКА.txt")

    return {
        "version": version,
        "file": str(archive),
        "sha256": sha256(archive),
        "zip": str(friendly),
        "zip_sha256": sha256(friendly),
    }


def link_shaderpacks(pack_id: str) -> int:
    """Point shaderpacks/<id> at pack/ for hot reload; never hijack someone else's install."""
    link = SHADERPACKS / pack_id
    if not SHADERPACKS.parent.exists():
        print("no Horizon install here, not linking")
        return 0
    SHADERPACKS.mkdir(parents=True, exist_ok=True)
    if link.is_symlink():
        if os.readlink(link) != str(PACK):
            print(f"error: {link} points at {os.readlink(link)}, not {PACK}")
            return 1
        print(f"symlink ok: {link} -> {PACK}")
    elif link.exists():
        print(f"error: {link} is a real directory; remove it to hot-reload from {PACK}")
        return 1
    else:
        link.symlink_to(PACK)
        print(f"symlinked {link} -> {PACK}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="one JSON line on stdout")
    parser.add_argument("--no-link", action="store_true", help="build dist/ only, no live symlink")
    args = parser.parse_args()

    data = manifest()
    result = build(str(data["version"]), str(data["id"]))
    print(f"sha256 {result['sha256']}")
    print(f"wrote {result['zip']} ({Path(result['zip']).stat().st_size} bytes)")

    code = 0 if args.no_link else link_shaderpacks(str(data["id"]))
    if args.json:
        print(json.dumps(result))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
