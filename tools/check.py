#!/usr/bin/env python3
"""Static checks for a Horizon shader pack, standing in for `horizon-shader check`.

Horizon itself validates a pack with naga; this machine has neither Horizon's CLI nor a Rust
toolchain, so what can be checked offline is checked here:

  * the manifest parses and has the required keys;
  * every file the manifest points at exists;
  * every `override` in those files has a `[[options]]` entry of the same id and type,
    and every such entry is used by an override;
  * no `override` id is declared twice across the pack;
  * braces and parentheses balance in every WGSL file.

Usage: python3 tools/check.py [pack dir]   (default: the directory above tools/)
"""

from __future__ import annotations

import sys
import tomllib
from pathlib import Path

TYPE_MAP = {"f32": "float", "f64": "float", "bool": "bool", "u32": "choice", "i32": "int"}
REQUIRED = ("schema", "id", "name", "version", "api")


def pack_files(manifest: dict[str, object]) -> list[str]:
    files: list[str] = []
    shared = manifest.get("shared", [])
    if isinstance(shared, list):
        files += [str(f) for f in shared]
    for stage in ("sky", "material", "vertex", "weather"):
        block = manifest.get(stage)
        if isinstance(block, dict) and "file" in block:
            files.append(str(block["file"]))
    for post in manifest.get("post", []):
        if isinstance(post, dict):
            if "file" in post:
                files.append(str(post["file"]))
            files += [str(f) for f in post.get("files", [])]
    return list(dict.fromkeys(files))


def overrides(text: str) -> list[tuple[str, str]]:
    found = []
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("override ") and ":" in line:
            head = line[len("override ") :]
            name, rest = head.split(":", 1)
            found.append((name.strip(), rest.split("=")[0].strip().rstrip(";")))
    return found


def balanced(text: str, opener: str, closer: str) -> bool:
    depth = 0
    for ch in text:
        if ch == opener:
            depth += 1
        elif ch == closer:
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "pack"
    manifest_path = root / "horizon-shaders.toml"
    errors: list[str] = []
    try:
        manifest = tomllib.loads(manifest_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"error: {manifest_path} does not exist")
        return 1
    except tomllib.TOMLDecodeError as exc:
        print(f"error: {manifest_path}: {exc}")
        return 1

    for key in REQUIRED:
        if key not in manifest:
            errors.append(f"manifest: missing {key!r}")

    options: dict[str, str] = {}
    for opt in manifest.get("options", []):
        opt_id = str(opt.get("id", ""))
        opt_type = str(opt.get("type", ""))
        options[opt_id] = opt_type
        if opt_type not in ("float", "bool", "int", "choice"):
            errors.append(f"option {opt_id}: unknown type {opt_type!r}")
        elif opt_type == "choice" and not opt.get("values"):
            errors.append(f"option {opt_id}: a choice needs values")

    for path in sorted(root.iterdir()):
        if path.name.startswith("."):
            continue
        if path.is_dir() or path.suffix in (".wgsl", ".png"):
            continue
        if path.name in ("horizon-shaders.toml", "README.md", "LICENSE", "LICENSE.md", "LICENSE.txt"):
            continue
        errors.append(f"{path.name}: the pack root may hold only the manifest, .wgsl, [[textures]] PNGs, README.md, LICENSE*, icon.png")

    declared: dict[str, str] = {}
    for name in pack_files(manifest):
        path = root / name
        if not path.exists():
            errors.append(f"{name}: listed in the manifest but missing")
            continue
        text = path.read_text(encoding="utf-8")
        for opener, closer in (("{", "}"), ("(", ")"), ("[", "]")):
            if not balanced(text, opener, closer):
                errors.append(f"{name}: unbalanced {opener}{closer}")
        seen_here: set[str] = set()
        for ov_name, ov_type in overrides(text):
            if ov_name in seen_here:
                errors.append(f"{name}: override {ov_name} declared twice")
            seen_here.add(ov_name)
            if ov_name in declared and declared[ov_name] != ov_type:
                errors.append(f"{name}: override {ov_name} is {ov_type}, declared {declared[ov_name]} elsewhere")
            declared[ov_name] = ov_type
            if ov_name not in options:
                errors.append(f"{name}: override {ov_name} has no [[options]] entry")
            elif TYPE_MAP.get(ov_type) != options[ov_name]:
                errors.append(
                    f"{name}: override {ov_name} is {ov_type} but the option is {options[ov_name]}"
                )

    shadow = manifest.get("shadow", {})
    exempt = {str(shadow.get("resolution_option", "")), str(shadow.get("distance_option", ""))}
    # [[pages]]: the first page opens, and every option must be reachable from it.
    pages = {str(page.get("id")): page for page in manifest.get("pages", [])}
    if pages:
        first = manifest["pages"][0]
        listed: set[str] = set()
        for page in manifest["pages"]:
            for item in page.get("items", []):
                item = str(item)
                if item.startswith("page:"):
                    if item[len("page:") :] not in pages:
                        errors.append(f"page {page.get('id')}: item {item} names no page")
                elif item:
                    listed.add(item)
        for opt_id in options:
            if opt_id not in listed and opt_id not in exempt:
                errors.append(f"option {opt_id}: not on any [[pages]] item list")
        if not pages.get(str(first.get("id"))):
            errors.append("pages: the first page is missing")

    for opt_id in options:
        if opt_id not in declared and opt_id not in exempt:
            errors.append(f"option {opt_id}: declared in the manifest, unused by any shader")

    print(f"{len(declared)} overrides, {len(options)} options, {len(pack_files(manifest))} files")
    for err in errors:
        print(f"error: {err}")
    print("ok" if not errors else f"{len(errors)} error(s)")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
