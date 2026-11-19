# Vanilla Horizon 2.11.1

The sunlight and the shadows read again, the pack now knows where the loaded terrain actually ends,
and the defaults are the ones tuned by hand.

## Sun and shadows (the main fix)

Moving to linear light, every gamma-tuned constant went through a 2.2 power. That is right for a
*multiplier* — a tint — but wrong for the direct light and for the share a shadow takes: `SUN_ADD`
fell from 0.18 to 0.022 and `SHADE` from 0.18 to 0.022, so outdoors the sun added about two percent of
white and a shadow darkened the ground by five percent. It read as vanilla with no shadows at all.

| constant | 2.11.0 | 2.11.1 |
| --- | --- | --- |
| `SUN_ADD` (direct sunlight) | 0.022 | **0.18** |
| `SUNSET_ADD` (a low sun's extra light) | 0.0094 | **0.12** |
| `SHADE` (what a shadow takes from sky light) | 0.022 | **0.30** |
| `MOON_ADD` (moonlight) | 0.022 | **0.10** |

`SHADE` is 0.30 rather than 0.18 because in linear light the same look needs `1 − depth` raised to the
2.2 power: at `Shadow depth` 1.5 that leaves about half the light, which is the 0.1 pack's shade. The
darkening is clamped at zero, so a high `Shadow depth` cannot drive a colour negative. The dusk fill
(the warm light on faces turned away from a low sun) went back up too, 0.03 → 0.10.

## The edge of the loaded terrain

`Skyline haze` used to sit at the distance this client *asked for* (`frame.fog_render`). On a server
whose view distance is shorter than that, the chunks ended well inside it: the mask was drawn beyond
the real edge and the edge itself stayed bare. It now also looks for the actual silhouette — if the
sky shows within four rows above a pixel, that pixel is the top of the loaded terrain — and fades
there, whatever the configured distance says. The fade mixes toward the sky's own colour as much as
toward `fog_color`, because at dusk and at night the latter is much darker than the sky and darkened
the last chunks instead of dissolving them.

## New defaults

Taken from a hand-tuned profile: `Day fog` 0, `Cave fog` 0, `Skyline haze` 0, `Mist height` 2.5,
`Mist distance` 1; `Dusk rays` 0.20; `Night mist` 1.20, `Midnight mist` 0.25; `Shadow edges` Sharp,
`Shadow depth` 1.50; `Block light colour` 0.65; `Water transparency` 0.70, `Far water` 0.40,
`Far water distance` 124; `Wind` 0.45. Everything else is unchanged.

## Install

1. Start Horizon with `HORIZON_HDR_FRAME=float`.
2. Horizon → Options → Horizon Settings → Shader Packs → **Open Pack Folder**, drop
   `vanilla_horizon-2.11.1.hshader` in, reopen the page, pick **Vanilla Horizon**.
3. `Reset all options` to take the new defaults.

`vanilla_horizon-2.11.1.hshader` — SHA-256
`a502e6cf3584b732f7e49dec74300b5fcbe051596ee604d387abddce85c7b1e3`
