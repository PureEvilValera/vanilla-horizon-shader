# Submitting to the Horizon registry without the web form

The form at `playhorizon.dev/mods/submit` runs an older bundled checker and rejects `[frame] fog`,
which the registry's own pinned revision accepts. Until that is fixed, the submission is a pull
request made by hand, entirely in the browser.

## What the pull request must contain

Into a fork of `horizon-rust/horizon-mods`, one file added:

```
mods/vanilla_horizon.toml      # from docs/registry-entry-2.11.0.toml of this repository
```

Nothing else. `icons/vanilla_horizon.png` and `screenshots/vanilla_horizon/1..7` already exist in the
registry from the 2.10.2 submission and stay as they are; the entry keeps pointing at them (note `3.png`, not `.jpg`). The pack
file itself is never committed — the entry carries its URL and SHA-256.

The entry as it should be added:

```toml
id = "vanilla_horizon"
kind = "shader"
name = "Vanilla Horizon"
summary = "Vanilla Minecraft's light, plus real sunrises and sunsets, water and rain."
description = "…"                                  # see the file; 50–10 000 chars
authors = ["PureEvilValera"]
owners = ["PureEvilValera"]
owner_ids = [130057984]
license = "MIT"
source = "https://github.com/PureEvilValera/vanilla-horizon-shader"
icon = "icons/vanilla_horizon.png"
categories = ["vanilla-like", "atmosphere", "shadows"]
screenshots = [
    "screenshots/vanilla_horizon/1.jpg",
    "screenshots/vanilla_horizon/2.jpg",
    "screenshots/vanilla_horizon/3.png",
    "screenshots/vanilla_horizon/4.jpg",
    "screenshots/vanilla_horizon/5.jpg",
    "screenshots/vanilla_horizon/6.jpg",
    "screenshots/vanilla_horizon/7.jpg",
]

[[versions]]
version = "2.11.0"
published = "2026-11-19"
game = "26.3"
file = "vanilla_horizon-2.11.0.hshader"
sha256 = "f734a1344f058ba54b4a790250d9d85c991c48f8d6a087a88d567180a13149ee"
changelog = "…"
```

## Steps, in the browser only

1. **Check the release first.** `https://github.com/PureEvilValera/vanilla-horizon-shader/releases/tag/v2.11.0`
   must carry `vanilla_horizon-2.11.0.hshader`, 30 963 bytes, digest
   `sha256:f734a1344f058ba54b4a790250d9d85c991c48f8d6a087a88d567180a13149ee`. A different digest means
   the file was packaged by something other than `horizon-shader pack`; do not submit it.

2. **Fork** `horizon-rust/horizon-mods` (Fork button). Work in the browser: in your fork open
   `mods/` → **Add file** → **Create new file** → name `vanilla_horizon.toml` → paste the entry →
   **Commit changes** (choose “Create a new branch for this commit”, branch `add-vanilla-horizon-2.11.0`).

3. **Open the PR** from that branch into `horizon-rust/horizon-mods:main`. Title:
   `Add vanilla_horizon 2.11.0 (reactivation, shader API 0.2)`. Body: what changed, the release URL,
   and one line saying it is the archived project brought back on the 0.2 line.

4. **Checks.** The registry's CI builds `horizon-shader` from its pinned revision
   (`.github/horizon-rev`), runs `registry review` and `registry check` on the new file. It also
   verifies the sha256 by downloading the release asset. A red check is a real problem; the log names
   the field.

5. **The archived-id gate.** `vanilla_horizon` lives in `archive/api-0.1/mods/vanilla_horizon.toml`.
   Reactivating it compares the GitHub numeric id of the PR's author with the archived `owner_ids`
   (`130057984`). A PR opened by the owner passes; the submit form's bot never does. Do not rename the
   id and do not remove the archived file.

6. **After the merge**, the entry appears in `mods/vanilla_horizon.toml` and in the built
   `index.json`; the launcher offers 2.11.0 to any Horizon that serves shader API 0.2.

## If a check fails

- **`sha256` mismatch** — the release asset was rebuilt after the entry was written; take the digest
  from the release page (the API shows `digest`) and fix the entry.
- **`needs shader API …`** — the uploaded file is built for another API line; rebuild with
  `python3 tools/pack.py` using the checker of the line the registry pins.
- **`description` / `summary` limits** — 50–10 000 and ≤160 characters after trimming.
- **`screenshots` / `icon`** — they must exist at the paths the entry names; the ones from 2.10.2 do.

## Why not the form

The form bundles an older `horizon-shader` that does not know `[frame] fog` (added to API 0.2 in
mid-November) and answers `unknown field 'fog', expected 'blend' or 'primaries'`. Our manifest needs
that key: without it Horizon fogs the material stage itself and the pack's own haze (the dawn/dusk
colour, `Cave fog`, the ground mist) either doubles or stops working. The registry's pinned revision
already accepts the key, so the pull request passes even though the form does not.
