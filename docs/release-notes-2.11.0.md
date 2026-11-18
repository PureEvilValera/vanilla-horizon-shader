# Vanilla Horizon 2.11.0

The pack moved to **shader API 0.2** — the line every current Horizon build serves, since 0.1 was
retired on 2026-11-15. Same pack, same look, linear light underneath.

The previous release, 2.10.2, was a 0.1 pack and is kept in `dist/` for builds that still serve that
line (e.g. nightly 13.11.2026). Install this one if your Horizon refuses
`needs shader API 0.1; this Horizon serves 0.2`.

## Install

1. Start Horizon with the frame 0.2 packs are drawn on:

   ```sh
   HORIZON_HDR_FRAME=float ~/Minecraft/horizon-launcher
   ```

2. Horizon → Options → Horizon Settings → Shader Packs → **Open Pack Folder**, put
   `vanilla_horizon-2.11.0.hshader` there.
3. Reopen the page and pick **Vanilla Horizon**.

## What the 0.2 port changed

- `api = "0.2"`; `[material] fog = false` became `[frame] fog = "pack"`, and the pack asks Horizon's
  own `vanilla_fog(position)` for the density instead of `frame.fog_start`/`fog_end`.
- Vanilla's surface is `albedo * tint * input.shade * input.ao * lightmap`: 0.2 hands the face's
  shade and the ambient occlusion as fields of their own.
- Every colour is linear light, so the gamma-tuned constants were converted with the 2.2 power.
- `shoulder()` is gone. The picture goes through a `[tonemap]` stage with **`Tone curve`** (0 clips at
  white the way the game does, 1 is the filmic curve, default 0.25) and **`Exposure`**. The curve works
  on luminance only, so a sunset keeps its hue instead of going crimson.
- The post chain clamps to `frame.headroom`, not to white.

## Also since 2.10.2

- **Skyline haze** no longer samples the picture for the sky: the sun, the moon and the stars used to
  be painted onto the far terrain and came out doubled at a silhouette. It fades to vanilla's fog
  colour by distance now.
- **Far water** and **Far water distance**: the end of the loaded chunks no longer cuts a lake off;
  its colour and its alpha both go to the horizon.
- **Block glow** is one setting, `Block light colour` — the colour the torches, the lanterns, the
  glowstone and the crystals cast, brightness untouched.
- **Cave fog**: 0 clears the fog out of the caves and the cellars, where vanilla's render-distance fog
  used to sit like a fog bank.
- **Ground mist**, with `Dawn mist`, `Dusk mist`, `Night mist`, `Midnight mist`, `Mist height` and
  `Mist distance`: the night splits into the evening right after the sunset and the small hours, and
  the two cross over. Night mist is moonlit grey-blue, not the black of vanilla's midnight fog.
- A few settings were dropped rather than added: the per-group glow colours, the flicker damping and
  the wet-ground sheen all turned out to look wrong, and the format allows 64 options in all.

## Checks

- `horizon-shader` built from Horizon `main` (`pub const API = "0.2"`):
  `vanilla_horizon 2.11.0 (shader API 0.2): ok`.
- 53 overrides, 55 options, every option reachable from the first settings page.

`vanilla_horizon-2.11.0.hshader` — SHA-256
`f734a1344f058ba54b4a790250d9d85c991c48f8d6a087a88d567180a13149ee`

## Known issues

- Mobs and dropped items are drawn by the game, not by the pack, so the pack's fog and its warm tint
  do not reach them. An `[entity]` stage in 0.2 is the fix; it is next.

## Licence

MIT — see `LICENSE.txt`.
