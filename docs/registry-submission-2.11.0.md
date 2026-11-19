# What was in `horizon-mods` PR #1103 (our 2.10.2 entry)

Taken from https://github.com/horizon-rust/horizon-mods/pull/1103 (merged; opened by the submission form
on behalf of `PureEvilValera`). It changed exactly six kinds of files:

```
mods/vanilla_horizon.toml                  # the entry, 20 lines
icons/vanilla_horizon.png                  # 233 301 bytes
screenshots/vanilla_horizon/1.jpg … 7.jpg  # 7 pictures, 300–760 KB each, five .jpg, one .png
```

Nothing else: no source, no `.hshader` — the file is attached to a release of *our* repository and only
its URL and SHA-256 are referenced.

## The entry as it was, and as 2.11.1 makes it

```toml
id = "vanilla_horizon"
kind = "shader"
name = "Vanilla Horizon"
summary = "Vanilla Minecraft's light, plus real sunrises and sunsets, water and rain."
description = "Vanilla's own light is the base: the sun and the moon cast shadows on top of it, the blocks the low sun reaches turn warm, rays spill across the horizon, and the air near the ground takes the hour's colour. The water, the rain and the glowing blocks are the pack's own."
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
version = "2.11.1"
published = "2026-11-19"
game = "26.3"
file = "vanilla_horizon-2.11.1.hshader"
sha256 = "a502e6cf3584b732f7e49dec74300b5fcbe051596ee604d387abddce85c7b1e3"
changelog = """
Moved to shader API 0.2: linear light, [frame] fog = "pack", vanilla_fog(), the face's shade and
ambient occlusion as fields of their own, and a [tonemap] stage with Tone curve and Exposure.
Fixed the doubled sun and moon at a silhouette (Skyline haze no longer samples the picture).
Far water and Far water distance keep the end of the loaded chunks from cutting a lake off.
Cave fog clears the render-distance fog out of the caves.
Ground mist for the dawn, the dusk and the night, with its own height and distance.
"""
```

The seven pictures of the 2.10.2 submission stay as they are — they still exist in the registry
(`1.jpg`, `2.jpg`, `3.png`, `4.jpg` … `7.jpg`), so the entry lists exactly those. Files of our own are
only needed to *replace* a picture: `screenshots/registry/1..8.jpg` in this repository are already
JPEG under the 1 MiB limit, and adding one means adding it to the same pull request.

## What the form asks for

`https://playhorizon.dev/mods/submit` takes, for an existing project:

| Field | Value for 2.11.1 |
| --- | --- |
| Project | `vanilla_horizon` (existing, archived at 0.1 — this is the reactivation) |
| Version | `2.11.1` |
| Game | `26.3` |
| File | `vanilla_horizon-2.11.1.hshader`, 31 346 bytes |
| SHA-256 | `a502e6cf3584b732f7e49dec74300b5fcbe051596ee604d387abddce85c7b1e3` |
| Signed | no |
| Source | `https://github.com/PureEvilValera/vanilla-horizon-shader` |
| Licence | `MIT` |
| Categories | `vanilla-like`, `atmosphere`, `shadows` |
| Icon | the existing `icons/vanilla_horizon.png` is reused (square, 233 KB) |
| Screenshots | keep the seven already in the registry (`…/3.png`, not `.jpg`); our own are optional replacements |

The file itself must already be downloadable from a release of our repository, because the registry
stores a link, not the bytes in the PR:

```
https://github.com/PureEvilValera/vanilla-horizon-shader/releases/download/v2.11.1/vanilla_horizon-2.11.1.hshader
```

## The archived-id gate

`vanilla_horizon` was moved to `archive/api-0.1/mods/vanilla_horizon.toml` when Horizon retired 0.1
(`f82620a`). Reactivating an archived id needs a new version and the owner's own account: the check
compares GitHub's numeric id against the archived `owner_ids` (`130057984`), and the form's bot cannot
pass that. If the form's PR fails the check, open the PR by hand from `PureEvilValera` — the entry
above is what it should contain.
