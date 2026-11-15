# Vanilla Horizon

**Vanilla Minecraft's light, plus real sunrises and sunsets, water and rain.**

A shader pack for [Horizon](https://playhorizon.dev) — the Rust rewrite of Minecraft: Java Edition.
Vanilla's own light is the base: the sun and the moon cast shadows on top of it, the blocks the low
sun reaches turn warm, rays spill across the horizon, and the air near the ground takes the hour's
colour. The water, the rain and the glowing blocks are the pack's own.

<p align="center">
  <img src="screenshots/sunset-orange-light-on-red-sand.png" width="49%">
  <img src="screenshots/sunrise-warm-light-on-tall-grass.png" width="49%">
  <br><sub><b>Magic dusks and dawns</b></sub>
</p>

<p align="center">
  <img src="screenshots/water-mirror-at-sunset.png" width="49%">
  <img src="screenshots/noon-water-transparency-and-waves.png" width="49%">
  <br><sub><b>Adjusting water transparency, waves, and reflections</b></sub>
</p>

<p align="center">
  <img src="screenshots/storm-rain-and-dark-wet-ground.png" width="49%">
  <img src="screenshots/rain-over-river-and-meadow.png" width="49%">
  <br><sub><b>Storm, strong wind</b> · <b>Rain, light breeze</b></sub>
</p>

<p align="center">
  <img src="screenshots/night-moon-over-torch-lit-mesa.png" width="49%">
  <img src="screenshots/moonlit-forest-grass-at-night.png" width="49%">
  <br><sub><b>Spellbinding moon light</b></sub>
</p>

<p align="center">
  <img src="screenshots/lantern-glow-in-dark-meadow.png" width="70%">
  <br><sub><b>The warm light of a lantern</b></sub>
</p>

<p align="center">
  <img src="screenshots/shader-settings-menu-over-night-scene.png" width="70%">
  <br><sub><b>Detailed settings</b></sub>
</p>

## Install

1. Horizon → Options → Horizon Settings → Shader Packs → **Open Pack Folder**.
2. Drop either the `pack/` folder (with `horizon-shaders.toml` at its root) or
   `dist/vanilla_horizon-2.10.2.hshader` in there.
3. Reopen the page and pick **Vanilla Horizon**.

Options are grouped on pages: Sky and clouds · Dawn · Dusk · Moon · Light and shadows · Block glow ·
Water · Rain · Nature. Horizon's **Reset all options** puts every slider back at the pack's
defaults.

## What is in the repository

| Path | What it is |
| --- | --- |
| `pack/` | the pack itself — the only folder Horizon reads: manifest, WGSL stages, icon-free assets, licence |
| `dist/vanilla_horizon-2.10.2.hshader` | the built pack, exactly what Horizon's own packer writes |
| `dist/vanilla-horizon-shader-2.10.2.zip` | **the file to send someone**: the pack as a folder to unzip into `shaderpacks/`, with `УСТАНОВКА.txt` beside it |
| `tools/check.py` | fast pre-flight: manifest, options ↔ overrides, `[[pages]]` reachability, pack-root files |
| `tools/pack.py` | builds `dist/` with `horizon-shader pack` when it is installed |
| `screenshots/` | the images above, downscaled to 1440 px wide so the repository stays light |
| `docs/release-notes-*.md` | the body of each GitHub release |
| `AGENTS.md` | notes for whoever (or whatever) edits the pack next: layout, conventions, design decisions |

The pack root may hold only what the format allows (`horizon-shaders.toml`, `.wgsl`, `[[textures]]`
PNGs, `README.md`, `LICENSE*`, `icon.png`). Anything else in `pack/` makes Horizon refuse the whole
pack, which is why the tools and the docs live beside it, not inside.

## Releases, built by CI

Two workflows, no local tooling needed:

- `.github/workflows/check.yml` — on every push and pull request: `tools/check.py`, then Horizon's
  own check and package. It builds `horizon-shader` from the Horizon commit pinned in `tools/ci.py`
  (cached between runs) and uploads the packaged files as a build artifact.
- `.github/workflows/release.yml` — on a `v*` tag: verifies the tag against `version` in the
  manifest, checks, packages, and attaches both files to the release, with the notes taken from
  `docs/release-notes-<version>.md`.

So a release is:

```sh
# bump "version" in pack/horizon-shaders.toml, add docs/release-notes-<version>.md
git add -A && git commit -m "Vanilla Horizon <version>"
git tag -a v<version> -m "Vanilla Horizon <version>"
git push origin main v<version>
```

Both files come from the same packer the registry uses, so their SHA-256 match a local
`python3 tools/pack.py`.

## Passing it to someone else

Send `dist/vanilla-horizon-shader-2.10.2.zip`. The receiver unzips it into the Shader Packs folder,
reopens the page and picks **Vanilla Horizon** — `УСТАНОВКА.txt` inside the archive says the same in
Russian, including what not to do (renaming files inside the pack, dropping extra files into it, or
keeping both the folder and the `.hshader` of one id: Horizon refuses or duplicates the pack).

`dist/vanilla_horizon-2.10.2.hshader` is the other way round: a single file to drop in, no unzipping.

## Building

```
horizon-shader check pack     # authoritative: naga, SPIR-V/Metal/HLSL, every option at min and max
python3 tools/check.py        # fast pre-flight
python3 tools/pack.py         # dist/*.hshader + sha256, and the friend-ready .zip
```

`horizon-shader` comes from the Horizon repository:

```
cargo build -p horizon-shader-api --bin horizon-shader
```

`tools/pack.py` also points `~/.local/share/horizon/shaderpacks/vanilla_horizon` at `pack/` for hot
reload — it refuses to touch a link that already points somewhere else, so a checked-out copy never
hijacks a live install by accident (the last lines of its output will say so, and that is fine).

## Licence

MIT — see `LICENSE.txt` (also inside `pack/`, where Horizon expects it, with the Apache-2.0 notice and
text for the parts inherited from the Wisdom Shaders Horizon port).

The pack started as a fork of the unofficial Wisdom Shaders V3 Lite Horizon port (Wisdom Shaders V3
© bobcao3, Horizon port © tomasmendes01): the water's waves and the swaying of the plants come from
it and stay Apache-2.0, as its licence asks; the rest is MIT. The sun rays' march follows Petalveil
(MIT) by BarmaleyVIP.

Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft.
