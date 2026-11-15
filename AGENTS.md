# AGENTS.md — vanilla-horizon

A Horizon shader pack (WGSL). Vanilla's own look, untouched; only the water changes. Started as a
fork of Wisdom Shaders V3 Lite (Horizon port) 1.3.7, whose code now sits in `backup/`.

## Layout

- `pack/` — the pack, and the only thing Horizon sees: `horizon-shaders.toml`, `.wgsl`,
  `README.md`, `LICENSE.txt`. Anything else in there fails the check
  (`a pack holds only horizon-shaders.toml, .wgsl files, ...`).
- `~/.local/share/horizon/shaderpacks/vanilla_horizon` — symlink to `pack/`; the game re-checks it
  every half second and rebuilds the changed stage, keeping the last good one and printing errors
  into chat. Options live in `shaderpacks/.horizon-options/vanilla_horizon.txt`.
- `dist/` — the `.hshader` from `tools/pack.py`; do not install it beside the symlink (two packs,
  one id).
- `backup/pack-0.2.0/` — the previous, Wisdom-shaped pack (atmosphere, 2D clouds, AgX, shadow map,
  its own light model); `backup/material.wisdom-light.wgsl` the same for the light.
- `tools/check.py` — fast pre-flight (manifest, options ↔ overrides, pack-root files).
  `tools/pack.py` — `dist/` via `horizon-shader pack` when installed.

## Workflow

```
horizon-shader check pack      # authoritative: naga, SPIR-V/Metal/HLSL, options at min/max
python3 tools/check.py         # pack-root files, options ↔ overrides, types
python3 tools/pack.py          # dist/*.hshader + sha256, and the live symlink
```

`horizon-shader` (in `~/.local/bin`) was built from a tarball of `horizon-rust/horizon` with
`cargo build -p horizon-shader-api --bin horizon-shader` (rustup, minimal profile). The sources in
`/tmp` do not survive a reboot: re-download, rebuild, copy again.

## Manifest shape (0.4.0)

`[[pages]]` group the options: `main` → `Light and shadows` → `Water` → `Nature`. Every option must
be listed on some page (`tools/check.py` verifies this), and `[shadow]` names `shadow_resolution` /
`shadow_distance` as `resolution_option` / `distance_option` (choice options whose values are the
numbers as strings; the check exempts them from needing an override). `[[post]]` chain: `post/rays.wgsl`
(quarter size, target `vh_rays`) then `post/frame.wgsl`, which reads `vh_rays` by name.

## Design

- **`material` draws vanilla's surface first** (`albedo * tint * lightmap`), then adds the direct
  light and lets shadows take back a bounded share of sky light (`SHADE` in `common.wgsl`), the way
  Petalveil does it. Sun and moon are `sun_strength` / `moon_strength`, the hue is `sun_warmth`.
- **No sky or weather stage**: vanilla's sky, clouds, sun, moon, stars, rain and fog stay the game's.
- **Water** keeps vanilla's colour and light, and adds: waves in the normals only (top face,
  `input.face == 1u`), fresnel mix to Horizon's `reflection` mirror (`[reflection] option`), a
  `pow(300)` sun glint along `frame.light_direction`, and alpha thinned from vanilla's by
  `water_transparency` (the translucent pass then really shows the world behind).
- Options: `water_reflections` (also the `[reflection] option`), `reflection_strength`,
  `water_transparency`, `water_waves`, `sun_glint`, `waving_plants` (off: vanilla stands still).
- `[material] fog` is absent, so Horizon fogs surfaces with vanilla's fog.

## Dawn, dusk, moon

`common.wgsl` owns the split: `sun_side()` returns the dawn's and the dusk's weights — the sun's
elevation gates both (`sun_low()`), and its `x` sign picks the side (east is dawn). `side_mix(a, b)`
blends one value from the `dawn_*` and `dusk_*` options; `sun_low()` is 0 with the sun below the
horizon, which is what keeps a setting moon out of the sunset's orange. The moon has `moon_strength`,
`moon_tint` and `moon_glow` of its own, and `nightfall()` gates its halo.

Defaults track the settings the user tuned by hand: dawn glow 0.7 / size 0.3 / haze 0 / warmth 0.25 /
orange 0.75 / light 0.5 / rays 0.1 / colour −0.25; dusk 0.75 / 0.2 / 0.2 / 0.5 / 2.0 / 0.3 / 0.3 /
0.5; Sunlight 2.0, Moonlight 0.3, Shadow depth 2.4, Shadow distance 64.

## Conventions

- Every `[[options]]` entry must be an `override` of its type in some stage (bool, f32, `int`→i32,
  `choice`→u32 index). Options naming the shadow map are exempt (none here).
- `[material]` and `[vertex]` share one module: an `override` goes in one of them or in `shared`,
  never both.
