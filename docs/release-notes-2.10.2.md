# Vanilla Horizon 2.10.2

Vanilla Minecraft's light, plus real sunrises and sunsets, water and rain. A shader pack for
[Horizon](https://playhorizon.dev), written in WGSL against shader API 0.1.

## Install

1. Horizon → Options → Horizon Settings → Shader Packs → **Open Pack Folder**.
2. Put `vanilla_horizon-2.10.2.hshader` in there (no unzipping), or unzip
   `vanilla-horizon-shader-2.10.2.zip` and keep its `vanilla_horizon/` folder.
3. Reopen the page and pick **Vanilla Horizon**.

Do not keep the `.hshader` and the folder at once: both carry the same id and both get listed.
Horizon's **Reset all options** restores every default.

## What is in the pack

- **Vanilla's light is the base.** Terrain draws vanilla's own `albedo * tint * lightmap`, so caves,
  torches, the night and the Brightness option behave exactly as without a pack. The sun and the
  moon only add to it, and a shadow takes back a bounded share of the sky light.
- **Sun and moon shadows** — one shadow map, cast by the sun by day and the moon by night
  (`Shadow depth`, `Shadow edges`, `Shadow detail`, `Shadow distance`).
- **Dawn and dusk, each with its own settings** — warmth, how orange the lit blocks turn, extra
  light, the glow and its size, the haze and its colour, the rays and their colour. The shader tells
  them apart by the side of the sky the sun is on, and the night is gated out of both, so a setting
  moon never paints the ground orange.
- **The moon** — its own light, cast shadows, colour and halo.
- **Water** — waves in the normals, a fresnel mirror of the world, a sun glint, its own transparency
  and raindrop rings.
- **Rain and snow** — recoloured streaks, wet ground that darkens and catches the sky, and rings of
  the drops on the ground and on the water.
- **Block glow** — four groups (torches, lava, lamps, crystals) with their own brightness and hue,
  a coloured block light from the manifest's `[[lights]]`, and carried light sources lighting the
  ground like placed ones.
- **Skyline haze** — the end of the loaded chunks fades into the sky instead of a hard band.
- **Waving plants** with separate wind for a calm hour, rain and a storm.

## Checks

- `horizon-shader check` — ok; 50 overrides, 52 options, 9 stages.
- Options reachable from the first settings page; every option is used by its `override`.

`vanilla_horizon-2.10.2.hshader` — SHA-256
`4faf2ac501b9862bff4ed27d4d60abed5bab1e20a397506981c3957d09dd7068`

## Licence

MIT. The water's waves and the swaying of the plants come from the unofficial Wisdom Shaders V3
Lite Horizon port and keep its Apache-2.0 notice, included in the pack's `LICENSE.txt`.

Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft.
