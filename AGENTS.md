# AGENTS.md — vanilla-horizon

A Horizon shader pack in WGSL (`schema = 1`, shader API 0.1). Vanilla's own light is the base; the
sun, the moon, shadows, the sky's glow, water, rain and block glow are added on top.

## Layout

- `pack/` — the pack, and the only thing Horizon sees: `horizon-shaders.toml`, the `.wgsl` files,
  `README.md`, `LICENSE.txt`. Anything else in there fails the check (`a pack holds only
  horizon-shaders.toml, .wgsl files, ...`).
- `screenshots/` — README images, 1440 px wide.
- `docs/release-notes-<version>.md` — the body of each GitHub release; the workflow picks it up by
  the tag's version.
- `dist/` — the built `.hshader` and the friend-ready `.zip`, both committed on purpose: the release
  uploads the same bytes the repository holds.
- `tools/check.py` — fast pre-flight (manifest parses, options ↔ overrides and types, every option on
  some `[[pages]]` entry, pack-root whitelist).
- `tools/pack.py` — builds `dist/` (via `horizon-shader pack` when present) and, on a developer
  machine, points `shaderpacks/<id>` at `pack/` for hot reload. `--no-link` and `--json` are for CI.
- `tools/ci.py` — builds `horizon-shader` from the pinned Horizon commit into `.ci/` when it is not
  on PATH, then runs the check and the package step.
- `.github/workflows/check.yml` (push, PR) and `release.yml` (tags `v*`).

On this machine `horizon-shader` sits in `~/.local/bin`; the live pack is symlinked from
`~/.local/share/horizon/shaderpacks/vanilla_horizon`. Options are saved by the game in
`shaderpacks/.horizon-options/vanilla_horizon.txt`.

## Workflow

```sh
python3 tools/check.py                  # seconds: manifest, options, pages, pack root
python3 tools/ci.py check               # authoritative: naga, SPIR-V/Metal/HLSL, options at min/max
python3 tools/ci.py package             # both files in dist/, JSON on stdout
python3 tools/pack.py                   # same, plus the live symlink
```

Release: bump `version` in `pack/horizon-shaders.toml` (and nothing else versioned), add
`docs/release-notes-<version>.md`, commit, `git tag -a v<version>`, push the tag. `release.yml` then
verifies the tag against the manifest, checks, packages, and attaches
`dist/vanilla_horizon-<version>.hshader` and `dist/vanilla-horizon-shader-<version>.zip`.

`HORIZON_SHA` in `tools/ci.py` pins the Horizon the tool is built from. Bump it only together with
the manifest's `api` line — the tool is the authority for that line.

## Design

- **Vanilla's surface first.** `material` returns `albedo * tint * lightmap`, then adds direct light
  weighted by `n·l`, by how much sky the face sees (`open`) and by the shadow map; a shadow takes
  back a bounded share of the sky light (`SHADE × Shadow depth`). Caves, torches and the night keep
  vanilla's brightness.
- **Dawn and dusk are separate.** `common.wgsl`: `sun_side()` weights the dawn (sun in the east,
  `x > 0`) and the dusk by the sun's elevation, `side_mix(dawn_*, dusk_*)` blends one setting, and
  `sun_low()` is 0 with the sun below the horizon — which keeps a setting moon out of the sunset's
  orange. The night has `moon_strength`, `moon_tint`, `moon_glow` and moon-cast shadows of its own.
- **Stages:** `sky` (sun glow near the horizon, moon halo; the sun quad, moon, stars and clouds stay
  the engine's), `material` (terrain light, water, rain on the ground, block glow, coloured block
  light, carried lights), `vertex` (waving plants), `weather` (rain and snow colour).
- **Post chain, in order:** `rays` (quarter size, `vh_rays`) → `glow_prefilter` → `glow_blur` →
  `frame`, which adds the rays and the glow, applies the skyline fade (`surface_at` tells terrain
  from entities, so mobs and dropped items take the hour's tint too), and tints non-terrain pixels.
  A `[[post]]` chain switches the player's TAA/FXAA off; the pack draws no anti-aliasing.
- **Fog is the pack's** (`[material] fog = false`): vanilla's `fog_start`/`fog_end`, `Day fog` by day,
  vanilla's thickness plus the low sun's colour at dawn and dusk (`*_haze`), warmest near the ground.
- **Shadows:** `[shadow] option = "shadows"`, `resolution_option`, `distance_option` (choice options
  whose values are the numbers as strings; exempt from needing an override).
- **Pages** group the options: Sky and clouds · Dawn · Dusk · Moon · Light and shadows · Block glow ·
  Water · Rain · Nature. Every option must be reachable and used, or `tools/check.py` complains.

## Conventions

- An `[[options]]` entry must be an `override` of its type in some stage: bool, f32, `int` → i32,
  `choice` → u32 index.
- `[material]` and `[vertex]` share one module: an `override` goes in one of them or in `shared`,
  never both.
- Options are pipeline constants: `if <option>` is folded at build time, so it is a real perf knob.
- Colours in `[[lights]]` are vanilla gamma; the pack normalises by luma before mixing, so brightness
  never changes — only hue.
