# Vanilla Horizon (API 0.2) 0.2.0

The pack ported to **shader API 0.2** — the line Horizon's nightlies serve since 2026-11-15, when 0.1
was retired. Same features as the 0.1 pack, in linear light, with its own tone curve.

Install this one if your Horizon refuses `needs shader API 0.1; this Horizon serves 0.2`. On a build
that still serves 0.1 (or is old enough not to know `[[lights]]`) use `vanilla_horizon-2.10.2.hshader`
instead.

## Install

1. Start Horizon with the frame 0.2 packs are drawn on:

   ```sh
   HORIZON_HDR_FRAME=float ~/Minecraft/horizon-launcher
   ```

2. Horizon → Options → Horizon Settings → Shader Packs → **Open Pack Folder**, put
   `vanilla_horizon_02-0.2.0.hshader` in there.
3. Reopen the page and pick **Vanilla Horizon (API 0.2)**. Its id is `vanilla_horizon_02`, so it can
   sit beside the 0.1 pack and the two can be compared in the list.

## What the port changed

- `api = "0.2"`; `[material] fog = false` became `[frame] fog = "pack"`, and the pack asks Horizon's
  own `vanilla_fog(position)` for the density instead of `frame.fog_start`/`fog_end`.
- Vanilla's surface is `albedo * tint * input.shade * input.ao * lightmap` — 0.2 hands the face's
  shade and the ambient occlusion as fields of their own.
- Every colour is linear light, so the gamma-tuned constants were converted with the 2.2 power
  (`SUN_ADD` 0.18 → 0.022, `SHADE` 0.18 → 0.022, the dusk tint `(1.55, 0.80, 0.40)` → `(1.94, 0.70, 0.30)`,
  the glow's threshold 0.70 → 0.90 of linear white, and so on).
- `shoulder()` is gone: the picture goes through a `[tonemap]` stage instead, and the post chain
  clamps to `frame.headroom` rather than to white.
- **`Tone curve`** (0…1, default 0.25) blends between the game's own clip at white (0) and the filmic
  curve (1). The curve works on luminance only, so a sunset keeps its hue instead of going crimson.

## Checks

- `horizon-shader` built from Horizon `main` (`pub const API = "0.2"`): `vanilla_horizon_02 0.2.0
  (shader API 0.2): ok`.
- Every option reachable from the first settings page, every option used by its `override`.

`vanilla_horizon_02-0.2.0.hshader` — SHA-256
`54150b2fef208449c53f07fb53b0846b5bbd557903c19380652791dde012fd4d`

## Known issues

- Around dawn and dusk, where the sun slides behind a mountain or a tree line, the shafts show
  artefacts at the silhouette. The colours are settled; this is next.

## Licence

MIT — see `LICENSE.txt` inside the pack.
