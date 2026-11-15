# Vanilla Horizon

A shader pack for [Horizon](https://playhorizon.dev) (the Rust rewrite of Minecraft: Java Edition).
Vanilla's own light is the base; the sun, the moon and the shadows work on top of it, and the water
is the pack's own.

## The rule the pack follows

`albedo * tint * lightmap` — vanilla's own surface — is drawn first and whole. The sun and the moon
only *add* to it, weighted by how much sky the point sees, and the shadow map takes back only a
bounded share (`SHADE` × Shadow depth) of that sky light. So a cave, a cellar, a torch and the night
keep vanilla's brightness and colours, whatever the shadows do.

## Options, by page

The dawn and the dusk have **their own settings**, told apart by the side of the sky the sun is on
(it rises in the east, sets in the west); the moon has its own, and none of the three borrows from
the others. Night is gated out of both dawn and dusk, so a setting moon never paints the ground
with the sunset's orange.

**Dawn** — warmth, orange, light, glow, glow size, haze, rays, rays colour (defaults: 0.25 · 0.75 ·
0.5 · 0.7 · 0.3 · 0 · 0.1 · −0.25).

**Dusk** — the same eight (defaults: 0.5 · 2.0 · 0.3 · 0.75 · 0.2 · 0.2 · 0.3 · 0.5).

**Moon** — `Moonlight` (0.3), `Moon colour` (0: cool blue, 1: warm white), `Moon glow`.

**Light and shadows** — Shadows, Shadow edges (Soft), Shadow detail (2048), Shadow distance (64),
Shadow depth (2.4), Sunlight (2.0).

**Sky and clouds** — Glow (0.05).

**Water** — Water reflections, Reflection strength (0.35), Water transparency (0.2), Waves (1.0),
Sun glint (1.0).

**Nature** — Waving plants (off).

Every option can be put back at once: Horizon's own **Reset all options**, the first entry of the
pack's settings page (`shader_ui.rs`, `Item::Reset`), writes the defaults back.

## Cost

Two post passes (the rays at a quarter of the world's size, then the frame), and the shadow map at
the size and distance the options pick. The rays are gated to dawn and dusk and their march's
per-pixel noise is averaged by nine taps of the quarter-size target in the last pass, so no grain,
spokes or shafts show by day or after sunset. When the camera swings past the sun, the march starts
from the sun's side of the sky far off the frame, so the shafts thin out instead of vanishing. A `[[post]]` chain means the player's TAA/FXAA do not run;
this pack draws no anti-aliasing of its own.

## Credits

MIT, see `LICENSE.txt`. The pack started as a fork of the unofficial Wisdom Shaders V3 Lite Horizon
port (Wisdom Shaders V3 © bobcao3, Horizon port © tomasmendes01): the water's waves and the swaying
of the plants come from it and keep its Apache License 2.0, whose text is in the same `LICENSE.txt`.
The sun rays' march follows Petalveil (MIT) by BarmaleyVIP.

## Build

```
horizon-shader check pack     # authoritative: naga, SPIR-V/Metal/HLSL, every option at min and max
python3 tools/check.py        # fast pre-flight: options ↔ overrides, [[pages]], pack-root files
python3 tools/pack.py         # dist/*.hshader, and the live symlink in shaderpacks/
```
