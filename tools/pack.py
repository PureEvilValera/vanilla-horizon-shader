#!/usr/bin/env python3
"""Package the pack: a .hshader in dist/, and the live symlink Horizon hot-reloads.

Horizon reads a folder holding `horizon-shaders.toml` or a zip of it renamed `.hshader`, and
re-checks a symlinked folder every half second, rebuilding the changed stage. So the workflow is:
edit `pack/`, look at the game, keep the last good stage on error; `pack.py` only makes the
distributable zip.

The pack root may hold only what the format allows (see pack/README.md); AGENTS.md, tools/ and
dist/ live beside it, not in it.

Usage: python3 tools/pack.py
"""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import pathlib
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PACK = REPO / "pack"
DIST = REPO / "dist"
SHADERPACKS = Path.home() / ".local/share/horizon/shaderpacks"
VERSION = "2.10.2"
PACK_ID = "vanilla_horizon"


def pack_files() -> list[Path]:
    return sorted(p for p in PACK.rglob("*") if p.is_file())


def main() -> int:
    manifest = PACK / "horizon-shaders.toml"
    if not manifest.exists():
        print(f"error: {manifest} is missing")
        return 1

    files = pack_files()
    DIST.mkdir(parents=True, exist_ok=True)
    archive = DIST / f"{PACK_ID}-{VERSION}.hshader"
    official = shutil.which("horizon-shader")
    if official:
        # Horizon's own packer, so the zip and its sha256 are the ones the registry would build.
        result = subprocess.run(
            [official, "pack", str(PACK), "--out", str(archive)], capture_output=True, text=True
        )
        if result.returncode != 0:
            print(result.stdout + result.stderr)
            return result.returncode
        print(result.stdout.strip())
    else:
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
            for path in files:
                zf.write(path, path.relative_to(PACK).as_posix())
        print(f"wrote {archive} ({len(files)} files)")
    print(f"sha256 {hashlib.sha256(archive.read_bytes()).hexdigest()}")

    # The archive to hand to someone else: the pack as a folder to unzip into shaderpacks/, plus
    # its install note beside it (never inside: a pack root may hold only the pack's own files).
    friendly = DIST / f"vanilla-horizon-shader-{VERSION}.zip"
    with zipfile.ZipFile(friendly, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in files:
            zf.write(path, pathlib.PurePosixPath(PACK_ID) / path.relative_to(PACK))
        note = REPO / "tools" / "УСТАНОВКА.txt"
        if note.exists():
            zf.write(note, "УСТАНОВКА.txt")
    print(f"wrote {friendly} ({friendly.stat().st_size} bytes)")

    link = SHADERPACKS / PACK_ID
    SHADERPACKS.mkdir(parents=True, exist_ok=True)
    if link.is_symlink():
        if os.readlink(link) != str(PACK):
            print(f"error: {link} points at {os.readlink(link)}, not {PACK}")
            return 1
        print(f"symlink ok: {link} -> {PACK}")
    elif link.exists():
        print(f"error: {link} is a real directory; remove it to hot-reload from {PACK}")
    else:
        link.symlink_to(PACK)
        print(f"symlinked {link} -> {PACK}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
